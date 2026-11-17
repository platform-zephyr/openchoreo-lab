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

# 2. Application hors apps/ (projet lab, légitime en apparence).
d="$(fresh app-outside)"; app sneaky lab platform/policies "$AUTO" > "$d/platform/data/sneaky.yaml"
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
check whitelist-joker refus "P2 lab : namespaceResourceWhitelist joker" "$d"

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

# 12. Application lab qui synchronise tests/ (hors platform/ et generated/).
d="$(fresh lab-tests)"; app tst lab tests/gitops-k3d/apps "$AUTO" > "$d/$A/apps/tst.yaml"
check lab-chemin-hors-platform refus "A3 .*chemin 'tests/gitops-k3d/apps'" "$d"

echo "argo-guard : $pass PASS, $fail FAIL"
(( fail == 0 ))
