#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Sauvegarde puis SUPPRIME un namespace de test
# et le restaure. Cible : MinIO du banc (01-install-engines.sh WITH_VELERO=1). Jamais un bucket
# R2 de production ; pour R2, un bucket de test dédié et des clés de test (hors Git).
# =============================================================================================
# T-08a : Velero file-system backup (Kopia) d'un PVC de 300 fichiers -> Completed.
# T-08b : suppression du namespace, restauration -> manifeste sha256 intégralement vérifié.
# T-08c : local-path en volumeType hostPath (défaut) -> attendu : volume NON sauvegardé
#         (« hostPath volumes are not supported », doc Velero). PASS si ce refus est constaté.
source "$(dirname "$0")/lib.sh"
guard
command -v velero >/dev/null || { record T-08a NOT_TESTED "CLI velero absente"; finish; exit; }
kubectl get backupstoragelocation -n velero default -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Available \
  || { record T-08a NOT_TESTED "Velero/BSL absent (WITH_VELERO=1 dans 01-install-engines.sh)"; finish; exit; }

ns="$(new_ns t08)"
if [[ $ENGINE == local-path && "${LOCAL_PATH_VOLUME_TYPE:-hostPath}" == local ]]; then
  kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: d, annotations: {volumeType: local}}
spec: {accessModes: [ReadWriteOnce], storageClassName: local-path, resources: {requests: {storage: 512Mi}}}
EOF
else make_pvc "$ns" d 512Mi; fi
make_pod "$ns" w d
pexec "$ns" w 'i=0; while [ $i -lt 300 ]; do dd if=/dev/urandom of=/data/d/f$i bs=32k count=$((1 + i % 8)) 2>/dev/null; i=$((i+1)); done; cd /data/d && sha256sum f* > MANIFEST && sync'
pvtype="$(kubectl get pv "$(kubectl -n "$ns" get pvc d -o jsonpath='{.spec.volumeName}')" -o json | jq -r '.spec | keys[]' | grep -E '^(hostPath|local|csi)$' || true)"

b="st-t08-$(date +%s)"
velero backup create "$b" --include-namespaces "$ns" --default-volumes-to-fs-backup --wait >/dev/null
phase="$(velero backup get "$b" -o json | jq -r '.status.phase')"
pvb="$(kubectl -n velero get podvolumebackups -l velero.io/backup-name="$b" -o json | jq '.items | length')"
velero backup describe "$b" --details | evidence T-08

if [[ "$pvtype" == hostPath ]]; then
  [[ "$pvb" == 0 ]] && record T-08c PASS "PV hostPath : aucun PodVolumeBackup (non supporté, prédit) -> volumeType local obligatoire" \
                    || record T-08c FAIL "PV hostPath sauvegardé, contraire à la doc : vérifier"
  drop_ns "$ns"; finish; exit
fi
[[ "$phase" == Completed && "$pvb" -ge 1 ]] && record T-08a PASS "backup $b Completed, $pvb PodVolumeBackup (type PV : $pvtype)" \
                                          || { record T-08a FAIL "backup $b phase=$phase pvb=$pvb"; drop_ns "$ns"; finish; exit; }

drop_ns "$ns"
velero restore create "$b-r" --from-backup "$b" --wait >/dev/null
kubectl -n "$ns" wait --for=condition=Ready pod/w --timeout=300s >/dev/null || true
r="$(pexec "$ns" w 'cd /data/d && sha256sum -c MANIFEST 2>&1 | grep -c ": OK$"' || echo 0)"
velero restore describe "$b-r" --details | evidence T-08
[[ "$r" == 300 ]] && record T-08b PASS "restauration : 300/300 fichiers vérifiés (sha256)" || record T-08b FAIL "restauration : $r/300 fichiers vérifiés"
drop_ns "$ns"
finish
