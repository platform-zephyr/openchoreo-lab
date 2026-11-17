#!/usr/bin/env bash
# check-helm.sh APP ENV : archétype E, chart tiers synchronisé par Argo CD (lecture seule).
# Parcours désactivé dans le pilote (ApplicationSet lab-helm absent) : BLOCKED attendu tant qu'il ne l'est pas.
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-helm.sh APP ENV}"; ENV="${2:?usage: check-helm.sh APP ENV}"
header "$APP" "$ENV" helm
if ! has_crd applications.argoproj.io; then record BLOCKED H0 "Argo CD absent"; finish; exit $?; fi
AA="$APP-$ENV"   # [S] nom d'Application produit par l'ApplicationSet lab-helm
s="$(k get applications.argoproj.io "$AA" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)"
if [ -z "$s" ]; then record BLOCKED H0 "Application $AA absente (parcours Helm non activé)"; finish; exit $?; fi
expect H1 "Application $AA sync/health" "$s" "Synced/Healthy"
expect H1 "version du chart = app.yaml" \
  "$(k get applications.argoproj.io "$AA" -n "$ARGOCD_NS" -o jsonpath='{.spec.sources[0].targetRevision}')" \
  "$(app_field "$APP" spec.source.chart.version)"
NS="$(k get applications.argoproj.io "$AA" -n "$ARGOCD_NS" -o jsonpath='{.spec.destination.namespace}')"
expect H2 "PSA enforce du namespace $NS" "$(k get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" "restricted"
[ -n "$(k get networkpolicies -n "$NS" -o name 2>/dev/null)" ] && record PASS H2 "NetworkPolicies présentes" || record FAIL H2 "aucune NetworkPolicy (default-deny absent)"
bad_svc="$(k get svc -n "$NS" -o jsonpath='{range .items[?(@.spec.type!="ClusterIP")]}{.metadata.name}:{.spec.type} {end}')"
[ -z "$bad_svc" ] && record PASS H3 "Services en ClusterIP" || record FAIL H3 "Services non ClusterIP : $bad_svc"
nodig="$(k get pods -n "$NS" -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | grep -v '@sha256:' | sort -u | tr '\n' ' ')"
[ -z "$nodig" ] && record PASS H3 "toutes les images par digest" || record FAIL H3 "images sans digest : $nodig"
notready="$(k get pods -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status} {end}' | tr ' ' '\n' | grep -v '=True$' | grep . | tr '\n' ' ')"
[ -z "$notready" ] && record PASS H4 "pods Ready" || record FAIL H4 "pods non Ready : $notready"
finish; exit $?
