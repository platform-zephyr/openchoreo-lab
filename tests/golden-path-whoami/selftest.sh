#!/usr/bin/env bash
# selftest.sh : garde-fous verifies SANS cluster. Aucun appel reseau : chaque cas doit etre refuse AVANT kubectl
# (sauf `kubectl config current-context`, lecture locale du kubeconfig factice).
# Usage : tests/golden-path-whoami/selftest.sh   (code 0 = tous les cas attendus)
#
# shellcheck source=common.sh source-path=SCRIPTDIR
# Les commandes bash -c ci-dessous sont volontairement entre apostrophes (expansion differee).
# shellcheck disable=SC2016
. "$(dirname "$0")/common.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
fail=0

# Kubeconfigs factices : aucun serveur joignable, aucun jeton.
mkkc() { # mkkc FICHIER CONTEXTE
  cat > "$1" <<EOF
apiVersion: v1
kind: Config
current-context: $2
clusters: [{name: fake, cluster: {server: "https://127.0.0.1:9"}}]
contexts: [{name: $2, context: {cluster: fake, user: fake}}]
users: [{name: fake, user: {}}]
EOF
}
mkkc "$TMPD/homeops.yaml" "admin@homeops"
mkkc "$TMPD/other.yaml" "context-autre-cluster"

t() { # t NOM RC_ATTENDU commande...
  local name="$1" want="$2" rc
  shift 2
  "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then printf 'PASS %-62s rc=%s\n' "$name" "$rc"
  else printf 'FAIL %-62s rc=%s (attendu %s)\n' "$name" "$rc" "$want"; fail=1; fi
}

t "verify-http : KUBECONFIG absent -> BLOCKED" 2 env -u KUBECONFIG bash "$HERE/verify-http.sh"
t "verify-http : contexte admin@homeops -> BLOCKED" 2 env KUBECONFIG="$TMPD/homeops.yaml" bash "$HERE/verify-http.sh"
t "verify-http : contexte hors CONTEXT_RE -> BLOCKED" 2 env KUBECONFIG="$TMPD/other.yaml" bash "$HERE/verify-http.sh"
t "verify-change : CHANGE_SHA/BASE_SHA absents -> BLOCKED" 2 env -u CHANGE_SHA -u BASE_SHA KUBECONFIG="$TMPD/other.yaml" bash "$HERE/verify-change.sh"
t "verify-change : SHA inconnu -> BLOCKED" 2 env CHANGE_SHA=0000000000000000000000000000000000000001 BASE_SHA=0000000000000000000000000000000000000002 KUBECONFIG="$TMPD/other.yaml" bash "$HERE/verify-change.sh"
t "verify-rollback : arguments absents -> BLOCKED" 2 env -u REVERT_SHA -u CHANGE_SHA -u BASE_SHA KUBECONFIG="$TMPD/other.yaml" bash "$HERE/verify-rollback.sh"

# Wrapper k : verbes et Secrets refuses avant tout appel.
t "k : delete refuse" 2 bash -c '. "$1"; k delete ns x' _ "$COMMON_DIR/common.sh"
t "k : apply refuse" 2 bash -c '. "$1"; k apply -f x' _ "$COMMON_DIR/common.sh"
t "k : patch refuse" 2 bash -c '. "$1"; k patch deploy x' _ "$COMMON_DIR/common.sh"
t "k : exec refuse" 2 bash -c '. "$1"; k exec pod -- sh' _ "$COMMON_DIR/common.sh"
t "k : lecture de Secret refusee" 2 bash -c '. "$1"; k get secrets -n x' _ "$COMMON_DIR/common.sh"
t "k : auth reconcile refuse" 2 bash -c '. "$1"; k auth reconcile -f x' _ "$COMMON_DIR/common.sh"

if [ "$fail" = 0 ]; then echo "selftest : OK"; exit 0; fi
echo "selftest : ECHEC"; exit 1
