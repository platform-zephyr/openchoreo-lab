#!/usr/bin/env bash
# install.sh : installation de la Phase B (OpenChoreo 1.3.3 minimal) sur OKE oracle-a1.
# Étapes 1 à 5 appliquées sur OKE le 2026-11-17 (18:22-18:28Z, $STATE_DIR/steps.log) ; 6 et suivantes
# non exécutées. Plan, critères de sortie et rollback : docs/PHASE-B.md §2.
#
# Usage : tools/oke/install.sh [--step N | --from N --to M] [--with-portal] [--apply] [--confirm-storage]
#   - N, M dans l'ordre 1 2 3 4 5 6 6b 7 8 9 10 11 12.
#   - DRY-RUN PAR DÉFAUT : affiche les commandes ; seules des LECTURES touchent le cluster (garde de
#     contexte, gardes de préconditions) ; téléchargements locaux (charts, CRD) dans STATE_DIR.
#   - --apply : exécute. Chaque étape est idempotente (helm upgrade --install, kubectl apply --server-side).
#   - Étapes 1 à 11 par défaut ; 6b (portail, docs/PORTAL.md) seulement si nommée (--step 6b, --from/--to 6b)
#     ou avec --with-portal ; 12 (RBAC réduit du cluster-agent) seulement si nommée.
#   - --confirm-storage : requis pour l'étape 10 (lab-pg = 1 block volume OCI de 50 Go), après accord
#     de Paul sur le budget de stockage (docs/PHASE-B.md §4).
# Après chaque étape (3 à 12) : mesure au repos de la pile et ARRÊT (code 3) si > 1,5 Gi ou > 300m.
# Puis lancer tools/oke/verify.sh --step N (critère de sortie) avant l'étape suivante.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FROM=1 TO=11 CONFIRM_STORAGE=0 WITH_PORTAL=0
ORDER=(1 2 3 4 5 6 6b 7 8 9 10 11 12)
while (($#)); do
  case "$1" in
    --step) FROM="$2"; TO="$2"; shift 2;;
    --from) FROM="$2"; shift 2;;
    --to) TO="$2"; shift 2;;
    --with-portal) WITH_PORTAL=1; shift;;
    --apply) APPLY=1; shift;;
    --confirm-storage) CONFIRM_STORAGE=1; shift;;
    -h|--help) sed -n '2,17p' "$0"; exit 0;;
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

# Garde I3 (revue) : un namespace que l'installation va étiqueter part-of=openchoreo-lab doit soit ne pas
# exister, soit porter DÉJÀ ce label (reprise). Un namespace préexistant sans le label n'est pas à nous :
# arrêt, jamais de réétiquetage. Lecture seule, aussi en dry-run. Fichier : manifest contenant les Namespace.
guard_ns_ownership() {
  local f="$1" ns out part
  for ns in $(yq -N 'select(.kind == "Namespace") | .metadata.name' "$f"); do
    out="$(kubectl get namespace "$ns" --ignore-not-found -o name)" || die "lecture du namespace $ns en erreur"
    [[ -n "$out" ]] || continue
    part="$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" \
      || die "labels du namespace $ns illisibles"
    [[ "$part" == openchoreo-lab ]] \
      || die "namespace $ns préexistant SANS label part-of=openchoreo-lab (part-of='$part') : hors essai, refus"
  done
}

step_1() { # Socle : namespaces, quotas, réseau
  guard_ns_ownership "$M/00-namespaces.yaml"
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

# cp_upgrade PORTAIL(true|false) : helm upgrade du CP (values uniques, portail activé ou non), puis CA.
cp_upgrade() {
  local portal="$1" tgz
  tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
  # Mise à jour des CRD (Helm ne les met jamais à jour) : server-side, avant l'upgrade (upgrades/overview.mdx).
  if [[ "$APPLY" == 1 ]] && kubectl get crd components.openchoreo.dev >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp -d)"; tar -xzf "$tgz" -C "$tmp"
    kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f "$tmp/openchoreo-control-plane/crds/"
    rm -rf "$tmp"
  fi
  # Egress vers Authentik (JWKS de l'API, OIDC du portail) posé AVANT les pods.
  run "${KA[@]}" -f "$M/03-idp-egress.yaml"
  run helm upgrade --install openchoreo-control-plane "$tgz" -n openchoreo-control-plane \
    -f "$V/openchoreo-control-plane.yaml" --set "backstage.enabled=$portal" --wait --timeout 10m
  wait_deploys openchoreo-control-plane
  copy_gateway_ca
  run kubectl -n openchoreo-control-plane rollout restart deployment/controller-manager deployment/openchoreo-api deployment/cluster-gateway
  wait_deploys openchoreo-control-plane
}

step_6() { # OpenChoreo control plane SANS portail (CRD du chart à la 1re installation)
  local out
  out="$(kubectl -n openchoreo-control-plane get deployment backstage --ignore-not-found -o name)" \
    || die "lecture du Deployment backstage en erreur"
  [[ -z "$out" ]] || die "portail actif : relancer --step 6b (l'étape 6 le désinstallerait)"
  cp_upgrade false
}

# Étape 6b : portail Backstage (docs/PORTAL.md §4). Préconditions vérifiées en LECTURE (aussi en dry-run) :
# quota CP relevé (640Mi/2304Mi), Secret backstage-secrets présent avec ses 4 clés (noms seulement, jamais
# les valeurs). Critères d'arrêt : verify.sh --step 6b ; budget_gate (pile <= 1,5 Gi / 300m).
step_6b() {
  local q keys k
  q="$(kubectl -n openchoreo-control-plane get resourcequota lab-quota -o jsonpath='{.spec.hard.requests\.memory} {.spec.hard.limits\.memory}')" \
    || die "quota lab-quota de openchoreo-control-plane illisible"
  [[ "$q" == "640Mi 2304Mi" ]] || die "quota CP = '$q' (attendu '640Mi 2304Mi') : install.sh --step 1 --apply d'abord"
  keys="$(kubectl -n openchoreo-control-plane get secret backstage-secrets --ignore-not-found -o json | jq -r '(.data // {}) | keys[]')" \
    || die "Secret backstage-secrets illisible"
  for k in backend-secret client-secret service-client-secret jenkins-api-key; do
    grep -qx "$k" <<<"$keys" || die "Secret backstage-secrets : clé '$k' absente (docs/PORTAL.md §4, créé hors dépôt par l'opérateur)"
  done
  cp_upgrade true
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
  run helm upgrade --install cnpg "$tgz" -n lab-cnpg -f "$ROOT/platform/data/cnpg-operator-values.yaml" --wait --timeout 5m
  # lab-pg-namespace.yaml porte déjà part-of et egress-isolated : aucun label posé hors fichier (garde I3).
  guard_ns_ownership "$ROOT/platform/data/lab-pg-namespace.yaml"
  run "${KA[@]}" -f "$ROOT/platform/data/lab-pg-namespace.yaml"
  run "${KA[@]}" -f "$M/51-lab-pg-oke-overlay.yaml"
  run "${KA[@]}" -f "$ROOT/platform/data/lab-pg-cluster.yaml"
  run kubectl -n lab-pg wait --for=condition=Ready --timeout=600s cluster.postgresql.cnpg.io/lab-pg
}

step_11() { # Argo CD minimal + AppProject lab et lab-authz + Application racine (adopte les objets des étapes 7, 9, 10)
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

idx() { local i; for i in "${!ORDER[@]}"; do [[ "${ORDER[$i]}" == "$1" ]] && { echo "$i"; return; }; done; die "étape inconnue : $1"; }
IFROM="$(idx "$FROM")"; ITO="$(idx "$TO")"
(( IFROM <= ITO )) || die "--from $FROM après --to $TO"
for ((i = IFROM; i <= ITO; i++)); do
  n="${ORDER[$i]}"
  if [[ "$n" == 6b && "$FROM" != 6b && "$TO" != 6b && "$WITH_PORTAL" != 1 ]]; then
    log "=== étape 6b (portail) sautée : la nommer (--step 6b) ou --with-portal"; continue
  fi
  declare -F "step_$n" >/dev/null || die "étape inconnue : $n"
  log "=== étape $n (APPLY=$APPLY)"
  "step_$n"
  if (( i >= 2 )); then budget_gate "étape $n"; fi
  [[ "$APPLY" != 1 ]] || printf '%s étape %s appliquée\n' "$(date -u +%FT%TZ)" "$n" >> "$STATE_DIR/steps.log"
done
log "terminé (étapes $FROM..$TO). Suite : tools/oke/verify.sh --step $TO"
