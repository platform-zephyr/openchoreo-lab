#!/usr/bin/env bash
# run-all.sh APP [ENV] [--evidence DIR] : toutes les vérifications runtime d'une app selon son archétype.
#
#   CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh whoami production \
#     --evidence evidence/runtime
#
# Archétype déduit de apps/<APP>/app.yaml : chart -> E ; database -> B ; storage -> C ; sinon A.
# Sortie : texte « evidence golden-path v1 » (DEPLOY-AND-FIX-FLOW.md §4) ou, avec --format json, un statut
# `app-status.v1` (docs/schema/app-status-v1.schema.json) seul sur stdout (le texte des checks est alors jeté).
# Sans cluster (GP_NO_CLUSTER=1, kubectl absent, serveur injoignable) : NOT_TESTED, niveau STATIC, code 3.
# Code retour : 0 PASS ; 1 FAIL ; 3 PARTIAL (aucun FAIL, mais BLOCKED ou NOT_TESTED).
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: run-all.sh APP [ENV] [--evidence DIR]}"; shift
ENV="production"; OUT=""; FORMAT="text"
while [ $# -gt 0 ]; do
  case "$1" in
    --evidence) OUT="${2:?}"; shift 2 ;;
    --format) FORMAT="${2:?}"; shift 2 ;;
    *) ENV="$1"; shift ;;
  esac
done
case "$FORMAT" in text|json) ;; *) echo "--format text|json" >&2; exit 2 ;; esac
[ -f "$REPO_ROOT/apps/$APP/app.yaml" ] || { echo "apps/$APP/app.yaml introuvable" >&2; exit 2; }
D="$(dirname "$0")"

if   [ -n "$(app_field "$APP" spec.source.chart)" ]; then ARCH="E-helm-chart"; CHECKS="check-gitops.sh check-helm.sh"
elif [ -n "$(app_field "$APP" spec.database)" ];      then ARCH="B-http-postgres"; CHECKS="check-gitops.sh check-workload.sh check-postgres.sh"
elif [ -n "$(app_field "$APP" spec.storage)" ];       then ARCH="C-http-sqlite-pvc"; CHECKS="check-gitops.sh check-workload.sh check-pvc.sh"
else                                                       ARCH="A-stateless-http"; CHECKS="check-gitops.sh check-workload.sh"
fi
[ "$ARCH" = "E-helm-chart" ] && CHECKS="check-helm.sh"   # pas de Component OpenChoreo pour un chart

# Mode sans cluster : GP_NO_CLUSTER=1, kubectl absent ou serveur injoignable -> NOT_TESTED, jamais PASS.
NO_CLUSTER=0
if [ "${GP_NO_CLUSTER:-0}" = 1 ] || ! command -v kubectl >/dev/null 2>&1 || ! k version --request-timeout=5s >/dev/null 2>&1; then
  NO_CLUSTER=1
fi

run() {
  header "$APP" "$ENV" "$ARCH"
  if [ "$NO_CLUSTER" = 1 ]; then
    record NOT_TESTED CLUSTER "aucun cluster joignable ou GP_NO_CLUSTER=1 : aucune observation runtime"
    return 0
  fi
  for c in $CHECKS; do
    echo "## $c"
    GP_NESTED=1 bash "$D/$c" "$APP" "$ENV" || true
  done
}

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if [ "$FORMAT" = json ]; then run >"$TMP" 2>&1; else run | tee "$TMP"; fi
p=$(grep -c '^PASS ' "$TMP" || true); f=$(grep -c '^FAIL ' "$TMP" || true)
n=$(grep -c '^NOT_TESTED ' "$TMP" || true); b=$(grep -c '^BLOCKED ' "$TMP" || true)
NC_FLAG=""; [ "$NO_CLUSTER" = 1 ] && NC_FLAG="--no-cluster"
# shellcheck disable=SC2086
JSON="$(python3 "$D/status_json.py" "$APP" "$ENV" "$ARCH" "$CLUSTER_LABEL" $NC_FLAG <"$TMP")"
if [ "$FORMAT" = json ]; then
  printf '%s\n' "$JSON"
else
  {
    echo "---"
    echo "summary: PASS=$p FAIL=$f NOT_TESTED=$n BLOCKED=$b"
    if [ "$f" -gt 0 ]; then echo "verdict: FAIL"
    elif [ "$NO_CLUSTER" = 1 ]; then echo "verdict: NOT_TESTED"
    elif [ $((n + b)) -gt 0 ]; then echo "verdict: PARTIAL"
    else echo "verdict: PASS"; fi
  } | tee -a "$TMP"
fi

if [ -n "$OUT" ]; then
  dir="$REPO_ROOT/$OUT/$CLUSTER_LABEL/$APP"; mkdir -p "$dir"
  ext=txt; [ "$FORMAT" = json ] && ext=json
  file="$dir/$(date -u +%Y%m%dT%H%M%SZ)-$ENV.$ext"
  if [ "$FORMAT" = json ]; then printf '%s\n' "$JSON" >"$file"; else cp "$TMP" "$file"; fi
  echo "evidence écrite : ${file#"$REPO_ROOT"/}" >&2
fi
[ "$f" -gt 0 ] && exit 1; [ $((n + b)) -gt 0 ] && exit 3; exit 0
