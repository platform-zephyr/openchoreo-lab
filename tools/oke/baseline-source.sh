#!/usr/bin/env bash
# baseline-source.sh : prouve que le socle cluster de l'étape 0 (T-494) est une copie NON modifiée de kube-ops.
# Chaque fichier copié porte un en-tête de 5 lignes (source, commit, licence) ; le reste doit avoir le sha256 du
# fichier amont au commit épinglé. Hors cluster. Sans réseau par défaut ; --online refait le calcul depuis
# raw.githubusercontent.com (dépôt public SmadjaPaul/kube-ops) pour vérifier aussi les sha256 épinglés ici.
# Usage : tools/oke/baseline-source.sh [--online]     Code : 0 = conforme, 1 = écart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ONLINE=0; [[ "${1:-}" == --online ]] && ONLINE=1
UPSTREAM="https://raw.githubusercontent.com/SmadjaPaul/kube-ops"
PR1620=1ecb02f8da18ca986aa5178633b1e97c9ac4ed93   # kube-ops PR #1620 (baseline oracle-a1), tête de branche
PR1629=98a263fb2241dfac92b348ad1ad7f9d35a94cc30   # kube-ops PR #1629 (correctif C1 egress-isolated)
HEADER_LINES=5
# fichier local | commit amont | chemin amont | sha256 du fichier amont
SOURCES=(
  "platform/baseline/vap-baseline-pod-hardening.yaml|$PR1620|k8s/components/baseline-vap/pod-hardening.yaml|a8d0eabec7694c142eb8f26e0ed22a7db64545122c072764c1b0475e7e36fe73"
  "platform/baseline/vap-baseline-automount-token.yaml|$PR1620|k8s/components/baseline-vap/automount-token.yaml|61c6a4bc74616d3e9c07994b4192bc443439f8550c24df36f7f32c31ec30f97f"
  "platform/baseline/vap-baseline-image-digest.yaml|$PR1620|k8s/components/baseline-vap/image-digest.yaml|e56abec5241a9ea87992c97dccd3aa9542ad743bd78e5a3e5beddef56f436ac1"
  "platform/baseline/ccnp-imds.yaml|$PR1629|k8s/clusters/oracle-a1/baseline/imds-deny.yaml|f216d98d42dd29f30ef9cd6007718c0bd739cd19a506afa51a499c37ccb08c82"
  "platform/install/values/cilium.yaml|$PR1620|k8s/clusters/oracle-a1/bootstrap/cilium-values.yaml|8e517289bba0b635ff36045ccb0381def090b9456199f94ce80aa1657d1f5408"
)
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
rc=0
for e in "${SOURCES[@]}"; do
  IFS='|' read -r local commit path want <<<"$e"
  f="$ROOT/$local"
  if [[ ! -f "$f" ]]; then echo "FAIL $local absent"; rc=1; continue; fi
  if ! head -n 2 "$f" | grep -q "commit $commit, fichier $path\."; then
    echo "FAIL $local : en-tête sans « commit $commit, fichier $path »"; rc=1; continue
  fi
  got="$(tail -n +$((HEADER_LINES + 1)) "$f" | sha)"
  if [[ "$got" != "$want" ]]; then echo "FAIL $local : contenu modifié ($got != $want épinglé)"; rc=1; continue; fi
  if (( ONLINE )); then
    up="$(curl -fsSL --retry 3 "$UPSTREAM/$commit/$path" | sha)" || { echo "FAIL $local : amont illisible"; rc=1; continue; }
    [[ "$up" == "$want" ]] || { echo "FAIL $local : sha256 amont $up != $want épinglé"; rc=1; continue; }
  fi
  echo "PASS $local = kube-ops@${commit:0:7}:$path$( ((ONLINE)) && echo ' (vérifié en ligne)')"
done
exit "$rc"
