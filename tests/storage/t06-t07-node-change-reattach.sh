#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Avec STORAGE_TEST_ALLOW_NODE_RENAME=yes,
# réinstalle l'identité du nœud k3s (nouveau --node-name) sur la VM jetable.
# =============================================================================================
# T-06 : changement d'identité Kubernetes du nœud (st-node-a -> st-node-b), disques conservés.
#        Attendu : pod Pending (nodeAffinity du PV sur l'ancien nom). Puis procédure documentée
#        (STORAGE-RECOMMENDATION §6) : PV recréé avec la nouvelle nodeAffinity (+ ownerNodeID
#        du LVMVolume pour openebs-lvm [NV]). PASS si les données reviennent intactes (sha256).
# T-07 : réattachement d'un support existant sans formatage : PV statique pointant le support
#        existant (même chemin / même LV), sans mkfs. PASS si sha256 identique et si le FS n'a
#        pas été recréé (mêmes inode/UUID).
# Sans STORAGE_TEST_ALLOW_NODE_RENAME=yes : T-06 NOT_TESTED ; T-07 tourne seul (même nœud).
source "$(dirname "$0")/lib.sh"
guard
ns="$(new_ns t06)"
RSC=st-retain-t06
kubectl get storageclass "$(storage_class)" -o json | jq '.metadata={name:"'$RSC'"} | .reclaimPolicy="Retain"' | kubectl apply -f - >/dev/null
make_pvc "$ns" d 256Mi "$RSC"; make_pod "$ns" w d
write_mib "$ns" w /data/d/f 16 >/dev/null; SHA="$(sha_of "$ns" w /data/d/f)"
pv="$(kubectl -n "$ns" get pvc d -o jsonpath='{.spec.volumeName}')"
kubectl get pv "$pv" -o yaml > "$EVIDENCE_DIR/T-06-pv-before.yaml"
FSID_BEFORE="$(pexec "$ns" w 'stat -f -c %i /data/d; stat -c %i /data/d/f' | tr '\n' ' ')"

# Recrée le PV à l'identique sauf nodeAffinity (et sans claimRef UID), puis relie un PVC.
rebind() { # nouveau_nom_de_noeud nom_pvc
  kubectl -n "$ns" delete pod w --wait=true --ignore-not-found >/dev/null
  kubectl -n "$ns" delete pvc d --wait=false --ignore-not-found >/dev/null
  kubectl patch pv "$pv" -p '{"metadata":{"finalizers":null}}' >/dev/null || true
  kubectl delete pv "$pv" --wait=true >/dev/null
  yq -o=json "$EVIDENCE_DIR/T-06-pv-before.yaml" | jq --arg n "$1" '
      del(.metadata.uid,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.managedFields,.status,.spec.claimRef)
      | .spec.nodeAffinity.required.nodeSelectorTerms |= map(.matchExpressions |= map(.values = [$n]))' \
    | kubectl apply -f - >/dev/null
  if [[ $ENGINE == openebs-lvm ]]; then
    kubectl -n storage-system patch lvmvolumes.local.openebs.io "$pv" --type=merge -p "{\"spec\":{\"ownerNodeID\":\"$1\"}}" >/dev/null || true   # [NV]
  fi
  kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: $2}
spec: {accessModes: [ReadWriteOnce], storageClassName: $RSC, volumeName: $pv, resources: {requests: {storage: 256Mi}}}
EOF
  make_pod "$ns" w "$2"
}

# --- T-07 (même nœud) : réattachement sans formatage
rebind st-node-a d7
got="$(sha_of "$ns" w /data/d7/f)"; FSID_AFTER="$(pexec "$ns" w 'stat -f -c %i /data/d7; stat -c %i /data/d7/f' | tr '\n' ' ')"
echo "fsid/inode avant=$FSID_BEFORE après=$FSID_AFTER" | evidence T-07
[[ "$got" == "$SHA" && "$FSID_BEFORE" == "$FSID_AFTER" ]] \
  && record T-07 PASS "PV statique sur support existant : données et FS identiques (pas de reformatage)" \
  || record T-07 FAIL "réattachement : sha256 ou identité du FS différents"
kubectl get pv "$pv" -o yaml > "$EVIDENCE_DIR/T-06-pv-before.yaml"

# --- T-06 : changement de nom du nœud
if [[ "${STORAGE_TEST_ALLOW_NODE_RENAME:-}" != yes ]]; then
  record T-06 NOT_TESTED "renommage du nœud non autorisé (STORAGE_TEST_ALLOW_NODE_RENAME=yes)"
else
  node_exec sh -c "sed -i 's/--node-name st-node-a/--node-name st-node-b/' /etc/systemd/system/k3s.service && systemctl daemon-reload && systemctl restart k3s"
  kubectl wait --for=condition=Ready node/st-node-b --timeout=300s >/dev/null
  kubectl delete node st-node-a --wait=true >/dev/null || true
  kubectl -n "$ns" delete pod w --wait=true --ignore-not-found >/dev/null
  set +e; make_pod "$ns" w d7; stuck=$?; set -e
  kubectl -n "$ns" describe pod w | tail -15 | evidence T-06
  [[ $stuck -ne 0 ]] && echo "pod Pending avant procédure (attendu)" | evidence T-06
  rebind st-node-b d6
  [[ "$(sha_of "$ns" w /data/d6/f)" == "$SHA" ]] \
    && record T-06 PASS "nouveau nom de nœud : procédure de reliaison appliquée, données intactes" \
    || record T-06 FAIL "nouveau nom de nœud : données non récupérées par la procédure"
fi
kubectl -n "$ns" delete pod w --wait=true --ignore-not-found >/dev/null
kubectl -n "$ns" delete pvc --all --wait=true >/dev/null; kubectl delete pv "$pv" --ignore-not-found >/dev/null
drop_ns "$ns"
finish
