#!/usr/bin/env bash
# kubeconform-platform.sh : validation HORS CLUSTER (kubeconform -strict) de platform/install/manifests/*.yaml,
# platform/install/argocd/**/*.yaml, platform/authz/*.yaml (CRD OpenChoreo du chart CP, docs/AGENT-ACCESS.md),
# platform/baseline/*.yaml et du rendu du chart Cilium de l'étape 0 (T-494) ; puis tools/oke/baseline-source.sh
# (copies de kube-ops non modifiées, sans réseau).
# Aucun accès à OKE ni à k3d.
# Schémas des CRD tierces : extraits des CRD RENDUES des charts épinglés (versions.env, sha256 vérifié par
# fetch_chart ; Gateway API par fetch_gw_crds), plus CiliumNetworkPolicy et CiliumClusterwideNetworkPolicy (tools/appgen/fetch-ext-schemas.sh,
# sha256 épinglé). Schémas Kubernetes : emplacement par défaut de kubeconform. Aucun schéma manquant toléré.
# Usage : tools/oke/kubeconform-platform.sh   (helm, kubeconform, python3 + PyYAML, curl, shasum)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need helm kubeconform python3 curl shasum
V="$INSTALL_DIR/values"
W="$STATE_DIR/kubeconform"
rm -rf "$W"; mkdir -p "$W/crds" "$W/schemas"

{
  helm template x "$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")" \
    --include-crds -f "$V/cert-manager.yaml"; echo '---'
  helm template x "$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")" \
    --include-crds -f "$V/external-secrets.yaml"; echo '---'
  helm template x "$(fetch_chart kgateway-crds "$KGATEWAY_CRDS_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_CRDS_TGZ_SHA256")" \
    --include-crds; echo '---'
  helm template x "$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")" \
    -n openchoreo-control-plane --include-crds -f "$V/openchoreo-control-plane.yaml" --set backstage.enabled=false; echo '---'
  helm template x "$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")" \
    -n lab-argocd --include-crds -f "$V/argocd.yaml"; echo '---'
  cat "$(fetch_gw_crds)"
} > "$W/all.yaml"
# Étape 0 : rendu du chart Cilium épinglé avec les values copiées de kube-ops (validé tel quel ci-dessous).
helm template cilium "$(fetch_chart cilium "$CILIUM_CHART" "$CILIUM_VERSION" "$CILIUM_TGZ_SHA256" "$CILIUM_REPO")" \
  -n kube-system -f "$V/cilium.yaml" > "$W/cilium.yaml"

python3 -I - "$W/all.yaml" "$W/crds" <<'PY'
import pathlib, sys, yaml
out = pathlib.Path(sys.argv[2]); n = 0
for d in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")):
    if isinstance(d, dict) and d.get("kind") == "CustomResourceDefinition":
        (out / f"{d['metadata']['name']}.yaml").write_text(yaml.safe_dump(d), encoding="utf-8"); n += 1
print(f"kubeconform-platform : {n} CRD extraites des rendus épinglés")
PY
python3 -I "$ROOT/tools/appgen/crd2schema.py" "$W/crds" "$W/schemas"
"$ROOT/tools/appgen/fetch-ext-schemas.sh" "$W/ext"
mkdir -p "$W/schemas/cilium.io" && cp "$W/ext/cilium.io/"*.json "$W/schemas/cilium.io/"

kubeconform -strict -summary -schema-location default \
  -schema-location "$W/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  "$INSTALL_DIR"/manifests/*.yaml "$INSTALL_DIR"/argocd/*.yaml "$INSTALL_DIR"/argocd/apps/*.yaml \
  "$ROOT"/platform/authz/*.yaml "$ROOT"/platform/baseline/*.yaml "$W/cilium.yaml"
"$ROOT/tools/oke/baseline-source.sh"
