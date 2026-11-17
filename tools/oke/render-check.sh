#!/usr/bin/env bash
# render-check.sh : contrôle HORS CLUSTER des values épinglées (aucun accès à OKE ni à k3d).
# Télécharge les charts aux versions de platform/install/versions.env (sha256 vérifié), fait
# `helm template` avec platform/install/values/*.yaml, puis tools/oke/psa_check.py au niveau PSA
# prévu par namespace (restricted partout, baseline pour openchoreo-data-plane).
# Usage : tools/oke/render-check.sh   (python3 avec PyYAML requis ; sortie : rendus dans $STATE_DIR/render)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need helm python3 shasum
V="$INSTALL_DIR/values"
OUT="$STATE_DIR/render"
mkdir -p "$OUT"
rc=0

render() { # NOM RELEASE NAMESPACE TGZ VALUES NIVEAU
  helm template "$2" "$4" -n "$3" -f "$5" > "$OUT/$1.yaml"
  python3 -I "$ROOT/tools/oke/psa_check.py" "$6" "$OUT/$1.yaml" || rc=1
}

render cert-manager cert-manager openchoreo-cert-manager \
  "$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")" "$V/cert-manager.yaml" restricted
render external-secrets external-secrets openchoreo-external-secrets \
  "$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")" "$V/external-secrets.yaml" restricted
render kgateway kgateway openchoreo-control-plane \
  "$(fetch_chart kgateway "$KGATEWAY_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_TGZ_SHA256")" "$V/kgateway.yaml" restricted
render openchoreo-control-plane openchoreo-control-plane openchoreo-control-plane \
  "$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")" \
  "$V/openchoreo-control-plane.yaml" restricted
render openchoreo-data-plane openchoreo-data-plane openchoreo-data-plane \
  "$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")" \
  "$V/openchoreo-data-plane.yaml" baseline
render argocd argocd lab-argocd \
  "$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")" "$V/argocd.yaml" restricted
render cnpg cnpg cnpg-system \
  "$(fetch_chart cloudnative-pg "$CNPG_CHART" "$CNPG_VERSION" "$CNPG_TGZ_SHA256" "$CNPG_REPO")" \
  "$ROOT/platform/data/cnpg-operator-values.yaml" restricted
log "render-check rc=$rc (rendus : $OUT)"
exit "$rc"
