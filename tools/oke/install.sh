#!/usr/bin/env bash
# install.sh : installation de la Phase B (OpenChoreo 1.3.3 minimal) sur OKE oracle-a1.
# NON EXÉCUTÉ à la rédaction (2026-11-17). Plan, critères de sortie et rollback : docs/PHASE-B.md §2.
#
# Usage : tools/oke/install.sh [--step N | --from N --to M] [--apply] [--confirm-storage]
#   - DRY-RUN PAR DÉFAUT : affiche les commandes, ne modifie rien (le contexte est quand même vérifié).
#   - --apply : exécute. Chaque étape est idempotente (helm upgrade --install, kubectl apply --server-side).
#   - Étapes 1 à 11 par défaut ; 12 (RBAC réduit du cluster-agent) seulement avec --step 12.
#   - --confirm-storage : requis pour l'étape 10 (lab-pg = 1 block volume OCI de 50 Go), après accord
#     de Paul sur le budget de stockage (docs/PHASE-B.md §4).
# Après chaque étape (3 à 12) : mesure au repos de la pile et ARRÊT (code 3) si > 1,5 Gi ou > 300m.
# Puis lancer tools/oke/verify.sh --step N (critère de sortie) avant l'étape suivante.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FROM=1 TO=11 CONFIRM_STORAGE=0
while (($#)); do
  case "$1" in
    --step) FROM="$2"; TO="$2"; shift 2;;
    --from) FROM="$2"; shift 2;;
    --to) TO="$2"; shift 2;;
    --apply) APPLY=1; shift;;
    --confirm-storage) CONFIRM_STORAGE=1; shift;;
    -h|--help) sed -n '2,13p' "$0"; exit 0;;
    *) die "argument inconnu : $1";;
  esac
done
export APPLY

need kubectl helm jq yq curl shasum base64
guard_context
mkdir -p "$STATE_DIR"
V="$INSTALL_DIR/values"
M="$INSTALL_DIR/manifests"
KA=(kubectl apply --server-side --field-manager=openchoreo-lab)

step_1() { # Socle : namespaces, quotas, réseau
  run "${KA[@]}" -f "$M/00-namespaces.yaml"
  run "${KA[@]}" -f "$M/01-quotas.yaml"
  run "${KA[@]}" -f "$M/02-network-policies.yaml"
}

step_2() { # Gateway API CRD (standard v1.5.1), manifest vérifié par sha256
  local f="$STATE_DIR/gateway-api-$GW_CRDS_VERSION.yaml" got
  [[ -f "$f" ]] || curl -fsSL -o "$f" "$GW_CRDS_URL"
  got="$(shasum -a 256 "$f" | awk '{print $1}')"
  [[ "$got" == "$GW_CRDS_SHA256" ]] || die "sha256 Gateway API : $got != $GW_CRDS_SHA256"
  run "${KA[@]}" -f "$f"
  run kubectl wait --for=condition=Established --timeout=120s crd/gateways.gateway.networking.k8s.io crd/httproutes.gateway.networking.k8s.io
}

step_3() { # cert-manager
  local tgz; tgz="$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")"
  run helm upgrade --install cert-manager "$tgz" -n openchoreo-cert-manager -f "$V/cert-manager.yaml" --wait --timeout 5m
}

step_4() { # External Secrets Operator + store lab-store
  local tgz; tgz="$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")"
  run helm upgrade --install external-secrets "$tgz" -n openchoreo-external-secrets -f "$V/external-secrets.yaml" --wait --timeout 5m
  run "${KA[@]}" -f "$M/20-eso-lab-store.yaml"
  run kubectl wait --for=condition=Ready --timeout=120s clustersecretstore/lab-store
}

step_5() { # kgateway (CRD puis contrôleur), namespace openchoreo-control-plane
  local crds ctl
  crds="$(fetch_chart kgateway-crds "$KGATEWAY_CRDS_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_CRDS_TGZ_SHA256")"
  ctl="$(fetch_chart kgateway "$KGATEWAY_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_TGZ_SHA256")"
  run helm upgrade --install kgateway-crds "$crds" -n openchoreo-control-plane --wait
  run helm upgrade --install kgateway "$ctl" -n openchoreo-control-plane -f "$V/kgateway.yaml" --wait --timeout 5m
}

# Copie la CA PUBLIQUE du cluster-gateway (ca.crt seulement) dans les ConfigMap des deux plans.
# À refaire après chaque `helm upgrade` du CP (le chart réécrit un ConfigMap placeholder).
copy_gateway_ca() {
  if [[ "$APPLY" != 1 ]]; then echo "[dry-run] copie ca.crt de secret/cluster-gateway-ca vers configmap/cluster-gateway-ca (CP et DP)"; return; fi
  local ns
  kubectl -n openchoreo-control-plane wait --for=condition=Ready --timeout=180s certificate/cluster-gateway-ca
  for ns in openchoreo-control-plane openchoreo-data-plane; do
    kubectl -n openchoreo-control-plane get secret cluster-gateway-ca -o jsonpath='{.data.ca\.crt}' | base64 -d \
      | kubectl create configmap cluster-gateway-ca --from-file=ca.crt=/dev/stdin -n "$ns" --dry-run=client -o yaml \
      | kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f - >/dev/null
  done
  log "ConfigMap cluster-gateway-ca peuplés (CP, DP)"
}

step_6() { # OpenChoreo control plane (CRD du chart à la 1re installation)
  local tgz; tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
  # Mise à jour des CRD (Helm ne les met jamais à jour) : server-side, avant l'upgrade (upgrades/overview.mdx).
  if [[ "$APPLY" == 1 ]] && kubectl get crd components.openchoreo.dev >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp -d)"; tar -xzf "$tgz" -C "$tmp"
    kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f "$tmp/openchoreo-control-plane/crds/"
    rm -rf "$tmp"
  fi
  run helm upgrade --install openchoreo-control-plane "$tgz" -n openchoreo-control-plane \
    -f "$V/openchoreo-control-plane.yaml" --wait --timeout 10m
  wait_deploys openchoreo-control-plane
  copy_gateway_ca
  run kubectl -n openchoreo-control-plane rollout restart deployment/controller-manager deployment/openchoreo-api deployment/cluster-gateway
  wait_deploys openchoreo-control-plane
}

step_7() { # VAP du labo + RBAC quota du cluster-agent + TLS/Envoy + OpenChoreo data plane
  # Les VAP passent AVANT que le cluster-agent existe : aucune écriture de l'agent n'échappe à VAP-1.
  run "${KA[@]}" -f "$ROOT/platform/policies/"
  run "${KA[@]}" -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml"
  run "${KA[@]}" -f "$M/11-gateway-tls.yaml"
  run kubectl -n openchoreo-data-plane wait --for=condition=Ready --timeout=120s certificate/dp-gateway-tls
  run "${KA[@]}" -f "$M/12-gateway-parameters.yaml"
  copy_gateway_ca
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  run helm upgrade --install openchoreo-data-plane "$tgz" -n openchoreo-data-plane \
    -f "$V/openchoreo-data-plane.yaml" --wait --timeout 10m
  run kubectl -n openchoreo-data-plane wait --for=condition=Ready --timeout=180s certificate/cluster-agent-dataplane-tls
  run kubectl -n openchoreo-data-plane wait --for=condition=Programmed --timeout=180s gateway/gateway-default
}

step_8() { # Enregistrement mTLS single-cluster : ClusterDataPlane avec la CA client de l'agent
  if [[ "$APPLY" != 1 ]]; then echo "[dry-run] ClusterDataPlane default <- ca.crt de secret/cluster-agent-tls (30-clusterdataplane.yaml.tmpl)"; return; fi
  local ca
  ca="$(kubectl -n openchoreo-data-plane get secret cluster-agent-tls -o jsonpath='{.data.ca\.crt}' | base64 -d)"
  [[ "$ca" == "-----BEGIN CERTIFICATE-----"* ]] || die "ca.crt de cluster-agent-tls absent ou invalide"
  # Indentation de 8 espaces sous `value: |` ; seule la CA publique transite (aucune clé privée).
  CA_INDENTED="        ${ca//$'\n'/$'\n'        }" awk '
    $0 == "__AGENT_CA__" { print ENVIRON["CA_INDENTED"]; next } { print }' "$M/30-clusterdataplane.yaml.tmpl" \
    | kubectl apply --server-side --field-manager=openchoreo-lab -f -
}

step_9() { # Types, environnement, pipeline et traits du labo (namespace default = objets OpenChoreo seulement)
  run kubectl label namespace default openchoreo.dev/control-plane=true --overwrite
  run "${KA[@]}" -f "$M/40-openchoreo-env.yaml"
  run "${KA[@]}" -f "$ROOT/platform/component-types/" -f "$ROOT/platform/traits/" \
    -f "$ROOT/platform/project-types/" -f "$ROOT/platform/resource-types/"
}

step_10() { # Opérateur CNPG + lab-pg (1 PVC = 1 block volume OCI de 50 Go)
  [[ "$CONFIRM_STORAGE" == 1 || "$APPLY" != 1 ]] || die "étape 10 : --confirm-storage requis (accord de Paul sur 50 Go de block volume)"
  local tgz; tgz="$(fetch_chart cloudnative-pg "$CNPG_CHART" "$CNPG_VERSION" "$CNPG_TGZ_SHA256" "$CNPG_REPO")"
  run helm upgrade --install cnpg "$tgz" -n cnpg-system -f "$ROOT/platform/data/cnpg-operator-values.yaml" --wait --timeout 5m
  run "${KA[@]}" -f "$ROOT/platform/data/lab-pg-namespace.yaml"
  # Labels absents de platform/data (hors périmètre) : sélection par uninstall.sh et marqueur C1.
  run kubectl label namespace lab-pg app.kubernetes.io/part-of=openchoreo-lab platform.smadja.dev/egress-isolated=true --overwrite
  run "${KA[@]}" -f "$M/51-lab-pg-oke-overlay.yaml"
  run "${KA[@]}" -f "$ROOT/platform/data/lab-pg-cluster.yaml"
  run kubectl -n lab-pg wait --for=condition=Ready --timeout=600s cluster.postgresql.cnpg.io/lab-pg
}

step_11() { # Argo CD minimal + AppProject lab + Application racine (adopte les objets des étapes 9-10)
  local tgz; tgz="$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")"
  run helm upgrade --install argocd "$tgz" -n lab-argocd -f "$V/argocd.yaml" --wait --timeout 10m
  run "${KA[@]}" -f "$INSTALL_DIR/argocd/project-lab.yaml"
  run "${KA[@]}" -f "$INSTALL_DIR/argocd/root-application.yaml"
}

step_12() { # OPTIONNEL : RBAC réduit du cluster-agent (platform/cluster-agent/reduced-clusterrole.yaml)
  # Le ClusterRole réduit est posé AVANT de retirer celui du chart : aucune fenêtre sans droits.
  run "${KA[@]}" -f "$ROOT/platform/cluster-agent/reduced-clusterrole.yaml"
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  run helm upgrade --install openchoreo-data-plane "$tgz" -n openchoreo-data-plane \
    -f "$V/openchoreo-data-plane.yaml" --set clusterAgent.rbac.create=false --wait --timeout 10m
}

for ((n = FROM; n <= TO; n++)); do
  declare -F "step_$n" >/dev/null || die "étape inconnue : $n"
  log "=== étape $n (APPLY=$APPLY)"
  "step_$n"
  if (( n >= 3 )); then budget_gate "étape $n"; fi
  [[ "$APPLY" != 1 ]] || printf '%s étape %s appliquée\n' "$(date -u +%FT%TZ)" "$n" >> "$STATE_DIR/steps.log"
done
log "terminé (étapes $FROM..$TO). Suite : tools/oke/verify.sh --step $TO"
