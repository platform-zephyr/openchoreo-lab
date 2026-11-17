#!/usr/bin/env bash
# check-pvc.sh APP ENV : archétype C, un seul PVC RWO (SQLite ou fichiers) (lecture seule).
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-pvc.sh APP ENV}"; ENV="${2:?usage: check-pvc.sh APP ENV}"
header "$APP" "$ENV" pvc
NS="$(cell_ns "$APP" "$ENV")"
if [ -z "$NS" ]; then record BLOCKED V0 "cellule $APP/$ENV introuvable"; finish; exit $?; fi
case "$CLUSTER_LABEL" in k3d) SC=local-path ;; oke) SC=oci-bv ;; esac

# V1 : quota de cellule autorisant le PVC (le défaut du CPT est pvcs=0).
expect V1 "quota persistentvolumeclaims" "$(k get resourcequota cell-quota -n "$NS" -o jsonpath='{.spec.hard.persistentvolumeclaims}' 2>/dev/null)" "1"

# V2 : PVC Bound, classe attendue, taille du contrat.
pvc="$(k get pvc -n "$NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
n="$(k get pvc -n "$NS" -o name 2>/dev/null | grep -c . || true)"
expect V2 "nombre de PVC dans la cellule" "$n" "1"
if [ -n "$pvc" ]; then
  expect V2 "PVC $pvc phase" "$(k get pvc "$pvc" -n "$NS" -o jsonpath='{.status.phase}')" "Bound"
  expect V2 "PVC $pvc storageClass" "$(k get pvc "$pvc" -n "$NS" -o jsonpath='{.spec.storageClassName}')" "$SC"
  expect V2 "PVC $pvc accessModes" "$(k get pvc "$pvc" -n "$NS" -o jsonpath='{.spec.accessModes[*]}')" "ReadWriteOnce"
  record INFO V2 "taille demandée $(k get pvc "$pvc" -n "$NS" -o jsonpath='{.spec.resources.requests.storage}') (contrat $(app_field "$APP" spec.storage.size) ; OKE : 50 Gi facturés minimum)"
fi

# V3 : stratégie Recreate, une seule réplique, montage au bon chemin, fsGroup posé.
dep="$(k get deploy -n "$NS" -l "openchoreo.dev/component=$APP" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -n "$dep" ]; then
  expect V3 "stratégie de déploiement" "$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.strategy.type}')" "Recreate"
  r="$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.replicas}')"
  [ "${r:-0}" -le 1 ] && record PASS V3 "replicas=$r (<= 1, PVC RWO)" || record FAIL V3 "replicas=$r avec PVC RWO"
  mp="$(app_field "$APP" spec.storage.mountPath)"
  mounts=" $(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}') "
  case "$mounts" in *" $mp "*) record PASS V3 "volume monté sur $mp" ;; *) record FAIL V3 "aucun montage sur $mp (montages :$mounts)" ;; esac
  fsg="$(k get deploy "$dep" -n "$NS" -o jsonpath='{.spec.template.spec.securityContext.fsGroup}')"
  [ -n "$fsg" ] && record PASS V3 "fsGroup=$fsg (écriture non-root sur le PVC)" || record FAIL V3 "fsGroup absent"
else
  record FAIL V3 "Deployment introuvable"
fi

# V4 : sauvegarde : regenerable = aucune copie attendue ; irreplaceable refusé par la CI.
record INFO V4 "backup.class=$(app_field "$APP" spec.backup.class) ; aucune sauvegarde de PVC dans le labo"
record NOT_TESTED V4 "persistance après redémarrage du pod : test actif (écriture), à faire dans tests/k3d"
finish; exit $?
