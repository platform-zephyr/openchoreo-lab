#!/usr/bin/env bash
# run-all.sh APP [ENV] [--evidence DIR] : toutes les vérifications runtime d'une app selon son archétype.
#
#   CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh whoami production \
#     --evidence evidence/runtime
#
# Archétype déduit de apps/<APP>/app.yaml : chart -> E ; database -> B ; storage -> C ; sinon A.
# Sortie : format « evidence golden-path v1 » (voir golden-paths/DEPLOY-AND-FIX-FLOW.md §4).
# Code retour : 0 PASS ; 1 FAIL ; 3 PARTIAL (aucun FAIL, mais BLOCKED ou NOT_TESTED).
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: run-all.sh APP [ENV] [--evidence DIR]}"; shift
ENV="production"; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in --evidence) OUT="${2:?}"; shift 2 ;; *) ENV="$1"; shift ;; esac
done
[ -f "$REPO_ROOT/apps/$APP/app.yaml" ] || { echo "apps/$APP/app.yaml introuvable" >&2; exit 2; }
D="$(dirname "$0")"

if   [ -n "$(app_field "$APP" spec.source.chart)" ]; then ARCH="E-helm-chart"; CHECKS="check-gitops.sh check-helm.sh"
elif [ -n "$(app_field "$APP" spec.database)" ];      then ARCH="B-http-postgres"; CHECKS="check-gitops.sh check-workload.sh check-postgres.sh"
elif [ -n "$(app_field "$APP" spec.storage)" ];       then ARCH="C-http-sqlite-pvc"; CHECKS="check-gitops.sh check-workload.sh check-pvc.sh"
else                                                       ARCH="A-stateless-http"; CHECKS="check-gitops.sh check-workload.sh"
fi
[ "$ARCH" = "E-helm-chart" ] && CHECKS="check-helm.sh"   # pas de Component OpenChoreo pour un chart

run() {
  header "$APP" "$ENV" "$ARCH"
  for c in $CHECKS; do
    echo "## $c"
    GP_NESTED=1 bash "$D/$c" "$APP" "$ENV" || true
  done
}

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
run | tee "$TMP"
p=$(grep -c '^PASS ' "$TMP" || true); f=$(grep -c '^FAIL ' "$TMP" || true)
n=$(grep -c '^NOT_TESTED ' "$TMP" || true); b=$(grep -c '^BLOCKED ' "$TMP" || true)
{
  echo "---"
  echo "summary: PASS=$p FAIL=$f NOT_TESTED=$n BLOCKED=$b"
  if [ "$f" -gt 0 ]; then echo "verdict: FAIL"; elif [ $((n + b)) -gt 0 ]; then echo "verdict: PARTIAL"; else echo "verdict: PASS"; fi
} | tee -a "$TMP"

if [ -n "$OUT" ]; then
  dir="$REPO_ROOT/$OUT/$CLUSTER_LABEL/$APP"; mkdir -p "$dir"
  file="$dir/$(date -u +%Y%m%dT%H%M%SZ)-$ENV.txt"; cp "$TMP" "$file"
  echo "evidence écrite : ${file#"$REPO_ROOT"/}" >&2
fi
[ "$f" -gt 0 ] && exit 1; [ $((n + b)) -gt 0 ] && exit 3; exit 0
