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

# --- Flux A2 : séparation par source (lab-apps / lab-platform / lab-authz), docs/ARGO-ESCALATION.md ---
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
check gen-clusterrolebinding refus "S1 ClusterRoleBinding/lab-evil cluster-scoped absent de clusterResourceWhitelist \(lab-apps\)" "$d"

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
check gen-secret refus "S1 Secret/leak namespacé non autorisé par l'AppProject lab-apps" "$d"

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
check gen-vap refus "S1 ValidatingAdmissionPolicy/lab-cell-pod-hardening cluster-scoped absent .*\(lab-apps\)" "$d"

# 18. Application lab-platform pointée sur generated/ (pour y gagner les kinds plateforme).
d="$(fresh platform-on-gen)"; app pgen lab-platform generated/namespaces/default "$AUTO" > "$d/$A/apps/pgen.yaml"
check lab-platform-sur-generated refus "A3 .*chemin 'generated/namespaces/default' interdit au projet lab-platform" "$d"

# 19. Projet lab-apps emprunté par une autre Application (chemin platform/policies).
d="$(fresh apps-borrow)"; app aborrow lab-apps platform/policies "$AUTO" > "$d/$A/apps/aborrow.yaml"
check lab-apps-emprunte refus "A2 projet lab-apps réservé" "$d"

# 20. lab-apps élargi : kind cluster-scoped en whitelist.
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
check lab-apps-cluster-scoped refus "P2 lab-apps : clusterResourceWhitelist doit être POSÉE vide" "$d"

# 21. lab-apps élargi : Secret en whitelist namespacée.
d="$(fresh apps-secret-wl)"
python3 -I - "$d/$A/project-lab.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "    - {group: openchoreo.dev, kind: SecretReference}\n"
assert anchor in s
open(p, "w").write(s.replace(anchor, anchor + '    - {group: "", kind: Secret}\n', 1))
PY
check lab-apps-secret-whitelist refus "P2 lab-apps : namespaceResourceWhitelist limitée" "$d"

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

# --- Flux lab-apps en sources[] (une source par app OKE stateless, refus des autres) ---
R=https://github.com/platform-zephyr/openchoreo-lab
GW=generated/namespaces/default/projects/whoami
GK=generated/namespaces/default/projects/miniflux
lab_apps() { # CORPS_SOURCES : Application lab-apps avec le bloc sources donné
  cat <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: lab-apps, namespace: lab-argocd}
spec:
  project: lab-apps
  sources:
$1
  destination: {server: https://kubernetes.default.svc, namespace: default}
  syncPolicy: {automated: {prune: false, selfHeal: true}}
EOF
}
src() { # DEPOT REVISION CHEMIN RECURSE INCLUDE : une entrée de sources[]
  printf '    - {repoURL: %s, targetRevision: %s, path: %s, directory: {recurse: %s, include: "%s"}}\n' "$@"
}

# Positif : sources[] actuelles (whoami + ntfy) déjà couvertes par « positif-arbre-actuel ».

# 26. Source vers une app k3d (volume interdit sur OKE) : miniflux.
d="$(fresh src-k3d)"; lab_apps "$(src $R main $GK true '*.yaml')
$(src $R main $GW true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-app-k3d refus "A2 lab-apps : sources\[0\]\.path .generated/namespaces/default/projects/miniflux. : app .miniflux. non OKE" "$d"

# 27. Source = dossier parent (generated/ entier) ou sous-dossier d'une app.
d="$(fresh src-racine)"; lab_apps "$(src $R main generated/namespaces/default true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-racine-generated refus "A2 lab-apps : sources\[0\]\.path .generated/namespaces/default. : seul" "$d"
d="$(fresh src-sous-dossier)"; lab_apps "$(src $R main $GW/components true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-sous-dossier refus "A2 lab-apps : sources\[0\]\.path .generated/namespaces/default/projects/whoami/components. : seul" "$d"

# 28. Récursion ou include différent de celui prévu.
d="$(fresh src-norecurse)"; lab_apps "$(src $R main $GW false '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-sans-recurse refus "A3 lab-apps : sources\[0\]\.directory\.recurse" "$d"
d="$(fresh src-include)"; lab_apps "$(src $R main $GW true '*')" > "$d/$A/apps/lab-apps.yaml"
check src-include-large refus "A3 lab-apps : sources\[0\]\.directory\.include" "$d"

# 29. Dépôt étranger, autre révision.
d="$(fresh src-depot)"; lab_apps "$(src https://example.org/evil main $GW true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-depot-etranger refus "A3 lab-apps : sources\[0\]\.repoURL .https://example.org/evil. hors" "$d"
d="$(fresh src-rev)"; lab_apps "$(src $R dev $GW true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-revision-dev refus "A3 lab-apps : sources\[0\]\.targetRevision doit être main" "$d"

# 30. Helm/kustomize dans une source ; même dossier deux fois.
d="$(fresh src-chart)"; lab_apps "    - {repoURL: $R, targetRevision: main, path: $GW, directory: {recurse: true, include: \"*.yaml\"}, chart: {name: x}}" > "$d/$A/apps/lab-apps.yaml"
check src-chart refus "A3 lab-apps : sources\[0\]\.chart interdit" "$d"
d="$(fresh src-doublon)"; lab_apps "$(src $R main $GW true '*.yaml')
$(src $R main $GW true '*.yaml')" > "$d/$A/apps/lab-apps.yaml"
check src-doublon refus "A3 lab-apps : sources\[1\]\.path .generated/namespaces/default/projects/whoami. en double" "$d"

# 31. `source` unique à la place de sources[] pour lab-apps.
d="$(fresh src-unique)"
cat > "$d/$A/apps/lab-apps.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: lab-apps, namespace: lab-argocd}
spec:
  project: lab-apps
  source: {repoURL: $R, targetRevision: main, path: $GW, directory: {recurse: true, include: "*.yaml"}}
  destination: {server: https://kubernetes.default.svc, namespace: default}
EOF
check source-unique-lab-apps refus 'A3 lab-apps : .source. unique interdit' "$d"

# 32. sources[] hors lab-apps (lab-platform) : interdit.
d="$(fresh src-platform)"
cat > "$d/$A/apps/x.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: x, namespace: lab-argocd}
spec:
  project: lab-platform
  sources: [{repoURL: $R, targetRevision: main, path: platform/policies}]
  destination: {server: https://kubernetes.default.svc, namespace: default}
EOF
check sources-hors-lab-apps refus "A3 Application 'x' : sources multiples interdites hors lab-apps" "$d"

# 33. Flip de politique sur l'app elle-même : ntfy repasse en k3d, puis en stateful (volume), refus côté Argo.
d="$(fresh ntfy-k3d)"; python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); assert "cluster: oke" in s; p.write_text(s.replace("cluster: oke","cluster: k3d",1))' "$d/apps/ntfy/app.yaml"
check ntfy-passe-k3d refus "A2 lab-apps : sources\[1\]\.path .generated/namespaces/default/projects/ntfy. : app .ntfy. non OKE" "$d"
d="$(fresh ntfy-stateful)"; python3 -I -c 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(); assert "profile: stateless" in s; p.write_text(s.replace("profile: stateless","profile: stateful",1))' "$d/apps/ntfy/app.yaml"
check ntfy-passe-stateful refus "A2 lab-apps : sources\[1\]\.path .generated/namespaces/default/projects/ntfy. : app .ntfy. non OKE" "$d"

echo "argo-guard : $pass PASS, $fail FAIL"
(( fail == 0 ))
