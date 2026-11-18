#!/usr/bin/env bash
# ci-bootstrap.sh : pile OpenChoreo 1.3.3 minimale sur un k3d JETABLE (un cluster par job CI).
# Reprend les étapes 1, 2 à 9 de tools/oke/install.sh avec les mêmes charts, values et sha256 (versions.env),
# sans leurs gardes OKE (contexte, budget, stockage). Hors périmètre, volontairement :
#   - 02-network-policies.yaml : CiliumNetworkPolicy (Cilium n'existe pas sur k3d) ;
#   - étape 10 (CNPG + lab-pg) : déployée par tests/k3d/run.sh lui-même ;
#   - étape 11 (Argo CD) : seuls tests/gitops-k3d et tests/argo-escalation en ont besoin, et ils l'installent eux-mêmes ;
#   - étape 12 (RBAC réduit du cluster-agent) : non rejouée.
# Usage : tools/k3d/ci-bootstrap.sh <nom-du-cluster>   (contexte attendu : k3d-<nom>, un seul nœud arm64)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER="${1:?usage : ci-bootstrap.sh <nom-du-cluster>}"
export OKE_PHASEB_STATE="${OKE_PHASEB_STATE:-$(mktemp -d)}"
# shellcheck source=../oke/lib.sh
. "$ROOT/tools/oke/lib.sh"
APPLY=1
export APPLY

need kubectl helm shasum curl jq
ctx="$(kubectl config current-context)"
[[ "$ctx" == "k3d-$CLUSTER" ]] || die "contexte '$ctx' != k3d-$CLUSTER (ce bootstrap ne tourne que sur k3d jetable)"
nodes="$(kubectl get nodes -o json)"
[[ "$(jq '.items | length' <<<"$nodes")" == 1 ]] || die "nombre de nœuds != 1"

M="$INSTALL_DIR/manifests"
V="$INSTALL_DIR/values"
KA=(kubectl apply --server-side --field-manager=openchoreo-lab)

# Copie la CA PUBLIQUE du cluster-gateway dans les ConfigMap des deux plans (identique à install.sh).
copy_gateway_ca() {
  local ns
  kubectl -n openchoreo-control-plane wait --for=condition=Ready --timeout=180s certificate/cluster-gateway-ca
  for ns in openchoreo-control-plane openchoreo-data-plane; do
    kubectl -n openchoreo-control-plane get secret cluster-gateway-ca -o jsonpath='{.data.ca\.crt}' | base64 -d \
      | kubectl create configmap cluster-gateway-ca --from-file=ca.crt=/dev/stdin -n "$ns" --dry-run=client -o yaml \
      | kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f - >/dev/null
  done
  log "ConfigMap cluster-gateway-ca peuplés (CP, DP)"
}

log "1. socle : namespaces, quotas (02-network-policies sauté : Cilium)"
"${KA[@]}" -f "$M/00-namespaces.yaml"
"${KA[@]}" -f "$M/01-quotas.yaml"

log "2. Gateway API CRD (sha256 épinglé)"
gw="$(fetch_gw_crds)"
"${KA[@]}" -f "$gw"
kubectl wait --for=condition=Established --timeout=120s crd/gateways.gateway.networking.k8s.io crd/httproutes.gateway.networking.k8s.io

log "3. cert-manager"
tgz="$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")"
helm upgrade --install cert-manager "$tgz" -n openchoreo-cert-manager -f "$V/cert-manager.yaml" --wait --timeout 5m

log "4. External Secrets Operator + lab-store"
tgz="$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")"
helm upgrade --install external-secrets "$tgz" -n openchoreo-external-secrets -f "$V/external-secrets.yaml" --wait --timeout 5m
"${KA[@]}" -f "$M/20-eso-lab-store.yaml"
kubectl wait --for=condition=Ready --timeout=120s clustersecretstore/lab-store

log "5. kgateway (CRD puis contrôleur)"
crds="$(fetch_chart kgateway-crds "$KGATEWAY_CRDS_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_CRDS_TGZ_SHA256")"
ctl="$(fetch_chart kgateway "$KGATEWAY_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_TGZ_SHA256")"
helm upgrade --install kgateway-crds "$crds" -n openchoreo-control-plane --wait
helm upgrade --install kgateway "$ctl" -n openchoreo-control-plane -f "$V/kgateway.yaml" --wait --timeout 5m

log "6. OpenChoreo control plane"
tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
helm upgrade --install openchoreo-control-plane "$tgz" -n openchoreo-control-plane -f "$V/openchoreo-control-plane.yaml" --wait --timeout 10m
wait_deploys openchoreo-control-plane
copy_gateway_ca
kubectl -n openchoreo-control-plane rollout restart deployment/controller-manager deployment/openchoreo-api deployment/cluster-gateway
wait_deploys openchoreo-control-plane

log "7. VAP du labo, RBAC quota, TLS/Envoy, data plane"
"${KA[@]}" -f "$ROOT/platform/policies/"
"${KA[@]}" -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml"
"${KA[@]}" -f "$M/11-gateway-tls.yaml"
kubectl -n openchoreo-data-plane wait --for=condition=Ready --timeout=120s certificate/dp-gateway-tls
"${KA[@]}" -f "$M/12-gateway-parameters.yaml"
copy_gateway_ca
tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
helm upgrade --install openchoreo-data-plane "$tgz" -n openchoreo-data-plane -f "$V/openchoreo-data-plane.yaml" --wait --timeout 10m
kubectl -n openchoreo-data-plane wait --for=condition=Ready --timeout=180s certificate/cluster-agent-dataplane-tls
kubectl -n openchoreo-data-plane wait --for=condition=Programmed --timeout=180s gateway/gateway-default

log "8. enregistrement du data plane (ClusterDataPlane default, CA publique de l'agent)"
ca="$(kubectl -n openchoreo-data-plane get secret cluster-agent-tls -o jsonpath='{.data.ca\.crt}' | base64 -d)"
[[ "$ca" == "-----BEGIN CERTIFICATE-----"* ]] || die "ca.crt de cluster-agent-tls absent ou invalide"
CA_INDENTED="        ${ca//$'\n'/$'\n'        }" awk '
  $0 == "__AGENT_CA__" { print ENVIRON["CA_INDENTED"]; next } { print }' "$M/30-clusterdataplane.yaml.tmpl" \
  | kubectl apply --server-side --field-manager=openchoreo-lab -f -

log "9. types, environnement, traits du labo"
kubectl label namespace default openchoreo.dev/control-plane=true --overwrite
"${KA[@]}" -f "$M/40-openchoreo-env.yaml"
"${KA[@]}" -f "$ROOT/platform/component-types/" -f "$ROOT/platform/traits/" \
  -f "$ROOT/platform/project-types/" -f "$ROOT/platform/resource-types/"

log "bootstrap OpenChoreo termine sur k3d-$CLUSTER"
