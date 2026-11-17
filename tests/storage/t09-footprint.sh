#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Génère une charge d'écriture sur un PVC.
# =============================================================================================
# T-09 : empreinte du moteur ENGINE, à comparer entre moteurs (même VM, même charge) :
#   - pods du moteur, somme des requests CPU/mémoire (au repos) ;
#   - CPU/mémoire réels (metrics-server de k3s), 10 relevés à 30 s au repos puis sous charge ;
#   - octets écrits sur les disques du nœud (/proc/diskstats) pour 512 Mio écrits par l'app en
#     petites écritures fsync (proxy de l'amplification d'écriture).
# Sortie : evidence/T-09-<engine>.csv. Le verdict compare au budget OKE : PASS si le moteur ajoute
# <= 2 pods et <= 100m CPU / 128 Mi de requests ; sinon FAIL (avec les chiffres). Ce n'est pas un
# critère sur Talos, où la comparaison avec Longhorn est le résultat attendu.
source "$(dirname "$0")/lib.sh"
guard
ENS="$(engine_namespace)"
CSV="$EVIDENCE_DIR/T-09-$ENGINE.csv"
sel=""; [[ $ENGINE == local-path ]] && sel="-l app=local-path-provisioner"
# shellcheck disable=SC2086
pods="$(kubectl -n "$ENS" get pods $sel --no-headers | wc -l | tr -d ' ')"
# shellcheck disable=SC2086
req="$(kubectl -n "$ENS" get pods $sel -o json | jq -r '
  def cpu: if . == null then 0 elif endswith("m") then (.[:-1]|tonumber) else (tonumber*1000) end;
  def mem: if . == null then 0 elif endswith("Mi") then (.[:-2]|tonumber) elif endswith("Gi") then (.[:-2]|tonumber*1024) elif endswith("Ki") then (.[:-2]|tonumber/1024) else (tonumber/1048576) end;
  [.items[].spec.containers[].resources.requests // {}] | "\(map(.cpu|cpu)|add // 0) \(map(.memory|mem)|add // 0)"')"
read -r REQ_CPU REQ_MEM <<<"$req"
echo "phase,ts,pod,cpu_m,mem_mi" > "$CSV"
sample() { # phase
  # shellcheck disable=SC2086
  kubectl top pods -n "$ENS" $sel --no-headers 2>/dev/null | awk -v p="$1" -v t="$(date -u +%FT%TZ)" '{gsub("m","",$2); gsub("Mi","",$3); print p","t","$1","$2","$3}' >> "$CSV"
}
for _ in $(seq 1 10); do sample idle; sleep 30; done

disk_writes() { node_exec awk '$3 ~ /^(vd|sd|nvme|loop|dm-)/ {s+=$10} END {print s*512}' /proc/diskstats 2>/dev/null || echo NA; }
ns="$(new_ns t09)"; trap 'drop_ns "$ns"' EXIT
make_pvc "$ns" d 1Gi; make_pod "$ns" w d
w0="$(disk_writes)"
( for _ in $(seq 1 10); do sample load; sleep 30; done ) &
pexec "$ns" w 'i=0; while [ $i -lt 2048 ]; do dd if=/dev/urandom of=/data/d/s$((i%64)) bs=256k count=1 conv=fsync 2>/dev/null; i=$((i+1)); done'
wait
w1="$(disk_writes)"
amp="NA"; [[ $w0 != NA && $w1 != NA ]] && amp="$(awk -v a="$w0" -v b="$w1" 'BEGIN{printf "%.2f", (b-a)/(512*1048576)}')"
echo "pods=$pods req_cpu_m=$REQ_CPU req_mem_mi=$REQ_MEM disk_bytes_written=$((${w1/NA/0} - ${w0/NA/0})) amplification=$amp" | tee -a "$CSV" | evidence T-09
if [[ $pods -le 2 && ${REQ_CPU%.*} -le 100 && ${REQ_MEM%.*} -le 128 ]]; then
  record T-09 PASS "budget OKE respecté : $pods pods, ${REQ_CPU}m, ${REQ_MEM}Mi requests ; amplification $amp"
else
  record T-09 FAIL "hors budget OKE : $pods pods, ${REQ_CPU}m, ${REQ_MEM}Mi requests ; amplification $amp (comparer à Longhorn)"
fi
finish
