#!/usr/bin/env bash
# verify-http.sh : etat runtime de whoami sur OKE. LECTURE SEULE, aucune exposition publique.
#
# Controle : Argo CD lab-o-whoami Synced/Healthy ; ReleaseBinding Ready ; ComponentRelease presente ;
# pod Ready ; securityContext ; Service ClusterIP ; 0 PVC, 0 LoadBalancer, 0 route externe, 0 base ;
# HTTP 200 sur /health et / via `kubectl port-forward` vers svc/whoami (tunnel local 127.0.0.1).
#
# Usage :
#   KUBECONFIG=<kubeconfig OKE> tests/golden-path-whoami/verify-http.sh
#   KUBECONFIG=... EXPECT_REVISION=<sha complet> EXPECT_RELEASE=whoami-xxxx \
#     EXPECT_NAME=<valeur> NAME_ABSENT=<valeur> tests/golden-path-whoami/verify-http.sh
# Code retour : 0 PASS ; 1 FAIL ; 2 BLOCKED (prerequis non remplis) ; 3 PARTIAL (aucun FAIL, mais NOT_TESTED/BLOCKED).
#
# shellcheck source=common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/common.sh"

print_header
preflight || { verdict; exit 2; }

NS="$(cell_ns)"
if [ -z "$NS" ]; then
  rec FAIL W0 "namespace de cellule dp-* introuvable pour $WHOAMI_APP/$WHOAMI_ENV"
  verdict; exit 1
fi
rec INFO W0 "cellule : $NS"

check_gitops "${EXPECT_REVISION:-}" "${EXPECT_RELEASE:-}"
check_runtime "$NS" "${EXPECT_NAME:-}" "${NAME_ABSENT:-}"
check_scope "$NS"
probe_http "$NS" "${EXPECT_NAME:-}" "${NAME_ABSENT:-}"
verdict
