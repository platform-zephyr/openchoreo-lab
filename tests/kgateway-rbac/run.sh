#!/usr/bin/env bash
# Test statique (T-060) du post-renderer tools/oke/kgateway-rbac.py : sans cluster, sans réseau.
# Vérifie : plus de `secrets` dans le ClusterRole, un Role + RoleBinding par namespace, refus si le chart change.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PR="$ROOT/tools/oke/kgateway-rbac.py"
FIX="$ROOT/tests/kgateway-rbac/fixture.yaml"
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
out="$(PYTHONDONTWRITEBYTECODE=1 python3 -I "$PR" < "$FIX")"

n="$(yq -N 'select(.kind == "ClusterRole") | .rules[] | select(.resources | contains(["secrets"])) | .kind' <<<"$out" | wc -l | tr -d ' ')"
[[ "$n" == 0 ]] && ok "ClusterRole sans secrets" || ko "ClusterRole garde secrets"
[[ "$(yq -N 'select(.kind == "ClusterRole") | .rules[] | select(.resources | contains(["serviceaccounts"])) | .resources | length' <<<"$out")" == 1 ]] \
  && ok "serviceaccounts conservé" || ko "serviceaccounts perdu"
[[ "$(yq -N 'select(.kind == "Role") | .metadata.namespace' <<<"$out" | paste -sd, -)" == openchoreo-control-plane,openchoreo-data-plane ]] \
  && ok "Role dans les 2 namespaces par défaut" || ko "Roles inattendus"
[[ "$(yq -N 'select(.kind == "RoleBinding") | .subjects[0].name' <<<"$out" | sort -u)" == kgateway ]] \
  && ok "RoleBinding vers le SA kgateway" || ko "RoleBinding inattendu"
out2="$(KGATEWAY_SECRETS_NAMESPACES=ns-a PYTHONDONTWRITEBYTECODE=1 python3 -I "$PR" < "$FIX")"
[[ "$(yq -N 'select(.kind == "Role") | .metadata.namespace' <<<"$out2")" == ns-a ]] && ok "namespaces paramétrables" || ko "KGATEWAY_SECRETS_NAMESPACES ignoré"
if yq -N 'select(.kind != "ClusterRole")' "$FIX" | PYTHONDONTWRITEBYTECODE=1 python3 -I "$PR" >/dev/null 2>&1; then
  ko "doit refuser un rendu sans ClusterRole"
else
  ok "refus fermé si le chart change"
fi
echo "fails=$fails"
[[ $fails -eq 0 ]]
