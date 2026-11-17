#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Avec STORAGE_TEST_ALLOW_NODE_RESTART=yes,
# redémarre k3s (et réattache les loop devices) sur la VM jetable.
# =============================================================================================
# T-03a : données (200 fichiers, manifeste sha256) intactes après suppression/recréation du pod.
# T-03b : intactes après redémarrage de k3s + réactivation des VG (simule un reboot du nœud).
#         NOT_TESTED sans STORAGE_TEST_ALLOW_NODE_RESTART=yes.
source "$(dirname "$0")/lib.sh"
guard
ns="$(new_ns t03)"; trap 'drop_ns "$ns"' EXIT
make_pvc "$ns" d 512Mi
make_pod "$ns" w d
# (racine du conteneur en lecture seule : tout est écrit sous /data/d)
pexec "$ns" w 'i=0; while [ $i -lt 200 ]; do dd if=/dev/urandom of=/data/d/f$i bs=64k count=4 2>/dev/null; i=$((i+1)); done; cd /data/d && sha256sum f* > MANIFEST && sync'
check() { pexec "$ns" w 'cd /data/d && sha256sum -c MANIFEST >/dev/null 2>&1 && echo OK || echo KO'; }

kubectl -n "$ns" delete pod w --wait=true >/dev/null
make_pod "$ns" w d
r="$(check)"; echo "après recréation du pod : $r" | evidence T-03
[[ $r == OK ]] && record T-03a PASS "200 fichiers intacts après recréation du pod" || record T-03a FAIL "manifeste sha256 en échec après recréation du pod"

if [[ "${STORAGE_TEST_ALLOW_NODE_RESTART:-}" != yes ]]; then
  record T-03b NOT_TESTED "redémarrage du nœud non autorisé (STORAGE_TEST_ALLOW_NODE_RESTART=yes)"
else
  node_exec sh -c 'systemctl stop k3s && /usr/local/bin/k3s-killall.sh >/dev/null 2>&1; /etc/storage-test-reattach.sh && systemctl start k3s' \
    || { record T-03b FAIL "redémarrage k3s/réattachement en échec"; finish; exit; }
  kubectl wait --for=condition=Ready node --all --timeout=300s >/dev/null
  kubectl -n "$ns" wait --for=condition=Ready pod/w --timeout=300s >/dev/null || { kubectl -n "$ns" delete pod w --wait=true >/dev/null; make_pod "$ns" w d; }
  r="$(check)"; echo "après redémarrage du nœud : $r" | evidence T-03
  [[ $r == OK ]] && record T-03b PASS "données intactes après redémarrage du nœud" || record T-03b FAIL "données altérées après redémarrage du nœud"
fi
finish
