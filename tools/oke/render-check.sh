#!/usr/bin/env bash
# render-check.sh : contrôle HORS CLUSTER des values épinglées (aucun accès à OKE ni à k3d).
# Télécharge les charts aux versions de platform/install/versions.env (sha256 vérifié, cache Helm isolé
# sous STATE_DIR), fait `helm template` avec platform/install/values/*.yaml, puis :
#   - tools/oke/psa_check.py au niveau PSA prévu par namespace (restricted partout, baseline pour le DP) ;
#   - 0 PVC / volumeClaimTemplates, 0 Service LoadBalancer ou NodePort, 0 image sans digest.
# Le CP est rendu deux fois : étape 6 (backstage.enabled=false) et 6b (portail actif).
# Usage : tools/oke/render-check.sh   (python3 avec PyYAML, yq requis ; sortie : rendus dans $STATE_DIR/render)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need helm python3 shasum yq
V="$INSTALL_DIR/values"
OUT="$STATE_DIR/render"
mkdir -p "$OUT"
rc=0

render() { # NOM RELEASE NAMESPACE TGZ VALUES NIVEAU [ARGS helm...]
  local name="$1" rel="$2" ns="$3" tgz="$4" values="$5" level="$6" f n
  shift 6
  f="$OUT/$name.yaml"
  helm template "$rel" "$tgz" -n "$ns" -f "$values" "$@" > "$f"
  python3 -I "$ROOT/tools/oke/psa_check.py" "$level" "$f" || rc=1
  n="$(yq -N 'select(.kind == "PersistentVolumeClaim" or (.spec.volumeClaimTemplates // [] | length) > 0) | .kind + "/" + .metadata.name' "$f")"
  [[ -z "$n" ]] || { log "$name : PVC rendus : $n"; rc=1; }
  n="$(yq -N 'select(.kind == "Service" and (.spec.type == "LoadBalancer" or .spec.type == "NodePort")) | .metadata.name' "$f")"
  [[ -z "$n" ]] || { log "$name : Service LoadBalancer/NodePort : $n"; rc=1; }
  n="$(yq -N '.. | select(has("image") and (.image | type) == "!!str") | .image | select(test("@sha256:") | not)' "$f" | sort -u)"
  [[ -z "$n" ]] || { log "$name : images sans digest : $n"; rc=1; }
  log "$name : rendu OK ($(yq -N 'select(.kind) | .kind' "$f" | wc -l | tr -d ' ') objets)"
}

CP_TGZ="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
render cert-manager cert-manager openchoreo-cert-manager \
  "$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")" "$V/cert-manager.yaml" restricted
render external-secrets external-secrets openchoreo-external-secrets \
  "$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")" "$V/external-secrets.yaml" restricted
render kgateway kgateway openchoreo-control-plane \
  "$(fetch_chart kgateway "$KGATEWAY_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_TGZ_SHA256")" "$V/kgateway.yaml" restricted
# T-060 : le filtre RBAC doit accepter le rendu réel du chart et ne laisser aucun `secrets` au ClusterRole.
n="$(python3 -I "$ROOT/tools/oke/kgateway-rbac.py" --rbac-only < "$OUT/kgateway.yaml" \
  | yq -N 'select(.kind == "ClusterRole") | .rules[] | select((.resources // []) | contains(["secrets"])) | .verbs | join(",")')" \
  || { log "kgateway : filtre RBAC en échec sur le rendu du chart"; rc=1; }
[[ -z "$n" ]] || { log "kgateway : ClusterRole avec secrets après filtre : $n"; rc=1; }
render openchoreo-control-plane openchoreo-control-plane openchoreo-control-plane \
  "$CP_TGZ" "$V/openchoreo-control-plane.yaml" restricted --set backstage.enabled=false
render openchoreo-control-plane-portal openchoreo-control-plane openchoreo-control-plane \
  "$CP_TGZ" "$V/openchoreo-control-plane.yaml" restricted
render openchoreo-data-plane openchoreo-data-plane openchoreo-data-plane \
  "$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")" \
  "$V/openchoreo-data-plane.yaml" baseline
render argocd argocd lab-argocd \
  "$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")" "$V/argocd.yaml" restricted
render cnpg cnpg lab-cnpg \
  "$(fetch_chart cloudnative-pg "$CNPG_CHART" "$CNPG_VERSION" "$CNPG_TGZ_SHA256" "$CNPG_REPO")" \
  "$ROOT/platform/data/cnpg-operator-values.yaml" restricted
log "render-check rc=$rc (rendus : $OUT)"
exit "$rc"
