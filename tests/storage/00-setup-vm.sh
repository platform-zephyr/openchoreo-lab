#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE DANS UNE VM DE TEST JETABLE (Lima, Multipass, VM Proxmox de test vide).
# Crée des disques loopback, des VG LVM, un FS XFS avec project quota, installe k3s et pose le
# marqueur du banc. Refuse de tourner sur Talos, Proxmox, un nœud OKE ou une machine qui a déjà
# un kubelet. JAMAIS exécuté à la préparation (2026-11-17).
# =============================================================================================
# Usage (dans la VM, Ubuntu 24.04 arm64 ou amd64) :
#   STORAGE_TEST_VM_CONFIRM="$(hostname)" sudo -E tests/storage/00-setup-vm.sh
# Produit : /var/lib/storage-test/{fast,bulk,hostpath}.img, VG st-fast (4 Gio) et st-bulk (8 Gio),
# /mnt/st-hostpath (XFS 4 Gio, prjquota), k3s mono-nœud, kubeconfig /root/storage-test.kubeconfig,
# contexte "storage-test", ConfigMap default/storage-test-disposable.
set -euo pipefail

die() { echo "ABANDON : $*" >&2; exit 2; }
[[ $EUID -eq 0 ]] || die "lancer avec sudo -E."
[[ "${STORAGE_TEST_VM_CONFIRM:-}" == "$(hostname)" ]] || die "STORAGE_TEST_VM_CONFIRM doit valoir le hostname de la VM jetable."
grep -qiE 'oke|oracle|homeops|tatouine|talos|prod' <<<"$(hostname)" && die "hostname de production."
[[ -e /etc/pve ]] && die "hôte Proxmox détecté."
[[ -e /usr/local/bin/talosctl || -e /system/state ]] && die "Talos détecté."
grep -qi 'oracle' /sys/class/dmi/id/sys_vendor 2>/dev/null && die "instance Oracle Cloud détectée."
pgrep -x kubelet >/dev/null && die "un kubelet tourne déjà sur cette machine."
[[ -e /var/lib/storage-test ]] && die "/var/lib/storage-test existe déjà : VM déjà préparée (recréer la VM)."

apt-get update -qq
apt-get install -y -qq lvm2 thin-provisioning-tools xfsprogs curl jq fio >/dev/null
modprobe dm_snapshot
modprobe dm_thin_pool

mkdir -p /var/lib/storage-test
loopdev() { local img=$1 size=$2; truncate -s "$size" "$img"; losetup --find --show "$img"; }
FAST=$(loopdev /var/lib/storage-test/fast.img 4G)
BULK=$(loopdev /var/lib/storage-test/bulk.img 8G)
HP=$(loopdev /var/lib/storage-test/hostpath.img 4G)
pvcreate -q "$FAST" "$BULK"
vgcreate -q st-fast "$FAST"
vgcreate -q st-bulk "$BULK"
mkfs.xfs -q "$HP"
mkdir -p /mnt/st-hostpath
mount -o prjquota "$HP" /mnt/st-hostpath
# Note : les loop devices ne survivent pas au redémarrage ; T-03 (redémarrage du nœud) utilise
# /etc/storage-test-reattach.sh pour les réattacher, ce qui exerce aussi T-07.
cat > /etc/storage-test-reattach.sh <<EOF
#!/bin/sh
losetup $FAST /var/lib/storage-test/fast.img 2>/dev/null || true
losetup $BULK /var/lib/storage-test/bulk.img 2>/dev/null || true
losetup $HP /var/lib/storage-test/hostpath.img 2>/dev/null || true
vgchange -ay st-fast st-bulk
mountpoint -q /mnt/st-hostpath || mount -o prjquota $HP /mnt/st-hostpath
EOF
chmod +x /etc/storage-test-reattach.sh

# k3s épinglé ; local-path intégré conservé (moteur "local-path").
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION:-v1.33.5+k3s1}" \
  INSTALL_K3S_EXEC="--write-kubeconfig /root/storage-test.kubeconfig --write-kubeconfig-mode 600 --node-name st-node-a --disable traefik" sh -
export KUBECONFIG=/root/storage-test.kubeconfig
kubectl config rename-context default storage-test
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl -n default create configmap storage-test-disposable \
  --from-literal=disposable=true --from-literal=context=storage-test --from-literal=created="$(date -u +%FT%TZ)"
echo "OK : export KUBECONFIG=/root/storage-test.kubeconfig STORAGE_TEST_ALLOWED_CONTEXTS=storage-test"
echo "     (le K3S_VERSION épinglé est à vérifier avant usage : version citée de mémoire [NV])"
