#!/usr/bin/env bash
# Tests de tools/oke/argo_guard.py (revue PR #8, P1). Hors cluster, sans réseau.
# Chaque cas copie platform/, generated/ et apps/ dans un répertoire TEMPORAIRE hors dépôt (mktemp), y pose
# UN piège, lance argo_guard et exige un refus (rc != 0) portant le code de règle attendu. Cas positif :
# copie intacte => rc=0. Usage : tests/argo-guard/run.sh   (python3 + PyYAML)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$REPO/tools/oke/argo_guard.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/argo-guard.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0 fail=0
A=platform/install/argocd

fresh() { # copie neuve de l'arbre contrôlé ; affiche son chemin
  local d="$WORK/$1"
  mkdir -p "$d"
  cp -R "$REPO/platform" "$REPO/generated" "$REPO/apps" "$d/"
  printf '%s\n' "$d"
}

check() { # NOM RC_ATTENDU(0|refus) MOTIF DOSSIER
  local name="$1" want="$2" pat="$3" dir="$4" out rc=0
  out="$(python3 -I "$GUARD" "$dir" 2>&1)" || rc=$?
  if { [[ "$want" == 0 && $rc == 0 ]] || [[ "$want" == refus && $rc != 0 ]]; } && grep -qE "$pat" <<<"$out"; then
    printf 'PASS %-28s rc=%s %s\n' "$name" "$rc" "$(grep -m1 -E "$pat" <<<"$out")"; pass=$((pass + 1))
  else
    printf 'FAIL %-28s rc=%s (attendu %s, motif %s)\n%s\n' "$name" "$rc" "$want" "$pat" "$out"; fail=$((fail + 1))
  fi
}

app() { # NOM PROJET CHEMIN [SYNC] : Application minimale
  cat <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: $1, namespace: lab-argocd}
spec:
  project: $2
  source: {repoURL: https://github.com/platform-zephyr/openchoreo-lab, targetRevision: main, path: $3}
  destination: {server: https://kubernetes.default.svc, namespace: lab-argocd}
${4:-}
EOF
}
AUTO='  syncPolicy: {automated: {prune: true, selfHeal: true}}'

# Positif : arbre actuel.
check positif-arbre-actuel 0 " 0 écart" "$(fresh ok)"

# 1. Application project: default, dans apps/ (seul piège : projet).
d="$(fresh default-in-apps)"; app evil default platform/policies "$AUTO" > "$d/$A/apps/evil.yaml"
check app-project-default refus "A2 .*projet 'default'" "$d"

# 1b. Scénario exact de la revue : platform/policies/zz.yaml, Application default automated.
d="$(fresh review-zz)"; app evil default platform "$AUTO" > "$d/platform/policies/zz.yaml"
check revue-policies-zz refus "A1 .*hors $A/apps/" "$d"

# 2. Application hors apps/ (projet lab-platform, légitime en apparence).
d="$(fresh app-outside)"; app sneaky lab-platform platform/policies "$AUTO" > "$d/platform/data/sneaky.yaml"
check app-hors-apps refus "A1 Application 'sneaky' hors" "$d"

# 3. lab-authz passé en automated.
d="$(fresh authz-auto)"
python3 -I - "$d/$A/apps/lab-authz.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
assert "  syncPolicy:\n" in s
open(p, "w").write(s.replace("  syncPolicy:\n", "  syncPolicy:\n    automated: {prune: false, selfHeal: true}\n", 1))
PY
check lab-authz-automated refus "A4 .*automated" "$d"

# 3b. Autre Application empruntant le projet lab-authz en automated.
d="$(fresh authz-borrow)"; app borrow lab-authz platform/authz "$AUTO" > "$d/$A/apps/borrow.yaml"
check lab-authz-emprunte refus "A2 projet lab-authz réservé|A4" "$d"

# 4. Objet authz hors platform/authz/.
d="$(fresh authz-outside)"
cat > "$d/platform/policies/admin.yaml" <<'EOF'
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRoleBinding
metadata: {name: lab-evil-admin}
spec: {roleRef: {kind: ClusterAuthzRole, name: admin}, entitlement: {claim: sub, value: attacker}, effect: allow}
EOF
check authz-hors-platform-authz refus "Z1 ClusterAuthzRoleBinding/lab-evil-admin hors platform/authz/" "$d"

# 5. Whitelist `*` dans l'AppProject lab.
d="$(fresh wildcard)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "    - {group: openchoreo.dev, kind: Environment}\n"
assert anchor in s
open(p, "w").write(s.replace(anchor, anchor + '    - {group: "*", kind: "*"}\n', 1))
PY
check whitelist-joker refus "P2 lab-platform : namespaceResourceWhitelist joker" "$d"

# 6. ClusterRoleBinding dans platform/policies (synchronisé par lab-platform).
d="$(fresh crb)"
cat > "$d/platform/policies/crb.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: lab-evil}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects: [{kind: ServiceAccount, name: default, namespace: default}]
EOF
check crb-dans-policies refus "S1 ClusterRoleBinding/lab-evil cluster-scoped absent" "$d"

# 7. Projet default déverrouillé (fichier de verrou supprimé, puis rouvert).
d="$(fresh default-unlocked)"
python3 -I - "$d/$A/project-default-locked.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
assert "  sourceRepos: []\n" in s
open(p, "w").write(s.replace("  sourceRepos: []\n", "  sourceRepos: ['*']\n", 1))
PY
check default-deverrouille refus "P1 projet default non verrouillé" "$d"

# 8. AppProject supplémentaire glissé dans platform/policies.
d="$(fresh extra-project)"
cat > "$d/platform/policies/proj.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: open, namespace: lab-argocd}
spec: {sourceRepos: ['*'], destinations: [{server: '*', namespace: '*'}], clusterResourceWhitelist: [{group: '*', kind: '*'}]}
EOF
check appproject-hors-bootstrap refus "P1 AppProject 'open' hors" "$d"

# 9. NetworkPolicy « tout ouvrir » dans lab-pg (revue A1).
d="$(fresh np-open)"
cat >> "$d/platform/data/lab-pg-namespace.yaml" <<'EOF'
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-all, namespace: lab-pg}
spec: {podSelector: {}, policyTypes: [Ingress], ingress: [{}]}
EOF
check np-allow-all-lab-pg refus "S2 NetworkPolicy lab-pg/allow-all" "$d"

# 10. Namespace lab-pg abaissé en PSA baseline (revue A2).
d="$(fresh psa-baseline)"
python3 -I - "$d/platform/data/lab-pg-namespace.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "pod-security.kubernetes.io/enforce: restricted"
assert old in s
open(p, "w").write(s.replace(old, "pod-security.kubernetes.io/enforce: baseline", 1))
PY
check lab-pg-psa-baseline refus "S3 Namespace lab-pg : label pod-security.kubernetes.io/enforce" "$d"

# 11. Application enfant dans le projet lab-root (pourrait créer d'autres Application).
d="$(fresh child-root)"; app nested lab-root platform/policies "$AUTO" > "$d/$A/apps/nested.yaml"
check enfant-projet-lab-root refus "A2 .*lab-root" "$d"

# 12. Application lab-platform qui synchronise tests/ (hors platform/).
d="$(fresh lab-tests)"; app tst lab-platform tests/gitops-k3d/apps "$AUTO" > "$d/$A/apps/tst.yaml"
check lab-chemin-hors-platform refus "A3 .*chemin 'tests/gitops-k3d/apps'" "$d"

# --- Flux A2 : séparation par source (lab-o / lab-platform / lab-authz), docs/ARGO-ESCALATION.md ---
G=generated/namespaces/default/projects/whoami

# 13. PR applicative : ClusterRoleBinding glissé dans generated/.
d="$(fresh gen-crb)"
cat > "$d/$G/zz-crb.yaml" <<'EOF2'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: lab-evil}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects: [{kind: ServiceAccount, name: default, namespace: default}]
EOF2
check gen-clusterrolebinding refus "S1 ClusterRoleBinding/lab-evil cluster-scoped absent de clusterResourceWhitelist \(lab-o\)" "$d"

# 14. PR applicative : Application dans generated/ (projet lab-platform).
d="$(fresh gen-app)"; app genapp lab-platform platform/policies "$AUTO" > "$d/$G/zz-app.yaml"
check gen-application refus "A1 Application 'genapp' hors" "$d"

# 15. PR applicative : Secret en clair dans generated/.
d="$(fresh gen-secret)"
cat > "$d/$G/zz-secret.yaml" <<'EOF2'
apiVersion: v1
kind: Secret
metadata: {name: leak, namespace: default}
stringData: {password: factice}
EOF2
check gen-secret refus "S1 Secret/leak namespacé non autorisé par l'AppProject lab-o" "$d"

# 16. PR applicative : Namespace kube-system patché (label PSA) dans generated/.
d="$(fresh gen-ns)"
cat > "$d/$G/zz-ns.yaml" <<'EOF2'
apiVersion: v1
kind: Namespace
metadata: {name: kube-system, labels: {pod-security.kubernetes.io/enforce: privileged}}
EOF2
check gen-namespace-psa refus "G1 Namespace/kube-system" "$d"

# 17. PR applicative : VAP modifiée (même nom que celle du labo) dans generated/.
d="$(fresh gen-vap)"
cat > "$d/$G/zz-vap.yaml" <<'EOF2'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: lab-cell-pod-hardening}
spec: {failurePolicy: Ignore, matchConstraints: {resourceRules: []}, validations: [{expression: "true"}]}
EOF2
check gen-vap refus "S1 ValidatingAdmissionPolicy/lab-cell-pod-hardening cluster-scoped absent .*\(lab-o\)" "$d"

# 18. Application lab-platform pointée sur generated/ (pour y gagner les kinds plateforme).
d="$(fresh platform-on-gen)"; app pgen lab-platform generated/namespaces/default "$AUTO" > "$d/$A/apps/pgen.yaml"
check lab-platform-sur-generated refus "A3 .*chemin 'generated/namespaces/default' interdit au projet lab-platform" "$d"

# 19. Projet lab-o emprunté par une Application écrite à la main (réservé à l'ApplicationSet).
d="$(fresh apps-borrow)"; app aborrow lab-o platform/policies "$AUTO" > "$d/$A/apps/aborrow.yaml"
check lab-o-emprunte refus "A2 Application .aborrow. : projet lab-o réservé à l'ApplicationSet lab-o" "$d"

# 20. lab-o élargi : kind cluster-scoped en whitelist.
d="$(fresh apps-cluster)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "  description: Applications du labo"
assert anchor in s and s.count("  clusterResourceWhitelist: []\n") >= 2
i = s.index(anchor); j = s.index("  clusterResourceWhitelist: []\n", i)
s = s[:j] + "  clusterResourceWhitelist:\n    - {group: rbac.authorization.k8s.io, kind: ClusterRoleBinding, name: lab-x}\n" \
    + s[j + len("  clusterResourceWhitelist: []\n"):]
open(p, "w").write(s)
PY
check lab-o-cluster-scoped refus "P2 lab-o : clusterResourceWhitelist doit être POSÉE vide" "$d"

# 21. lab-o élargi : Secret en whitelist namespacée.
d="$(fresh apps-secret-wl)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "    - {group: openchoreo.dev, kind: SecretReference}\n"
assert anchor in s
open(p, "w").write(s.replace(anchor, anchor + '    - {group: "", kind: Secret}\n', 1))
PY
check lab-o-secret-whitelist refus "P2 lab-o : namespaceResourceWhitelist limitée" "$d"

# 22. lab-authz : fenêtre deny retirée (la synchro automatique redeviendrait possible).
d="$(fresh authz-nowindow)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("name: lab-authz"); j = s.index("    - kind: deny\n", i)
open(p, "w").write(s[:j] + "    - kind: allow\n" + s[j + len("    - kind: deny\n"):])
PY
check lab-authz-sans-fenetre-deny refus "P3 lab-authz : fenêtre deny permanente exigée" "$d"

# 23. Fichier hors kinds applicatifs ailleurs sous generated/ (ConfigMap à la racine).
d="$(fresh gen-other)"
printf 'apiVersion: v1\nkind: ConfigMap\nmetadata: {name: x, namespace: default}\n' > "$d/generated/zz.yaml"
check gen-chemin-inconnu refus "G1 ConfigMap/x : chemin generated/ inconnu" "$d"

# 24. lab-platform repassé en automated (un merge platform/** s'appliquerait seul).
d="$(fresh platform-auto)"
python3 -I - "$d/$A/apps/lab-platform.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
assert "  syncPolicy:\n" in s
open(p, "w").write(s.replace("  syncPolicy:\n", "  syncPolicy:\n    automated: {prune: false, selfHeal: true}\n", 1))
PY
check lab-platform-automated refus "A4 Application 'lab-platform' \(lab-platform\) : synchro automated interdite" "$d"

# 25. lab-platform : fenêtre deny retirée du projet.
d="$(fresh platform-nowindow)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("name: lab-platform"); j = s.index("    - kind: deny\n", i)
open(p, "w").write(s[:j] + "    - kind: allow\n" + s[j + len("    - kind: deny\n"):])
PY
check lab-platform-sans-fenetre-deny refus "P3 lab-platform : fenêtre deny permanente exigée" "$d"

# --- ApplicationSet lab-o (T-491) : une Application par app, projet et destination fixes ---
APPSET=$A/apps/lab-apps.yaml
mutate() { # DOSSIER ANCIEN NOUVEAU : remplace UNE occurrence dans l'ApplicationSet (échoue si absente)
  python3 -I - "$1/$APPSET" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
assert old in s, old
open(p, "w").write(s.replace(old, new, 1))
PY
}

# 26. Projet tiré du dépôt applicatif (paramètre) au lieu du littéral lab-o.
d="$(fresh appset-projet)"; mutate "$d" "      project: lab-o" "      project: '{{.path.basename}}'"
check appset-projet-parametre refus "O4 lab-o : template.spec.project doit être le littéral lab-o" "$d"
d="$(fresh appset-projet-default)"; mutate "$d" "      project: lab-o" "      project: default"
check appset-projet-default refus "O4 lab-o : template.spec.project doit être le littéral lab-o" "$d"

# 27. Destination tirée du dépôt applicatif, ou autre namespace.
d="$(fresh appset-dest)"; mutate "$d" "        namespace: default
      syncPolicy" "        namespace: '{{.path.basename}}'
      syncPolicy"
check appset-destination-parametree refus "O4 lab-o : template.spec.destination doit être le littéral" "$d"
d="$(fresh appset-dest-ks)"; mutate "$d" "        namespace: default
      syncPolicy" "        namespace: kube-system
      syncPolicy"
check appset-destination-kube-system refus "O4 lab-o : template.spec.destination doit être le littéral" "$d"

# 28. templatePatch (réécriture du modèle par un paramètre), générateur `files`, dépôt étranger.
d="$(fresh appset-patch)"; mutate "$d" "  goTemplate: true" "  templatePatch: 'spec: {project: x}'
  goTemplate: true"
check appset-templatepatch refus "O2 lab-o : spec.templatePatch interdit" "$d"
d="$(fresh appset-files)"; mutate "$d" "        directories:" "        files: [{path: 'apps/*/app.yaml'}]
        directories:"
check appset-generateur-files refus "O3 lab-o : generators\[0\].git.files interdit" "$d"
d="$(fresh appset-depot)"; mutate "$d" "        repoURL: https://github.com/platform-zephyr/openchoreo-lab
        revision: main" "        repoURL: https://example.org/evil
        revision: main"
check appset-depot-etranger refus "O3 lab-o : git.repoURL .https://example.org/evil. hors dépôt du labo" "$d"

# 29. missingkey=error retiré ; preserveResourcesOnDeletion retiré ; chemin source figé.
d="$(fresh appset-missingkey)"; mutate "$d" '  goTemplateOptions: ["missingkey=error"]' '  goTemplateOptions: []'
check appset-sans-missingkey refus "O2 lab-o : goTemplate: true et goTemplateOptions" "$d"
d="$(fresh appset-preserve)"; mutate "$d" "preserveResourcesOnDeletion: true" "preserveResourcesOnDeletion: false"
check appset-sans-preserve refus "O2 lab-o : syncPolicy.preserveResourcesOnDeletion" "$d"
d="$(fresh appset-chemin)"; mutate "$d" '        path: "{{.path.path}}"' "        path: platform"
check appset-chemin-fixe refus "O4 lab-o : template.spec.source.path doit être" "$d"

# 30. App k3d (volume interdit sur OKE) retirée de la liste d'exclusion : déployée par le générateur.
d="$(fresh appset-k3d)"; mutate "$d" "          - {path: generated/namespaces/default/projects/miniflux, exclude: true}
" ""
check appset-app-k3d-non-exclue refus "O5 lab-o : app .miniflux. non OKE stateless et non exclue" "$d"

# 31. Flip de politique sur l'app elle-même : ntfy repasse en k3d, puis en stateful (volume).
d="$(fresh ntfy-k3d)"; python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); assert "cluster: oke" in s; p.write_text(s.replace("cluster: oke","cluster: k3d",1))' "$d/apps/ntfy/app.yaml"
check ntfy-passe-k3d refus "O5 lab-o : app .ntfy. non OKE stateless et non exclue" "$d"
d="$(fresh ntfy-stateful)"; python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); assert "profile: stateless" in s; p.write_text(s.replace("profile: stateless","profile: stateful",1))' "$d/apps/ntfy/app.yaml"
check ntfy-passe-stateful refus "O5 lab-o : app .ntfy. non OKE stateless et non exclue" "$d"

# 32. Un second ApplicationSet, ou un ApplicationSet hors apps/ : refus.
d="$(fresh appset-second)"; sed 's/name: lab-o$/name: lab-evil/' "$d/$APPSET" > "$d/$A/apps/evil-appset.yaml"
check appset-second refus "O1 ApplicationSet .lab-evil. : seul .lab-o., un exemplaire" "$d"

# 33. App témoin (critère 4 de T-491) : une app OKE ajoutée par apps/<app>/app.yaml et sa sortie generated/ SEULS,
#     sans modifier platform/ ni l'ApplicationSet : le contrôle statique passe et la synchronise.
d="$(fresh app-temoin)"
cp -R "$d/apps/whoami" "$d/apps/zz-temoin"
cp -R "$d/generated/namespaces/default/projects/whoami" "$d/generated/namespaces/default/projects/zz-temoin"
check app-temoin-sans-edition-platform 0 " 0 écart" "$d"
n_before="$(python3 -I "$GUARD" "$(fresh app-temoin-ref)" | grep -oE '[0-9]+ par lab-o')"
n_after="$(python3 -I "$GUARD" "$d" | grep -oE '[0-9]+ par lab-o')"
if [[ "$n_before" != "$n_after" ]]; then
  printf 'PASS %-28s fichiers synchronisés par lab-o : %s -> %s\n' app-temoin-synchronisee "$n_before" "$n_after"; pass=$((pass + 1))
else
  printf 'FAIL %-28s l app témoin n est pas synchronisée (%s)\n' app-temoin-synchronisee "$n_after"; fail=$((fail + 1))
fi

# 34. Socle cluster (T-494) : platform/baseline/ est synchronisé par lab-platform, mais seuls les 8 objets nommés
#     passent. Une CCNP ou une VAP de plus (nom non listé) dans baseline/ : refus S1.
d="$(fresh baseline-ccnp-extra)"
cat > "$d/platform/baseline/zz-allow-all.yaml" <<'EOF2'
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata: {name: allow-all-egress}
spec: {endpointSelector: {}, egress: [{toEntities: [all]}]}
EOF2
check baseline-ccnp-hors-liste refus "S1 CiliumClusterwideNetworkPolicy/allow-all-egress cluster-scoped absent .*\(lab-platform\)" "$d"
d="$(fresh baseline-vapb-extra)"
cat > "$d/platform/baseline/zz-vapb.yaml" <<'EOF2'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: {name: baseline-pod-hardening-relax}
spec: {policyName: baseline-pod-hardening, validationActions: [Warn]}
EOF2
check baseline-vapb-hors-liste refus "S1 ValidatingAdmissionPolicyBinding/baseline-pod-hardening-relax cluster-scoped absent" "$d"
# 34b. Même nom qu'un objet du socle, mais dans generated/ (PR applicative) : refus (lab-o n'a aucun kind cluster-scoped).
d="$(fresh gen-ccnp)"
cat > "$d/$G/zz-ccnp.yaml" <<'EOF2'
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata: {name: deny-imds}
spec: {endpointSelector: {matchLabels: {none: none}}, egressDeny: []}
EOF2
check gen-ccnp-deny-imds refus "S1 CiliumClusterwideNetworkPolicy/deny-imds cluster-scoped absent .*\(lab-o\)" "$d"

# --- Bras K du banc A/B (T-495) : AppProject lab-k, projet et Application lab-k-root ---
PROJ=$A/project-lab.yaml
kmut() { # DOSSIER FICHIER ANCRE AJOUT : insère AJOUT après la 1re ANCRE suivant « name: lab-k » (ou lab-k-root)
  python3 -I - "$1/$2" "$3" "$4" "$5" <<'PY'
import sys
p, start, anchor, add = sys.argv[1:5]
s = open(p).read()
i = s.index(start); j = s.index(anchor, i) + len(anchor)
open(p, "w").write(s[:j] + add + s[j:])
PY
}

# 35. lab-k élargi à kube-system, puis à argocd, puis à lab-argocd.
for ns in kube-system argocd lab-argocd; do
  d="$(fresh lab-k-dest-$ns)"
  kmut "$d" "$PROJ" "  name: lab-k
" "  destinations:
" "    - {server: https://kubernetes.default.svc, namespace: $ns}
"
  check lab-k-destination-$ns refus "L2 lab-k : destination .*'$ns'" "$d"
done

# 36. lab-k : source d'un autre dépôt (le dépôt du labo).
d="$(fresh lab-k-repo)"
kmut "$d" "$PROJ" "  name: lab-k
" "  sourceRepos:
" "    - https://github.com/platform-zephyr/openchoreo-lab
"
check lab-k-autre-depot refus "L1 lab-k : sourceRepos limité au seul dépôt du bac à sable" "$d"

# 37. lab-k : kind non listé chez kube-ops (ExternalSecret), puis ClusterRole.
d="$(fresh lab-k-es)"
kmut "$d" "$PROJ" "  name: lab-k
" "  namespaceResourceWhitelist:
" "    - {group: external-secrets.io, kind: ExternalSecret}
"
check lab-k-externalsecret refus "L1 lab-k : namespaceResourceWhitelist = EXACTEMENT" "$d"
d="$(fresh lab-k-cr)"
kmut "$d" "$PROJ" "  name: lab-k
" "  clusterResourceWhitelist:
" "    - {group: rbac.authorization.k8s.io, kind: ClusterRole, name: lab-k-x}
"
check lab-k-clusterrole refus "L1 lab-k : clusterResourceWhitelist limitée" "$d"

# 38. svc-* admis seulement pour lab-k : le même glob dans lab-o est refusé.
d="$(fresh lab-o-svc)"
kmut "$d" "$PROJ" "  name: lab-o
" "  destinations:
" "    - {server: https://kubernetes.default.svc, namespace: 'svc-*'}
"
check lab-o-destination-svc refus "P2 lab-o : destination joker" "$d"

# 39. lab-k-root livre aussi l'AppProject copié du bac à sable (include *.yaml) ; ou passe en automated.
d="$(fresh k-root-include)"
python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); old="include: \"{apps-generated-applicationset.yaml,applications-applicationset.yaml}\""
assert old in s; p.write_text(s.replace(old, "include: \"*.yaml\"", 1))' "$d/$A/apps/lab-k-root.yaml"
check lab-k-root-projet-copie refus "L3 Application 'lab-k-root'" "$d"
d="$(fresh k-root-auto)"
python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); assert "  syncPolicy:\n" in s
p.write_text(s.replace("  syncPolicy:\n", "  syncPolicy:\n    automated: {prune: false, selfHeal: true}\n", 1))' "$d/$A/apps/lab-k-root.yaml"
check lab-k-root-automated refus "A4 Application 'lab-k-root' \(lab-k-root\) : synchro automated interdite" "$d"

# 40. Application de ce dépôt dans le projet lab-k (réservé aux ApplicationSets du bac à sable) ; projet
#     lab-k-root emprunté par une autre Application.
d="$(fresh k-app-lab-k)"; app kevil lab-k platform/policies > "$d/$A/apps/kevil.yaml"
check app-projet-lab-k refus "A2 Application 'kevil' : projet 'lab-k' interdit" "$d"
d="$(fresh k-root-borrow)"; app kborrow lab-k-root platform/policies > "$d/$A/apps/kborrow.yaml"
check lab-k-root-emprunte refus "L3 Application 'kborrow' : projet lab-k-root réservé" "$d"

echo "argo-guard : $pass PASS, $fail FAIL"
(( fail == 0 ))
