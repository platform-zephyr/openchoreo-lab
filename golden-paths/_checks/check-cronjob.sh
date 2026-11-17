#!/usr/bin/env bash
# check-cronjob.sh APP ENV : archétype D (worker / CronJob). NON DISPONIBLE dans v2alpha1 (SCHEMA-GAPS G1).
# Prêt pour le jour où la plateforme rendra un CronJob : vérifie forme et dernière exécution (lecture seule).
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-cronjob.sh APP ENV}"; ENV="${2:?usage: check-cronjob.sh APP ENV}"
header "$APP" "$ENV" cronjob
NS="$(cell_ns "$APP" "$ENV")"
if [ -z "$NS" ]; then record BLOCKED D0 "cellule introuvable : archétype D non supporté par v2alpha1"; finish; exit $?; fi
SEL="openchoreo.dev/component=$APP"
cj="$(k get cronjobs -n "$NS" -l "$SEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$cj" ]; then record BLOCKED D1 "aucun CronJob ($SEL) : archétype D non rendu"; finish; exit $?; fi
expect D1 "concurrencyPolicy" "$(k get cronjob "$cj" -n "$NS" -o jsonpath='{.spec.concurrencyPolicy}')" "Forbid"
expect D1 "suspend" "$(k get cronjob "$cj" -n "$NS" -o jsonpath='{.spec.suspend}')" "false"
expect D2 "runAsNonRoot" "$(k get cronjob "$cj" -n "$NS" -o jsonpath='{.spec.jobTemplate.spec.template.spec.securityContext.runAsNonRoot}')" "true"
img="$(k get cronjob "$cj" -n "$NS" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')"
case "$img" in *@sha256:*) record PASS D2 "image par digest" ;; *) record FAIL D2 "image sans digest : $img" ;; esac
last="$(k get cronjob "$cj" -n "$NS" -o jsonpath='{.status.lastSuccessfulTime}')"
[ -n "$last" ] && record PASS D3 "dernière exécution réussie : $last" || record NOT_TESTED D3 "aucune exécution réussie à ce jour"
failed="$(k get jobs -n "$NS" -l "$SEL" -o jsonpath='{range .items[?(@.status.failed)]}{.metadata.name} {end}')"
[ -z "$failed" ] && record PASS D3 "aucun Job en échec" || record FAIL D3 "Jobs en échec : $failed"
finish; exit $?
