#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE (VM préparée par 00-setup-vm.sh).
# Enchaîne T-00 à T-09 pour un moteur. JAMAIS exécuté à la préparation (2026-11-17).
# =============================================================================================
# Usage : ENGINE=openebs-lvm KUBECONFIG=/root/storage-test.kubeconfig \
#         STORAGE_TEST_ALLOWED_CONTEXTS=storage-test tests/storage/run-all.sh
# Ordre : les tests destructifs du nœud (T-03b, T-06) ne tournent que si leurs variables
# d'autorisation sont posées ; T-06 renomme le nœud : à lancer en dernier.
source "$(dirname "$0")/lib.sh"
guard
rc=0
for t in t00-privileges t01-t02-size-isolation t03-persistence-restart t04-pool-full \
         t05-delete-recreate t08-backup-restore t09-footprint t06-t07-node-change-reattach; do
  echo "=== $t [$ENGINE]"
  bash "$STORAGE_TEST_DIR/$t.sh" || rc=1
done
echo "=== résultats cumulés : $EVIDENCE_DIR/results.log"
exit $rc
