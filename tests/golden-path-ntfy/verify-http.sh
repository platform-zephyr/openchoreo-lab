#!/usr/bin/env bash
# verify-http.sh : etat runtime de ntfy (golden path n°2, stateless) sur OKE. LECTURE SEULE, aucune exposition.
#
# Controle : Argo lab-apps Synced/Healthy (+ revision) ; ReleaseBinding Ready ; ComponentRelease presente ;
# pod Ready ; securityContext PSA restricted ; Service ClusterIP ; 0 PVC, 0 LoadBalancer, 0 route externe, 0 base ;
# variable NTFY_LOG_LEVEL (valeur attendue ou absente) ; HTTP 200 sur /v1/health via `kubectl port-forward`
# vers svc/ntfy (tunnel local 127.0.0.1 : aucune route, aucun LoadBalancer).
#
# Usage :
#   KUBECONFIG=<kubeconfig OKE> tests/golden-path-ntfy/verify-http.sh
#   KUBECONFIG=... EXPECT_REVISION=<sha complet> EXPECT_RELEASE=ntfy-xxxx EXPECT_LOG_LEVEL=DEBUG \
#     tests/golden-path-ntfy/verify-http.sh
#   KUBECONFIG=... LOG_LEVEL_ABSENT=1 tests/golden-path-ntfy/verify-http.sh     # apres revert
# Code retour : 0 PASS ; 1 FAIL ; 2 BLOCKED (prerequis non remplis) ; 3 PARTIAL (aucun FAIL, NOT_TESTED/BLOCKED).
#
# shellcheck source=../golden-path-whoami/common.sh source-path=SCRIPTDIR
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# common.sh est partage avec whoami : il lit WHOAMI_APP. Ce script cible ntfy, valeur IMPOSEE (pas heritee).
WHOAMI_APP=ntfy
export WHOAMI_APP
. "$HERE/../golden-path-whoami/common.sh"

NTFY_PORT=8080

env_value() { # env_value NS VAR : valeur de VAR dans le pod (env direct, sinon ConfigMap envFrom OpenChoreo)
  local ns="$1" var="$2" dep v cm
  dep="$(k get deploy -n "$ns" -l "openchoreo.dev/component=$WHOAMI_APP" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [ -n "$dep" ] || return 0
  v="$(k get deploy "$dep" -n "$ns" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"$var\")].value}" 2>/dev/null || true)"
  if [ -z "$v" ]; then
    cm="$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}' 2>/dev/null || true)"
    [ -n "$cm" ] && v="$(k get configmap "$cm" -n "$ns" -o jsonpath="{.data.$var}" 2>/dev/null || true)"
  fi
  printf '%s' "$v"
}

probe_ntfy() { # probe_ntfy NS : GET /v1/health via tunnel port-forward local (corps non journalise)
  local ns="$1" port pf_pid pf_log body code="" ok=0
  port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
  pf_log="$(mktemp)"; body="$(mktemp)"
  kubectl -n "$ns" port-forward "svc/$WHOAMI_APP" "$port:$NTFY_PORT" --address 127.0.0.1 >"$pf_log" 2>&1 &
  pf_pid=$!
  for _try in $(seq 1 20); do
    code="$(curl -s -o "$body" -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/v1/health" || true)"
    if [ "$code" = "200" ]; then ok=1; break; fi
    sleep 1
  done
  if [ "$ok" = 1 ]; then
    expect H1 "GET /v1/health via tunnel local (tunnel, pas d'exposition)" "$code" "200"
    if grep -qF '"healthy":true' "$body"; then rec PASS H2 "reponse ntfy reconnue (healthy=true)"; else rec FAIL H2 "reponse /v1/health inattendue"; fi
  else
    rec FAIL H1 "pas de 200 sur /v1/health via port-forward (dernier code '${code:-vide}')"
    sed 's/^/  pf: /' "$pf_log" | head -n 5
  fi
  kill "$pf_pid" 2>/dev/null || true
  wait "$pf_pid" 2>/dev/null || true
  rm -f "$pf_log" "$body"
}

print_header
preflight || { verdict; exit 2; }

NS="$(cell_ns)"
if [ -z "$NS" ]; then
  rec FAIL N0 "namespace de cellule dp-* introuvable pour $WHOAMI_APP/$WHOAMI_ENV"
  verdict; exit 1
fi
rec INFO N0 "cellule : $NS"

check_gitops "${EXPECT_REVISION:-}" "${EXPECT_RELEASE:-}"
check_runtime "$NS" "" ""
check_scope "$NS"

# Variable de changement GitOps (NTFY_LOG_LEVEL) : valeur attendue, ou absente (retour a la base).
lvl="$(env_value "$NS" NTFY_LOG_LEVEL)"
if [ -n "${EXPECT_LOG_LEVEL:-}" ]; then
  expect N6 "NTFY_LOG_LEVEL dans le pod" "$lvl" "$EXPECT_LOG_LEVEL"
elif [ -n "${LOG_LEVEL_ABSENT:-}" ]; then
  if [ -z "$lvl" ]; then rec PASS N6 "NTFY_LOG_LEVEL absent du pod (retour a la base)"; else rec FAIL N6 "NTFY_LOG_LEVEL encore present ($lvl)"; fi
fi

probe_ntfy "$NS"
verdict
