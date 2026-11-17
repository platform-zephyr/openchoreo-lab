#!/usr/bin/env bash
# measure.sh : empreinte de l'essai sur OKE (lecture seule). NON EXÉCUTÉ.
# Usage : tools/oke/measure.sh [LIBELLÉ]   (ex. « avant », « après-étape-7 », « repos-24h »)
# Mesure : usage (API summary du kubelet ; `kubectl top` en plus si metrics-server existe) et requests,
# par namespace, puis total de la pile (STACK_NS_RE) comparé au budget (1,5 Gi / 300m au repos).
# Écrit $STATE_DIR/measure-<horodatage>-<libellé>.txt (aucune valeur secrète). Code 3 si budget dépassé.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

label="${1:-mesure}"
guard_context
mkdir -p "$STATE_DIR"
out="$STATE_DIR/measure-$(date -u +%Y%m%dT%H%M%SZ)-$label.txt"
{
  echo "# $(date -u +%FT%TZ) OKE oracle-a1 libellé=$label"
  kubectl get nodes -o json | jq -r '.items[0] | "nœud allocatable cpu=\(.status.allocatable.cpu) mem=\(.status.allocatable.memory) pods=\(.status.allocatable.pods)"'
  echo "-- usage par namespace (cpu m, mem Mi ; API summary du kubelet, instantané)"
  usage_by_ns
  echo "-- requests par namespace (cpu m, mem Mi)"
  requests_by_ns
  if kubectl top nodes >/dev/null 2>&1; then
    echo "-- kubectl top"; kubectl top nodes; kubectl top pods -A --no-headers | sort
  fi
  echo "-- pile de l'essai ($STACK_NS_RE)"
  read -r cpu mem < <(stack_usage)
  read -r rcpu rmem < <(requests_by_ns | awk -v re="$STACK_NS_RE" '$1 ~ re {c+=$2; m+=$3} END {printf "%d %d\n", c, m}')
  echo "usage=${cpu}m/${mem}Mi requests=${rcpu}m/${rmem}Mi budget-usage=${BUDGET_CPU_M}m/${BUDGET_MEM_MI}Mi"
  echo "référence k3d (tests/k3d/RESULTS.md) : CP+DP usage 30-60m/480Mi, requests 850m/1088Mi (avant réduction)"
} | tee "$out"
read -r cpu mem < <(stack_usage)
if (( mem > BUDGET_MEM_MI || cpu > BUDGET_CPU_M )); then
  log "BUDGET DÉPASSÉ (${cpu}m/${mem}Mi) : arrêt et rapport (missions/MISSION.md)"; exit 3
fi
log "dans le budget (${cpu}m/${mem}Mi) ; fichier : $out"
