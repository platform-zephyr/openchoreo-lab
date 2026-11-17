#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Sature volontairement le support partagé
# (VG LVM, FS hostpath, disque Longhorn ou disque racine de la VM pour local-path).
# =============================================================================================
# T-04a : demande de PVC dont la somme dépasse le support (VG st-fast = 4 Gio).
#         PASS si le PVC en trop reste Pending avec un événement explicite (refus à la création)
#         ET qu'aucun PVC déjà lié n'est altéré. Moteurs fins (local-path, Longhorn sur-alloué,
#         LVM thin) : on attend Bound puis un échec à l'écriture -> FAIL documenté.
# T-04b (openebs-lvm uniquement, classe st-lvm-thin) : épuisement du pool thin -> on observe
#         le comportement (I/O bloquées ? erreurs ?) ; résultat PASS seulement si les autres LV
#         du pool restent lisibles avec leur sha256.
# NOT_TESTED pour local-path : saturer le disque racine de la VM met tout le nœud en DiskPressure
# (c'est exactement le risque OKE) ; activer avec STORAGE_TEST_ALLOW_ROOT_FILL=yes.
source "$(dirname "$0")/lib.sh"
guard
ns="$(new_ns t04)"; trap 'drop_ns "$ns"' EXIT

if [[ "$ENGINE" == local-path && "${STORAGE_TEST_ALLOW_ROOT_FILL:-}" != yes ]]; then
  record T-04a NOT_TESTED "local-path écrit sur le disque racine ; STORAGE_TEST_ALLOW_ROOT_FILL=yes pour tester la DiskPressure"
  finish; exit
fi

make_pvc "$ns" keep 512Mi; make_pod "$ns" k keep
write_mib "$ns" k /data/keep/witness 32 >/dev/null; SHA="$(sha_of "$ns" k /data/keep/witness)"
make_pvc "$ns" big1 2Gi; make_pvc "$ns" big2 2Gi    # 0,5 + 2 + 2 > 4 Gio utiles
set +e
make_pod "$ns" b1 big1; make_pod "$ns" b2 big2
set -e
p1="$(kubectl -n "$ns" get pvc big1 -o jsonpath='{.status.phase}')"
p2="$(kubectl -n "$ns" get pvc big2 -o jsonpath='{.status.phase}')"
{ kubectl -n "$ns" get pvc; kubectl -n "$ns" get events --sort-by=.lastTimestamp | tail -30; node_exec vgs 2>/dev/null || true; } | evidence T-04
if [[ "$p1" == Bound && "$p2" == Bound ]]; then
  # Sur-allocation acceptée : remplir les deux pour voir où ça casse.
  r1=0; write_mib "$ns" b1 /data/big1/fill 1900 >/dev/null 2>&1 || r1=$?
  r2=0; write_mib "$ns" b2 /data/big2/fill 1900 >/dev/null 2>&1 || r2=$?
  echo "sur-allocation : dd big1 rc=$r1 big2 rc=$r2" | evidence T-04
  record T-04a FAIL "sur-allocation acceptée (2 PVC de 2 Gio sur 4 Gio partagés) : échec à l'écriture, pas à la création"
else
  record T-04a PASS "PVC en trop refusé à la création (big1=$p1, big2=$p2)"
fi
[[ "$(sha_of "$ns" k /data/keep/witness)" == "$SHA" ]] && record T-04a PASS "PVC témoin intact" || record T-04a FAIL "PVC témoin altéré"

if [[ "$ENGINE" == openebs-lvm ]]; then
  make_pvc "$ns" t1 6Gi st-lvm-thin; make_pvc "$ns" t2 6Gi st-lvm-thin   # 12 Gio fins sur 8 Gio
  make_pod "$ns" tw t1 t2
  write_mib "$ns" tw /data/t2/witness 32 >/dev/null; TSHA="$(sha_of "$ns" tw /data/t2/witness)"
  rt=0; timeout 600 kubectl -n "$ns" exec tw -- sh -c 'dd if=/dev/urandom of=/data/t1/fill bs=1M count=5800 conv=fsync' >/dev/null 2>&1 || rt=$?
  { echo "thin fill rc=$rt"; node_exec lvs -a 2>/dev/null || true; node_exec dmesg 2>/dev/null | tail -30 || true; } | evidence T-04b
  set +e; got="$(timeout 60 kubectl -n "$ns" exec tw -- sh -c 'sha256sum /data/t2/witness | cut -d" " -f1')"; set -e
  [[ "$got" == "$TSHA" ]] && record T-04b PASS "pool thin plein (rc=$rt) : l'autre LV reste lisible et intact" \
                           || record T-04b FAIL "pool thin plein : l'autre LV est illisible ou altéré (rc=$rt)"
else
  record T-04b NOT_TESTED "pool thin : propre à openebs-lvm"
fi
finish
