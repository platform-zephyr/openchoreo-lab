#!/usr/bin/env bash
# check-workload.sh APP ENV : invariants runtime communs aux archétypes natifs A, B, C (lecture seule).
# Cellule : PSA, NetworkPolicies, quota ; pod : securityContext, digest, readiness ; exposition ; secrets.
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-workload.sh APP ENV}"; ENV="${2:?usage: check-workload.sh APP ENV}"
header "$APP" "$ENV" workload

NS="$(cell_ns "$APP" "$ENV")"
if [ -z "$NS" ]; then record BLOCKED W0 "namespace de cellule introuvable pour $APP/$ENV"; finish; exit $?; fi
record INFO W0 "cellule : $NS"
SEL="openchoreo.dev/component=$APP"   # [S] label posé par OpenChoreo sur les objets rendus

# W1 : PSA restricted posée en constante par le CPT cell-restricted.
expect W1 "label PSA enforce" "$(k get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" "restricted"

# W2 : NetworkPolicies attendues, et seulement elles pour l'egress.
nps=" $(k get networkpolicies -n "$NS" -o jsonpath='{.items[*].metadata.name}') "
want_np() { case "$nps" in *" $1 "*) record PASS W2 "NetworkPolicy $1 présente" ;; *) record FAIL W2 "NetworkPolicy $1 absente" ;; esac; }
deny_np() { case "$nps" in *" $1 "*) record FAIL W2 "NetworkPolicy $1 présente sans être demandée" ;; *) record PASS W2 "NetworkPolicy $1 absente (non demandée)" ;; esac; }
want_np default-deny; want_np allow-dns-and-cell
[ "$(app_field "$APP" spec.network.egress)" = "public-internet" ] && want_np egress-public-internet || deny_np egress-public-internet
[ "$(app_field "$APP" spec.network.allowIdp)" = "true" ] && want_np egress-idp || deny_np egress-idp
[ -n "$(app_field "$APP" spec.database)" ] && want_np egress-lab-pg || deny_np egress-lab-pg

# W3 : quota et LimitRange de cellule ; aucun LoadBalancer ni NodePort.
expect W3 "quota services.loadbalancers" "$(k get resourcequota cell-quota -n "$NS" -o jsonpath='{.spec.hard.services\.loadbalancers}' 2>/dev/null)" "0"
expect W3 "quota services.nodeports" "$(k get resourcequota cell-quota -n "$NS" -o jsonpath='{.spec.hard.services\.nodeports}' 2>/dev/null)" "0"
[ -n "$(k get limitrange cell-limits -n "$NS" -o name 2>/dev/null)" ] && record PASS W3 "LimitRange cell-limits présente" || record FAIL W3 "LimitRange cell-limits absente"
bad_svc="$(k get svc -n "$NS" -o jsonpath='{range .items[?(@.spec.type!="ClusterIP")]}{.metadata.name}:{.spec.type} {end}')"
[ -z "$bad_svc" ] && record PASS W3 "tous les Services en ClusterIP" || record FAIL W3 "Services non ClusterIP : $bad_svc"

# W4 : Deployment disponible, pods prêts, redémarrages bornés.
dep="$(k get deploy -n "$NS" -l "$SEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$dep" ]; then record FAIL W4 "aucun Deployment ($SEL) dans $NS"; finish; exit $?; fi
expect W4 "Deployment $dep disponible (ready/desired)" \
  "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')" \
  "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.replicas}/{.spec.replicas}')"
restarts="$(k get pods -n "$NS" -l "$SEL" -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' | awk '{s+=$1} END {print s+0}')"
[ "$restarts" -lt 3 ] && record PASS W4 "redémarrages cumulés = $restarts (< 3)" || record FAIL W4 "redémarrages cumulés = $restarts (crash-loop probable)"

# W5 : securityContext restricted effectif (pas seulement déclaré dans la CCT).
expect W5 "runAsNonRoot" "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}')" "true"
expect W5 "seccompProfile" "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}')" "RuntimeDefault"
expect W5 "automountServiceAccountToken" "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')" "false"
csc="$(k get deploy "$dep" -n "$NS" -o jsonpath='{range .spec.template.spec.containers[*]}{.securityContext.allowPrivilegeEscalation}/{.securityContext.readOnlyRootFilesystem}/{.securityContext.capabilities.drop[*]} {end}')"
ok=1; for c in $csc; do [ "$c" = "false/true/ALL" ] || ok=0; done
[ "$ok" = 1 ] && record PASS W5 "conteneurs : allowPrivilegeEscalation=false, rootfs RO, drop ALL" || record FAIL W5 "securityContext conteneur altéré : $csc"

# W6 : image épinglée par digest, identique au contrat.
img="$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}')"
expect W6 "image du Deployment = app.yaml" "$img" "$(app_field "$APP" spec.source.image)"

# W7 : exposition conforme au contrat.
mode="$(app_field "$APP" spec.exposure.mode)"
routes="$(k get httproutes.gateway.networking.k8s.io -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}[{.spec.hostnames[*]}] {end}' 2>/dev/null)"
record INFO W7 "HTTPRoutes : ${routes:-aucune}"
if [ "$mode" = "public" ]; then
  host="$(app_field "$APP" spec.exposure.host)"
  case "$routes" in *"$host"*) record PASS W7 "hôte public $host routé" ;; *) record NOT_TESTED W7 "hôte $host absent des HTTPRoutes (routage par hôte non rendu, SCHEMA-GAPS G6)" ;; esac
  record NOT_TESTED W7 "refus anonyme de https://$host : test réseau externe, hors lecture kubectl"
fi

# W8 : santé applicative via le proxy de l'API server (GET seulement). Peut être bloqué par default-deny [S].
port="$(app_field "$APP" spec.runtime.port)"; hp="$(app_field "$APP" spec.runtime.healthPath)"
svc="$(k get svc -n "$NS" -l "$SEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
sport="$(k get svc "$svc" -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)"
if [ -n "$svc" ] && k get --raw "/api/v1/namespaces/$NS/services/http:$svc:${sport:-$port}/proxy$hp" >/dev/null 2>&1; then
  record PASS W8 "GET $hp via proxy API server : 2xx"
else
  record NOT_TESTED W8 "GET $hp via proxy API server impossible (NP default-deny ou Service absent) : vérifier readiness (W4)"
fi

# W9 : secrets matérialisés par ESO (conditions seulement, jamais les valeurs).
if [ -n "$(app_field "$APP" spec.secrets)" ]; then
  es="$(k get externalsecrets.external-secrets.io -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status} {end}' 2>/dev/null)"
  [ -z "$es" ] && record FAIL W9 "aucun ExternalSecret dans $NS"
  for e in $es; do [ "${e#*=}" = "True" ] && record PASS W9 "ExternalSecret ${e%=*} Ready" || record FAIL W9 "ExternalSecret ${e%=*} non Ready (clé absente du store ?)"; done
  lit="$(k get deploy "$dep" -n "$NS" -o jsonpath='{range .spec.template.spec.containers[0].env[?(@.valueFrom)]}{.name} {end}')"
  record INFO W9 "variables injectées par référence : ${lit:-aucune}"
fi

# W10 : observabilité (déclaratif seulement dans le labo).
if [ "$(app_field "$APP" spec.observability.metrics.enabled)" = "true" ]; then
  ann="$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.metadata.annotations.prometheus\.io/scrape}')"
  [ "$ann" = "true" ] && record PASS W10 "annotation de scrape présente" || record NOT_TESTED W10 "annotation de scrape absente (non rendue, SCHEMA-GAPS G5)"
fi

# W11 : événements Warning récents (indicatif).
warn="$(k get events -n "$NS" --field-selector type=Warning -o jsonpath='{range .items[*]}{.reason} {end}' 2>/dev/null | tr ' ' '\n' | sort | uniq -c | tr '\n' ' ')"
record INFO W11 "événements Warning : ${warn:-aucun}"
finish; exit $?
