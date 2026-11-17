#!/usr/bin/env bash
# check-postgres.sh APP ENV : archétype B, base dédiée dans le CNPG éphémère lab-pg (lecture seule).
# Aucun mot de passe lu : uniquement conditions, noms d'objets et forme des références d'env.
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-postgres.sh APP ENV}"; ENV="${2:?usage: check-postgres.sh APP ENV}"
header "$APP" "$ENV" postgres
RES="$APP-db"; RRB="$APP-db-$ENV"

# P1 : instance lab-pg saine.
if has_crd clusters.postgresql.cnpg.io; then
  ph="$(k get clusters.postgresql.cnpg.io lab-pg -n lab-pg -o jsonpath='{.status.phase}' 2>/dev/null)"
  expect P1 "Cluster CNPG lab-pg" "$ph" "Cluster in healthy state"
else
  record BLOCKED P1 "CRD CNPG absente (opérateur non installé)"; finish; exit $?
fi

# P2 : Resource et pin de la ResourceReleaseBinding (2e PR obligatoire, APP-CONTRACT §0.6).
if [ -z "$(k get resources.openchoreo.dev "$RES" -n "$OC_NS" -o name 2>/dev/null)" ]; then
  record FAIL P2 "Resource $RES absente de $OC_NS (PR non mergée ou Argo non synchronisé)"; finish; exit $?
fi
latest="$(k get resources.openchoreo.dev "$RES" -n "$OC_NS" -o jsonpath='{.status.latestRelease.name}' 2>/dev/null)"
pin="$(k get resourcereleasebindings.openchoreo.dev "$RRB" -n "$OC_NS" -o jsonpath='{.spec.resourceRelease}' 2>/dev/null)"
record INFO P2 "Resource $RES : dernière release = ${latest:-inconnue} [S champ status.latestRelease.name]"
if [ -z "$pin" ]; then
  record BLOCKED P2 "$RRB non épinglée : 2e PR 'appgen pin-resource $APP $ENV ${latest:-<release>}' requise"
else
  expect P2 "pin $RRB = dernière release" "$pin" "${latest:-$pin}"
  expect P2 "$RRB Ready" "$(cond resourcereleasebindings.openchoreo.dev "$RRB" "$OC_NS" Ready)" "True"
fi
expect P2 "retainPolicy $RRB" "$(k get resourcereleasebindings.openchoreo.dev "$RRB" -n "$OC_NS" -o jsonpath='{.spec.retainPolicy}' 2>/dev/null)" "Retain"

# P3 : Job d'initialisation (rôle, base, REVOKE CONNECT) réussi dans lab-pg.
expect P3 "Job $RES-pg-init réussi" "$(k get job "$RES-pg-init" -n lab-pg -o jsonpath='{.status.succeeded}' 2>/dev/null)" "1"

# P4 : secrets via ESO, des deux côtés (conditions seulement).
expect P4 "ExternalSecret $RES-role (lab-pg) Ready" "$(cond externalsecrets.external-secrets.io "$RES-role" lab-pg Ready)" "True"
NS="$(cell_ns "$APP" "$ENV")"
if [ -n "$NS" ]; then
  expect P4 "ExternalSecret $RES-pg (cellule) Ready" "$(cond externalsecrets.external-secrets.io "$RES-pg" "$NS" Ready)" "True"
  [ -n "$(k get secret "$RES-pg" -n "$NS" -o name 2>/dev/null)" ] && record PASS P4 "Secret $RES-pg présent (valeur non lue)" || record FAIL P4 "Secret $RES-pg absent"
  # P5 : réseau vers lab-pg ouvert pour cette cellule uniquement.
  expect P5 "label pg-client de la cellule" "$(k get ns "$NS" -o jsonpath='{.metadata.labels.platform\.smadja\.dev/pg-client}')" "true"
  # P6 : l'URL de base arrive par référence, jamais en clair.
  var="$(app_field "$APP" spec.database.envVar)"; var="${var:-DATABASE_URL}"
  dep="$(k get deploy -n "$NS" -l "openchoreo.dev/component=$APP" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  ref="$(k get deploy "$dep" -n "$NS" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"$var\")].valueFrom.secretKeyRef.name}" 2>/dev/null)"
  [ -n "$ref" ] && record PASS P6 "$var injectée par secretKeyRef ($ref)" || record FAIL P6 "$var absente ou en valeur littérale"
else
  record BLOCKED P4 "cellule $APP/$ENV introuvable"
fi

# P7 : isolation SQL et réseau : tests actifs, hors lecture seule.
record NOT_TESTED P7 "refus inter-bases (REVOKE CONNECT) et refus réseau : tests 9 et 10 de APP-CONTRACT §8 (tests/k3d)"
# P8 : sauvegarde : lab-pg n'en a pas, par conception.
record INFO P8 "backup.class=$(app_field "$APP" spec.backup.class) ; lab-pg sans sauvegarde (éphémère, D-2026-11-14-03)"
finish; exit $?
