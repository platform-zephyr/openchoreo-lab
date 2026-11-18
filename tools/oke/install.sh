#!/usr/bin/env bash
# install.sh : installation de la Phase B (OpenChoreo 1.3.3 minimal) sur OKE oracle-a1.
# Étapes 1 à 5 appliquées sur OKE le 2026-11-17 (18:22-18:28Z, $STATE_DIR/steps.log) ; 6 et suivantes
# non exécutées. Plan, critères de sortie et rollback : docs/PHASE-B.md §2.
#
# Usage : tools/oke/install.sh [--step N | --from N --to M] [--with-portal] [--apply] [--confirm-storage]
#   - N, M dans l'ordre 0 1 2 3 4 5 6 6b 7 8 9 10 11 12.
#   - Étape 0 (socle cluster, T-494) : Cilium en chaînage OCI VCN-native + VAP baseline-* + CCNP deny-imds et
#     allow-egress-unisolated (copies de kube-ops #1620/#1629, platform/baseline/). Hors plage par défaut : la
#     lancer SEULE sur un cluster vierge, AVANT tools/oke/preflight.sh : install.sh --step 0 --apply ;
#     contrôle : verify.sh --step 0. Écrit dans kube-system (Cilium) : décision de Paul du 2026-11-18 (T-487).
#   - DRY-RUN PAR DÉFAUT : affiche les commandes ; seules des LECTURES touchent le cluster (garde de
#     contexte, gardes de préconditions) ; téléchargements locaux (charts, CRD) dans STATE_DIR.
#   - --apply : exécute. Chaque étape est idempotente (helm upgrade --install, kubectl apply --server-side).
#   - Étapes 1 à 11 par défaut ; 6b (portail, docs/PORTAL.md) seulement si nommée (--step 6b, --from/--to 6b)
#     ou avec --with-portal ; 12 conservée pour compatibilité, sans effet (intégrée à l'étape 7).
#   - SECURITY BUNDLE OBLIGATOIRE (docs/SECURITY-BUNDLE.md) dès que la plage contient 6, 6b, 7 ou 10 : vérifié
#     AVANT toute écriture, aussi en dry-run et avec --step/--from/--to ; sans bundle valide, arrêt (code 2).
#     Les charts OpenChoreo ne passent QUE par helm_secure (tools/oke/security-bundle.sh) ; rollback : idem.
#   - --confirm-storage : requis pour l'étape 10 (lab-pg = 1 block volume OCI de 50 Go), après accord
#     de Paul sur le budget de stockage (docs/PHASE-B.md §4).
# Après chaque étape (3 à 12) : mesure au repos de la pile et ARRÊT (code 3) si > 1,5 Gi ou > 300m.
# Puis lancer tools/oke/verify.sh --step N (critère de sortie) avant l'étape suivante.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=security-bundle.sh
. "$(dirname "${BASH_SOURCE[0]}")/security-bundle.sh"

FROM=1 TO=11 CONFIRM_STORAGE=0 WITH_PORTAL=0
ORDER=(0 1 2 3 4 5 6 6b 7 8 9 10 11 12)
while (($#)); do
  case "$1" in
    --step) FROM="$2"; TO="$2"; shift 2;;
    --from) FROM="$2"; shift 2;;
    --to) TO="$2"; shift 2;;
    --with-portal) WITH_PORTAL=1; shift;;
    --apply) APPLY=1; shift;;
    --confirm-storage) CONFIRM_STORAGE=1; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) die "argument inconnu : $1";;
  esac
done
export APPLY

need kubectl helm jq yq curl shasum base64
idx() { local i; for i in "${!ORDER[@]}"; do [[ "${ORDER[$i]}" == "$1" ]] && { echo "$i"; return; }; done; die "étape inconnue : $1"; }
IFROM="$(idx "$FROM")"; ITO="$(idx "$TO")"
(( IFROM <= ITO )) || die "--from $FROM après --to $TO"
guard_context
mkdir -p "$STATE_DIR"
# Security bundle exigé AVANT la première étape (donc avant toute écriture) si la plage touche OpenChoreo.
for ((i = IFROM; i <= ITO; i++)); do
  case "${ORDER[$i]}" in 6|6b|7|10) sb_require; break;; esac
done
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

# Pods créés avant Cilium : aucune politique ne s'y applique tant qu'ils ne sont pas recréés (guide amont
# « Oracle Kubernetes Engine (OKE) VCN-Native Pod Networking », § Restart existing pods). Pods hors hostNetwork
# sans CiliumEndpoint : supprimés s'ils ont un contrôleur (recréés aussitôt), signalés sinon. Cluster vierge :
# seuls les pods système de kube-system sont concernés.
restart_unmanaged_pods() {
  if [[ "$APPLY" != 1 ]]; then echo "[dry-run] recréation des pods hors hostNetwork sans CiliumEndpoint"; return; fi
  local pods ceps ns name owned
  pods="$(kubectl get pods -A -o json)" || die "liste des pods illisible"
  ceps="$(kubectl get ciliumendpoints.cilium.io -A -o json)" || die "liste des CiliumEndpoints illisible"
  while read -r ns name owned; do
    [[ -n "$ns" ]] || continue
    if [[ "$owned" == true ]]; then run kubectl -n "$ns" delete pod "$name" --wait=false
    else log "ATTENTION pod sans contrôleur et sans CiliumEndpoint (non recréé, hors politique) : $ns/$name"; fi
  done < <(jq -r --slurpfile cep <(printf '%s' "$ceps") '
      ([$cep[0].items[] | "\(.metadata.namespace)/\(.metadata.name)"]) as $c
      | .items[] | select(.spec.hostNetwork != true and .status.phase == "Running")
      | select(("\(.metadata.namespace)/\(.metadata.name)") as $k | ($c | index($k)) == null)
      | "\(.metadata.namespace) \(.metadata.name) \((.metadata.ownerReferences // []) | length > 0)"' <<<"$pods")
  run kubectl -n kube-system wait --for=condition=Available deployment --all --timeout=300s
}

step_0() { # Socle cluster (T-494) : Cilium (kube-system), puis VAP et CCNP baseline (platform/baseline/)
  local tgz; tgz="$(fetch_chart cilium "$CILIUM_CHART" "$CILIUM_VERSION" "$CILIUM_TGZ_SHA256" "$CILIUM_REPO")"
  run helm upgrade --install cilium "$tgz" -n kube-system -f "$V/cilium.yaml" --wait --timeout 10m
  run kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
  run kubectl -n kube-system rollout status deployment/cilium-operator --timeout=300s
  # Les CRD Cilium sont créées par cilium-operator à son démarrage (le chart n'en contient pas).
  run kubectl wait --for=create --timeout=180s crd/ciliumclusterwidenetworkpolicies.cilium.io
  run kubectl wait --for=condition=Established --timeout=120s crd/ciliumclusterwidenetworkpolicies.cilium.io
  # VAP + bindings + CCNP, copies NON modifiées de kube-ops (tools/oke/baseline-source.sh). Argo (lab-platform)
  # les adopte à l'étape 11 ; jusque-là, ce fichier fait foi.
  run "${KA[@]}" -f "$ROOT/platform/baseline/"
  restart_unmanaged_pods
}

step_1() { # Socle : namespaces, quotas, réseau
  guard_ns_ownership "$M/00-namespaces.yaml"
  run "${KA[@]}" -f "$M/00-namespaces.yaml"
  run "${KA[@]}" -f "$M/01-quotas.yaml"
  run "${KA[@]}" -f "$M/02-network-policies.yaml"
}

step_2() { # Gateway API CRD (standard v1.5.1), manifest vérifié par sha256
  local f; f="$(fetch_gw_crds)"
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
  # Rendu durci vérifié AVANT la première écriture de l'étape (CRD, egress).
  local cpargs=(-f "$V/openchoreo-control-plane.yaml" --set "backstage.enabled=$portal" --wait --timeout 10m)
  sb_prerender cp openchoreo-control-plane "$tgz" openchoreo-control-plane "${cpargs[@]}"
  # Mise à jour des CRD (Helm ne les met jamais à jour) : server-side, avant l'upgrade (upgrades/overview.mdx).
  if [[ "$APPLY" == 1 ]] && kubectl get crd components.openchoreo.dev >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp -d)"; tar -xzf "$tgz" -C "$tmp"
    kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f "$tmp/openchoreo-control-plane/crds/"
    rm -rf "$tmp"
  fi
  # Egress vers Authentik (JWKS de l'API, OIDC du portail) posé AVANT les pods.
  run "${KA[@]}" -f "$M/03-idp-egress.yaml"
  # Security bundle : durcissement des droits de lecture rendus par le chart et image du contrôleur imposée par
  # digest (détails hors dépôt, docs/SECURITY-BUNDLE.md). Refus avant écriture si le bundle n'est pas valide.
  # helm_secure recopie la CA et redémarre controller-manager et openchoreo-api juste après l'upgrade.
  helm_secure cp openchoreo-control-plane "$tgz" openchoreo-control-plane "${cpargs[@]}"
  wait_deploys openchoreo-control-plane
  # Redémarrage EN SÉRIE avec `rollout status` (revue m5) : un seul surge à la fois sous le quota de 640 Mi,
  # et l'attente porte sur les NOUVEAUX pods (wait Available passait sur les anciens).
  # controller-manager et openchoreo-api : déjà redémarrés par helm_secure (recopie de la CA).
  run kubectl -n openchoreo-control-plane rollout restart deployment/cluster-gateway
  run kubectl -n openchoreo-control-plane rollout status deployment/cluster-gateway --timeout=300s
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

step_7() { # VAP du labo + TLS/Envoy + OpenChoreo data plane (RBAC du cluster-agent fourni par le security bundle)
  # Rendu durci vérifié AVANT la première écriture de l'étape.
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  local dpargs=(-f "$V/openchoreo-data-plane.yaml" --wait --timeout 10m)
  sb_prerender dp openchoreo-data-plane "$tgz" openchoreo-data-plane "${dpargs[@]}"
  # Les VAP passent AVANT que le cluster-agent existe : aucune écriture de l'agent n'échappe à VAP-1.
  run "${KA[@]}" -f "$ROOT/platform/policies/"
  run "${KA[@]}" -f "$M/11-gateway-tls.yaml"
  run kubectl -n openchoreo-data-plane wait --for=condition=Ready --timeout=120s certificate/dp-gateway-tls
  run "${KA[@]}" -f "$M/12-gateway-parameters.yaml"
  copy_gateway_ca
  # Security bundle : les droits du cluster-agent sont rendus AVEC le chart (aucun ClusterRole d'origine, même
  # transitoire) ; refus avant écriture si le bundle n'est pas valide.
  helm_secure dp openchoreo-data-plane "$tgz" openchoreo-data-plane "${dpargs[@]}"
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
  sb_apply_extra lab-pg   # droits du cluster-agent dans lab-pg (security bundle)
  run "${KA[@]}" -f "$M/51-lab-pg-oke-overlay.yaml"
  run "${KA[@]}" -f "$ROOT/platform/data/lab-pg-cluster.yaml"
  run kubectl -n lab-pg wait --for=condition=Ready --timeout=600s cluster.postgresql.cnpg.io/lab-pg
}

step_11() { # Argo CD minimal + projet default VERROUILLÉ + AppProject lab, lab-authz, lab-root + Application racine
  # Bootstrap PRIVILÉGIÉ (revue PR #8, P1) : le projet `default` est verrouillé AVANT toute Application,
  # sinon une Application `project: default` obtiendrait les droits */*/* du contrôleur.
  local tgz; tgz="$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")"
  run helm upgrade --install argocd "$tgz" -n lab-argocd -f "$V/argocd.yaml" --wait --timeout 10m
  # argocd-server crée `default` à son démarrage (champs possédés par argocd-server) : on attend sa
  # présence, puis --force-conflicts reprend la propriété de chaque liste, posée vide dans le manifest.
  run kubectl -n lab-argocd wait --for=create appprojects.argoproj.io/default --timeout=120s
  run "${KA[@]}" --force-conflicts -f "$INSTALL_DIR/argocd/project-default-locked.yaml"
  run "${KA[@]}" -f "$INSTALL_DIR/argocd/project-lab.yaml"
  run "${KA[@]}" -f "$INSTALL_DIR/argocd/root-application.yaml"
}

step_12() { # SANS EFFET : le RBAC du cluster-agent est rendu avec le chart à l'étape 7 (security bundle)
  log "étape 12 : intégrée à l'étape 7 (security bundle), rien à appliquer ; contrôle : verify.sh --step 7"
}

for ((i = IFROM; i <= ITO; i++)); do
  n="${ORDER[$i]}"
  if [[ "$n" == 6b && "$FROM" != 6b && "$TO" != 6b && "$WITH_PORTAL" != 1 ]]; then
    log "=== étape 6b (portail) sautée : la nommer (--step 6b) ou --with-portal"; continue
  fi
  declare -F "step_$n" >/dev/null || die "étape inconnue : $n"
  log "=== étape $n (APPLY=$APPLY)"
  "step_$n"
  # Journalisé AVANT le gate (revue m6) : un arrêt 3/4/5 du gate n'efface pas la trace d'une étape appliquée.
  [[ "$APPLY" != 1 ]] || printf '%s étape %s appliquée\n' "$(date -u +%FT%TZ)" "$n" >> "$STATE_DIR/steps.log"
  case "$n" in 0|1|2) ;; *) budget_gate "étape $n";; esac
done
log "terminé (étapes $FROM..$TO). Suite : tools/oke/verify.sh --step $TO"
