#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Supprime PVC et PV de test.
# =============================================================================================
# T-05a (Delete) : après suppression du PVC, le PV disparaît ET le support est libéré
#                  (LV absent de `lvs`, répertoire absent, volume Longhorn absent).
# T-05b (Retain) : après suppression du PVC, le PV passe Released ; on le relie à un nouveau PVC
#                  (claimRef vidé) et les données sont intactes (sha256).
# T-05c (orphelins) : le rapport des PV Released / volumes du moteur sans PV est produit et
#                  exhaustif (le PV de T-05b apparaît tant qu'il n'est pas relié).
source "$(dirname "$0")/lib.sh"
guard
ns="$(new_ns t05)"; trap 'drop_ns "$ns"' EXIT

backing_of() { # pv -> identifiant côté nœud
  case "$ENGINE" in
    openebs-lvm) echo "$1" ;;                                  # LV nommé comme le PV [NV]
    local-path|openebs-hostpath) kubectl get pv "$1" -o jsonpath='{.spec.local.path}{.spec.hostPath.path}' ;;
    longhorn) echo "$1" ;;
  esac
}
backing_exists() { # id
  case "$ENGINE" in
    openebs-lvm) node_exec lvs --noheadings -o lv_name 2>/dev/null | grep -qw "$1" ;;
    local-path|openebs-hostpath) node_exec test -e "$1" ;;
    longhorn) kubectl -n longhorn-system get volumes.longhorn.io "$1" >/dev/null 2>&1 ;;
  esac
}

# --- T-05a
make_pvc "$ns" del 256Mi; make_pod "$ns" w del
pv="$(kubectl -n "$ns" get pvc del -o jsonpath='{.spec.volumeName}')"; back="$(backing_of "$pv")"
kubectl -n "$ns" delete pod w --wait=true >/dev/null; kubectl -n "$ns" delete pvc del --wait=true >/dev/null
for _ in $(seq 1 30); do kubectl get pv "$pv" >/dev/null 2>&1 || break; sleep 5; done
if kubectl get pv "$pv" >/dev/null 2>&1; then record T-05a FAIL "PV $pv toujours présent après 150 s"
elif [[ -z "$NODE_EXEC" ]]; then record T-05a NOT_TESTED "PV supprimé ; support non vérifiable sans NODE_EXEC"
elif backing_exists "$back"; then record T-05a FAIL "PV supprimé mais support orphelin : $back"
else record T-05a PASS "PV et support supprimés ($back)"; fi

# --- T-05b
RSC="$(storage_class)"
case "$ENGINE" in
  openebs-lvm) RSC=st-lvm-thick-retain ;;
  *) kubectl get storageclass "$(storage_class)" -o json | jq '.metadata={name:"st-retain"} | .reclaimPolicy="Retain"' | kubectl apply -f - >/dev/null; RSC=st-retain ;;
esac
make_pvc "$ns" keep 256Mi "$RSC"; make_pod "$ns" w keep
write_mib "$ns" w /data/keep/f 16 >/dev/null; SHA="$(sha_of "$ns" w /data/keep/f)"
pv="$(kubectl -n "$ns" get pvc keep -o jsonpath='{.spec.volumeName}')"
kubectl -n "$ns" delete pod w --wait=true >/dev/null; kubectl -n "$ns" delete pvc keep --wait=true >/dev/null
sleep 10
phase="$(kubectl get pv "$pv" -o jsonpath='{.status.phase}')"

# --- T-05c (avant la reliaison)
report="$(kubectl get pv -o json | jq -r '.items[] | select(.status.phase=="Released") | "\(.metadata.name)\t\(.spec.storageClassName)\t\(.spec.claimRef.namespace)/\(.spec.claimRef.name)"')"
{ echo "PV Released :"; echo "$report"; [[ $ENGINE == openebs-lvm ]] && node_exec lvs 2>/dev/null; true; } | evidence T-05c
grep -q "$pv" <<<"$report" && record T-05c PASS "rapport d'orphelins : $pv listé (Released)" || record T-05c FAIL "rapport d'orphelins incomplet"

kubectl patch pv "$pv" --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]' >/dev/null
kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: keep2}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: $RSC
  volumeName: $pv
  resources: {requests: {storage: 256Mi}}
EOF
make_pod "$ns" w2 keep2
if [[ $phase == Released && "$(sha_of "$ns" w2 /data/keep2/f)" == "$SHA" ]]; then
  record T-05b PASS "Retain : PV Released puis relié à un nouveau PVC, données intactes"
else record T-05b FAIL "Retain : phase=$phase ou sha256 différent"; fi
# Nettoyage explicite du PV Retain (sinon il devient lui-même un orphelin du banc).
kubectl -n "$ns" delete pod w2 --wait=true >/dev/null; kubectl -n "$ns" delete pvc keep2 --wait=true >/dev/null
kubectl delete pv "$pv" --wait=true >/dev/null || true
finish
