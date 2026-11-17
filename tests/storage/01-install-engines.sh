#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE (préparé par 00-setup-vm.sh).
# Installe le moteur ENGINE (et, avec WITH_VELERO=1, MinIO + Velero pour T-08). JAMAIS exécuté.
# =============================================================================================
# Usage : ENGINE=openebs-lvm OPENEBS_LVM_CHART_VERSION=<x.y.z> tests/storage/01-install-engines.sh
# Les versions de chart n'ont PAS de valeur par défaut : l'opérateur les épingle (aucune version
# n'a été vérifiée dans cette passe [NV]).
source "$(dirname "$0")/lib.sh"
guard

need() { [[ -n "${!1:-}" ]] || die "variable $1 requise (version épinglée)."; }

ensure_storage_ns() {
  kubectl create namespace storage-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  # Exception nommée proposée (STORAGE-RECOMMENDATION §8) reproduite sur le banc.
  kubectl label namespace storage-system --overwrite pod-security.kubernetes.io/enforce=privileged >/dev/null
}

case "$ENGINE" in
  local-path)
    kubectl get storageclass local-path >/dev/null || die "local-path absent (k3s sans --disable local-storage attendu)." ;;
  openebs-hostpath)
    need OPENEBS_HOSTPATH_CHART_VERSION; ensure_storage_ns
    helm repo add openebs-localpv https://openebs.github.io/dynamic-localpv-provisioner >/dev/null
    helm upgrade --install localpv openebs-localpv/localpv-provisioner -n storage-system \
      --version "$OPENEBS_HOSTPATH_CHART_VERSION" --set hostpathClass.enabled=false --wait
    kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: st-openebs-hostpath-xfs
  annotations:
    openebs.io/cas-type: local
    cas.openebs.io/config: |
      - name: StorageType
        value: hostpath
      - name: BasePath
        value: /mnt/st-hostpath
      - name: XFSQuota
        enabled: "true"
provisioner: openebs.io/local
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
    ;;
  openebs-lvm)
    need OPENEBS_LVM_CHART_VERSION; ensure_storage_ns
    helm repo add openebs-lvm https://openebs.github.io/lvm-localpv >/dev/null
    helm upgrade --install lvm-localpv openebs-lvm/lvm-localpv -n storage-system \
      --version "$OPENEBS_LVM_CHART_VERSION" --wait
    kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: st-lvm-thick}
provisioner: local.csi.openebs.io
parameters: {storage: lvm, volgroup: st-fast, fsType: ext4, thinProvision: "no"}
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: st-lvm-thick-retain}
provisioner: local.csi.openebs.io
parameters: {storage: lvm, volgroup: st-fast, fsType: ext4, thinProvision: "no"}
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: st-lvm-thin}
provisioner: local.csi.openebs.io
parameters: {storage: lvm, volgroup: st-bulk, fsType: ext4, thinProvision: "yes"}
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    ;;
  longhorn)
    need LONGHORN_CHART_VERSION
    node_exec sh -c 'apt-get install -y -qq open-iscsi nfs-common >/dev/null && systemctl enable --now iscsid' || die "prérequis Longhorn."
    helm repo add longhorn https://charts.longhorn.io >/dev/null
    helm upgrade --install longhorn longhorn/longhorn -n longhorn-system --create-namespace \
      --version "$LONGHORN_CHART_VERSION" --set persistence.createStorageClass=false \
      --set defaultSettings.defaultReplicaCount=1 --set defaultSettings.v2DataEngine=false \
      --set csi.attacherReplicaCount=1 --set csi.provisionerReplicaCount=1 \
      --set csi.resizerReplicaCount=1 --set csi.snapshotterReplicaCount=1 \
      --set preUpgradeChecker.jobEnabled=false --wait
    kubectl label namespace longhorn-system --overwrite pod-security.kubernetes.io/enforce=privileged >/dev/null
    kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: st-longhorn-1r}
provisioner: driver.longhorn.io
parameters: {numberOfReplicas: "1", dataEngine: v1, fsType: ext4}
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF
    ;;
esac

if [[ "${WITH_VELERO:-0}" == 1 ]]; then
  need VELERO_VERSION; need MINIO_IMAGE   # ex. image MinIO épinglée par digest
  command -v velero >/dev/null || die "CLI velero absente."
  kubectl create namespace st-minio --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n st-minio apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: minio}
spec:
  selector: {matchLabels: {app: minio}}
  template:
    metadata: {labels: {app: minio}}
    spec:
      containers:
        - name: minio
          image: $MINIO_IMAGE
          args: [server, /data]
          env: [{name: MINIO_ROOT_USER, value: sttest}, {name: MINIO_ROOT_PASSWORD, value: sttest-throwaway-only}]
          volumeMounts: [{name: d, mountPath: /data}]
      volumes: [{name: d, emptyDir: {}}]
---
apiVersion: v1
kind: Service
metadata: {name: minio}
spec: {selector: {app: minio}, ports: [{port: 9000}]}
EOF
  kubectl -n st-minio rollout status deploy/minio --timeout=180s
  kubectl -n st-minio run mc --rm -i --restart=Never --image=minio/mc --command -- sh -c \
    'mc alias set m http://minio:9000 sttest sttest-throwaway-only && mc mb -p m/velero' || true
  creds="$(mktemp)"; trap 'rm -f "$creds"' EXIT
  printf '[default]\naws_access_key_id=sttest\naws_secret_access_key=sttest-throwaway-only\n' > "$creds"
  velero install --use-node-agent --default-volumes-to-fs-backup --uploader-type kopia \
    --provider aws --plugins "velero/velero-plugin-for-aws:${VELERO_AWS_PLUGIN_VERSION:?}" \
    --bucket velero --secret-file "$creds" --use-volume-snapshots=false \
    --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.st-minio.svc:9000 --wait
  kubectl label namespace velero --overwrite pod-security.kubernetes.io/enforce=privileged >/dev/null
fi
echo "OK : moteur $ENGINE installé (classe $(storage_class))."
