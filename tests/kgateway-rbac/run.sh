#!/usr/bin/env bash
# Test HORS LIGNE de tools/oke/kgateway_rbac_check.py (T-060) : sans cluster ni réseau. Le manifeste et les values
# du dépôt passent ; chaque mutation qui rendrait l'écriture des Secrets ou le RBAC du chart doit être refusée.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
C="$REPO/tools/oke/kgateway_rbac_check.py"
M="$REPO/platform/install/manifests/05-kgateway-rbac.yaml"
V="$REPO/platform/install/values/kgateway.yaml"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fail=1; }
expect() { # attendu(0|1) libellé motif args...
  local want="$1" msg="$2" pat="$3" out rc; shift 3
  set +e; out="$(python3 -I "$C" "$@" 2>&1)"; rc=$?; set -e
  if [[ "$rc" == "$want" ]] && grep -q -- "$pat" <<<"$out"; then ok "$msg"; else ko "$msg (rc=$rc : ${out:0:200})"; fi
}
mut() { python3 -I -c 'import sys,yaml; d=list(yaml.safe_load_all(open(sys.argv[1]))); exec(sys.argv[2]); print(yaml.safe_dump_all(d))' "$@"; }

expect 0 "dépôt : manifeste et values conformes" "kgateway-rbac : OK" "$M" "$V"
mut "$M" 'next(r for r in d[0]["rules"] if r["resources"]==["secrets"])["verbs"].append("patch")' > "$T/patch.yaml"
expect 1 "R2 : patch secrets cluster-wide refusé" "R2 ClusterRole : secrets" "$T/patch.yaml" "$V"
mut "$M" 'd[0]["rules"].append({"apiGroups":["*"],"resources":["*"],"verbs":["*"]})' > "$T/joker.yaml"
expect 1 "R2 : joker refusé" "R2 ClusterRole : joker" "$T/joker.yaml" "$V"
mut "$M" 'd[2]["rules"][0]["verbs"].append("delete")' > "$T/role.yaml"
expect 1 "R3 : Role avec delete refusé" "R3 Role" "$T/role.yaml" "$V"
mut "$M" 'd[1]["subjects"][0]["namespace"]="default"' > "$T/subj.yaml"
expect 1 "R3 : liaison vers un autre sujet refusée" "R3 ClusterRoleBinding" "$T/subj.yaml" "$V"
mut "$V" 'd[0]["rbac"]["create"]=True' > "$T/values.yaml"
expect 1 "R1 : rbac.create=true refusé" "R1 values" "$M" "$T/values.yaml"
# R4/R5 avec des rendus synthétiques : le chart rend un ClusterRole (R4) ; le chart gagne un droit absent de Git (R5).
mut "$M" 'd=d[:1]; d[0]["metadata"]["name"]="kgateway-openchoreo-control-plane"' > "$T/off.yaml"
expect 1 "R4 : RBAC rendu malgré rbac.create=false refusé" "R4 rendu" "$M" "$V" "$T/off.yaml" "$T/off.yaml"
mut "$M" 'd=d[:1]; d[0]["rules"].append({"apiGroups":["x.io"],"resources":["y"],"verbs":["get"]})' > "$T/up.yaml"
printf 'kind: Service\nmetadata: {name: kgateway}\n' > "$T/empty.yaml"
expect 1 "R5 : écart avec le ClusterRole du chart refusé" "R5 écart" "$M" "$V" "$T/empty.yaml" "$T/up.yaml"
mut "$M" 'd=d[:1]; next(r for r in d[0]["rules"] if r["resources"]==["secrets"])["verbs"]+=["create","delete","patch"]' > "$T/up2.yaml"
expect 0 "R5 : chart avec écriture des Secrets = Git moins l'écriture" "kgateway-rbac : OK" "$M" "$V" "$T/empty.yaml" "$T/up2.yaml"
exit "$fail"
