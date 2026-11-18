#!/usr/bin/env bash
# measure.sh : relevé de capacité du homelab, STRICTEMENT en lecture seule (T-360, ADR-0003, ADR-0017).
#
# Usage (sur l'hôte Proxmox, aucun sudo obligatoire ; root donne plus de résultats) :
#   bash measure.sh > homelab-mesures.yaml          # YAML anonymisé sur stdout, progression sur stderr
#   bash measure.sh --out homelab-mesures.yaml      # même chose, fichier créé (refus si déjà présent)
#   bash measure.sh --label avant --only ram,arc    # sections ciblées (ex. avant/après arrêt de services)
#   bash measure.sh --help
#
# Garanties :
#   - aucune écriture hors du fichier donné à --out ; aucun fichier temporaire ; aucun sudo ; aucune mutation ;
#   - chaque commande système passe par `ro`, qui n'accepte qu'une liste fermée de sous-commandes de lecture
#     (qm list|config, pvesh get, pvesm status, zpool list|status, sensors, sar, arc_summary, df, curl -G) ;
#   - aucun envoi réseau, sauf des GET vers l'API Prometheus si Paul fournit PROM_URL ; l'URL n'est jamais écrite
#     dans la sortie ;
#   - sortie anonymisée : aucune IP, aucun nom d'hôte, aucun UUID, aucun MAC, aucun nom de VM, de pool ou de stockage ;
#     les VM sont désignées `vm-kube-ops` et `vm-lab`. Une passe finale remplace en plus tout motif d'IP, de MAC, d'UUID
#     et les noms réellement lus (hôte, VM).
#   - chaque mesure indisponible rend `status: NOT_AVAILABLE` avec une raison ; le script rend toujours 0.
#
# Variables d'environnement (toutes facultatives) :
#   PROM_URL                 base de l'API Prometheus (http://… ou https://…), sans identifiants
#   KUBEOPS_VMID, LAB_VMID   numéros de VM, si la détection par le nom (kube|talos|k8s ; lab) ne suffit pas ; jamais écrits
#   PROM_KUBEOPS_CPU_QUERY, PROM_KUBEOPS_RAM_QUERY, PROM_LAB_CPU_QUERY, PROM_LAB_RAM_QUERY
#                            requêtes PromQL de remplacement : CPU = ratio 0..1 de la VM, RAM = octets utilisés, une seule
#                            série. Par défaut : métriques de prometheus-pve-exporter (pve_cpu_usage_ratio,
#                            pve_memory_usage_bytes) filtrées sur id="qemu/<vmid>".
#   PROM_TCTL_QUERY          requête PromQL de la température Tctl en °C (ex. node_hwmon_temp_celsius{…}), une série
#   Crochets de test : MEASURE_PROC, MEASURE_SYS, MEASURE_QEMU_RUN, MEASURE_SA_DIR (défauts : /proc, /sys,
#   /run/qemu-server, /var/log/sysstat).
#
# Sections (--only a,b) : host, vms, usage, storage, temperature, arc, ram.
# shellcheck disable=SC2329  # fonctions appelées indirectement (sec_<nom>)
set -u
export LC_ALL=C

SCHEMA="homelab-mesures.v1"
WINDOW_DAYS=14
PROC="${MEASURE_PROC:-/proc}"
SYS="${MEASURE_SYS:-/sys}"
QEMU_RUN="${MEASURE_QEMU_RUN:-/run/qemu-server}"
SA_DIR="${MEASURE_SA_DIR:-/var/log/sysstat}"
ALL_SECTIONS="host vms usage storage temperature arc ram"

LABEL="base"
OUT_FILE=""
ONLY=""

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --label) LABEL="${2:-}"; shift 2 ;;
    --out) OUT_FILE="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "option inconnue : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
[[ "$LABEL" =~ ^[a-z0-9-]{1,32}$ ]] || { echo "--label : [a-z0-9-], 1 à 32 caractères" >&2; exit 2; }
if [ -n "$ONLY" ]; then
  for s in ${ONLY//,/ }; do
    [[ " $ALL_SECTIONS " == *" $s "* ]] || { echo "--only : section inconnue : $s" >&2; exit 2; }
  done
fi
want() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }

# ---------------------------------------------------------------------------------------------------------------
# Garde lecture seule : seule porte d'accès aux commandes système.
# Retours : 0/échec de la commande ; 126 refusée par la garde ; 127 commande absente.
# ---------------------------------------------------------------------------------------------------------------
refuse() { echo "REFUSED: commande hors liste de lecture seule : $*" >&2; }
ro() {
  local c="$1" a="${2:-}" arg g=0
  case "$c" in
    qm) case "$a" in list | config) ;; *) refuse "$@"; return 126 ;; esac ;;
    pvesh) [ "$a" = get ] || { refuse "$@"; return 126; } ;;
    pvesm) [ "$a" = status ] || { refuse "$@"; return 126; } ;;
    zpool) case "$a" in list | status) ;; *) refuse "$@"; return 126 ;; esac ;;
    sensors | arc_summary | sar | df) ;;
    curl)
      for arg in "${@:2}"; do
        case "$arg" in
          -G | --get) g=1 ;;
          -X | --request | -d | --data | --data-raw | --data-binary | -T | --upload-file | -F | --form | \
            -o | --output | -O | -K | --config | -u | --user | --json) refuse "$@"; return 126 ;;
        esac
      done
      [ "$g" = 1 ] || { refuse "$@"; return 126; }
      ;;
    *) refuse "$@"; return 126 ;;
  esac
  command -v "$c" > /dev/null 2>&1 || return 127
  "$c" "${@:2}"
}
reason_rc() { # $1 outil, $2 code retour
  case "$2" in
    127) printf 'commande absente : %s' "$1" ;;
    126) printf 'refusée par la garde lecture seule : %s' "$1" ;;
    *) printf '%s a échoué (code %s), droits insuffisants ou service arrêté' "$1" "$2" ;;
  esac
}
progress() { echo "[mesure] $*" >&2; }

# ---------------------------------------------------------------------------------------------------------------
# Aides de présentation et de calcul
# ---------------------------------------------------------------------------------------------------------------
na() { printf '%sstatus: NOT_AVAILABLE\n%sreason: "%s"\n' "$1" "$1" "$2"; }
div() { awk -v a="$1" -v d="$2" 'BEGIN{printf "%.2f", a/d}'; }
# stats MULT : lit des nombres sur stdin ; écrit "n p50 p95 max" (rang le plus proche) ; code 1 si vide.
stats() {
  sort -g | awk -v m="${1:-1}" '
    function ceil(x) { return (x == int(x)) ? x : int(x) + 1 }
    NF { a[++n] = $1 * m }
    END {
      if (n == 0) exit 1
      r50 = ceil(0.50 * n); r95 = ceil(0.95 * n); if (r50 < 1) r50 = 1; if (r95 < 1) r95 = 1
      printf "%d %.4f %.4f %.4f\n", n, a[r50], a[r95], a[n]
    }'
}
maxof() { sort -g | awk -v m="${1:-1}" 'NF { v = $1 * m; if (!s || v > x) x = v; s = 1 } END { if (s) printf "%.4f\n", x; else exit 1 }'; }
# emit_stat INDENT NOM UNITE "n p50 p95 max" [PIC]
emit_stat() {
  local p="${5:-$(printf '%s' "$4" | awk '{print $4}')}"
  printf '%s%s: {unit: %s, p50: %s, p95: %s, peak: %s}\n' "$1" "$2" "$3" \
    "$(printf '%s' "$4" | awk '{print $2}')" "$(printf '%s' "$4" | awk '{print $3}')" "$p"
}

# ---------------------------------------------------------------------------------------------------------------
# Lectures communes (variables globales, sans sortie)
# ---------------------------------------------------------------------------------------------------------------
NODE_NAME=""
[ -r "$PROC/sys/kernel/hostname" ] && read -r NODE_NAME < "$PROC/sys/kernel/hostname"

meminfo_kb() { awk -v k="$1:" '$1 == k { print $2; exit }' "$PROC/meminfo" 2> /dev/null; }
arcstat() { awk -v k="$1" '$1 == k { print $3; exit }' "$PROC/spl/kstat/zfs/arcstats" 2> /dev/null; }

declare -a VM_ID=() VM_NAME=() VM_STATE=() VM_MEM=()
VM_REASON=""
KO_ID="" LAB_ID="" KO_IDX=-1 LAB_IDX=-1 KO_REASON="" LAB_REASON=""

discover_vms() {
  local out rc first=1 id name state mem
  out=$(ro qm list 2> /dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then VM_REASON=$(reason_rc qm "$rc"); return; fi
  while read -r id name state mem _ _; do
    if [ "$first" = 1 ]; then first=0; continue; fi
    [[ "$id" =~ ^[0-9]+$ ]] || continue
    VM_ID+=("$id"); VM_NAME+=("$name"); VM_STATE+=("$state"); VM_MEM+=("$mem")
  done <<< "$out"
}
find_idx() { local i; for i in "${!VM_ID[@]}"; do [ "${VM_ID[$i]}" = "$1" ] && { echo "$i"; return; }; done; echo -1; }
# match_by_name REGEX [INDEX_EXCLU] : écrit l'index unique, -1 (aucun) ou -2 (ambigu)
match_by_name() {
  local i hit=-1 n=0
  for i in "${!VM_ID[@]}"; do
    [ "$i" = "${2:--9}" ] && continue
    if [[ "${VM_NAME[$i]}" =~ $1 ]]; then hit=$i; n=$((n + 1)); fi
  done
  if [ "$n" -gt 1 ]; then echo -2; else echo "$hit"; fi
}
identify_vms() {
  local env_ko="${KUBEOPS_VMID:-}" env_lab="${LAB_VMID:-}"
  [[ "$env_ko" =~ ^[0-9]+$ ]] || env_ko=""
  [[ "$env_lab" =~ ^[0-9]+$ ]] || env_lab=""
  if [ -n "$env_ko" ]; then
    KO_ID="$env_ko"; KO_IDX=$(find_idx "$env_ko")
  else
    KO_IDX=$(match_by_name '[Kk]ube|[Tt]alos|[Kk]8s')
    if [ "$KO_IDX" = -2 ]; then KO_IDX=-1; KO_REASON="plusieurs VM correspondent à kube-ops ; fournir KUBEOPS_VMID"
    elif [ "$KO_IDX" = -1 ]; then KO_REASON="VM kube-ops non identifiée ; fournir KUBEOPS_VMID"
    else KO_ID="${VM_ID[$KO_IDX]}"; fi
  fi
  if [ -n "$env_lab" ]; then
    LAB_ID="$env_lab"; LAB_IDX=$(find_idx "$env_lab")
  else
    LAB_IDX=$(match_by_name '[Ll]ab' "$KO_IDX")
    if [ "$LAB_IDX" = -2 ]; then LAB_IDX=-1; LAB_REASON="plusieurs VM correspondent à lab ; fournir LAB_VMID"
    elif [ "$LAB_IDX" = -1 ]; then LAB_REASON="VM lab non identifiée (absente ou pas encore créée) ; LAB_VMID si elle existe"
    else LAB_ID="${VM_ID[$LAB_IDX]}"; fi
  fi
}

# vm_config VMID : renseigne CFG_VCPUS, CFG_MEM_MIB, CFG_BALLOON_MIB (vides si illisibles). Seules les clés utiles sont lues.
vm_config() {
  local cfg rc cores sockets vcpus
  CFG_VCPUS="" CFG_MEM_MIB="" CFG_BALLOON_MIB=""
  cfg=$(ro qm config "$1" 2> /dev/null)
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  cores=$(printf '%s\n' "$cfg" | awk -F': *' '$1 == "cores" { print $2; exit }')
  sockets=$(printf '%s\n' "$cfg" | awk -F': *' '$1 == "sockets" { print $2; exit }')
  vcpus=$(printf '%s\n' "$cfg" | awk -F': *' '$1 == "vcpus" { print $2; exit }')
  CFG_MEM_MIB=$(printf '%s\n' "$cfg" | awk -F': *' '$1 == "memory" { print $2; exit }')
  CFG_BALLOON_MIB=$(printf '%s\n' "$cfg" | awk -F': *' '$1 == "balloon" { print $2; exit }')
  if [[ "$vcpus" =~ ^[0-9]+$ ]]; then CFG_VCPUS="$vcpus"
  elif [[ "$cores" =~ ^[0-9]+$ ]]; then CFG_VCPUS=$((cores * ${sockets:-1})); fi
  [[ "$CFG_MEM_MIB" =~ ^[0-9]+$ ]] || CFG_MEM_MIB=""
  [[ "$CFG_BALLOON_MIB" =~ ^[0-9]+$ ]] || CFG_BALLOON_MIB=""
  return 0
}
# vm_rss_mib VMID : RSS du processus qemu sur l'hôte (MiB), vide si illisible
vm_rss_mib() {
  local pid=""
  [ -r "$QEMU_RUN/$1.pid" ] && read -r pid < "$QEMU_RUN/$1.pid"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  awk '$1 == "VmRSS:" { printf "%.0f\n", $2 / 1024; f = 1 } END { exit !f }' "$PROC/$pid/status" 2> /dev/null
}

# ---------------------------------------------------------------------------------------------------------------
# Prometheus (GET seulement) et RRD Proxmox
# ---------------------------------------------------------------------------------------------------------------
PROM_ERR=""
prom_values() { # QUERY -> valeurs, une par ligne ; code 0 si une seule série non vide
  local end start body rc n
  PROM_ERR=""
  case "${PROM_URL:-}" in http://* | https://*) ;; *) PROM_ERR="PROM_URL absente ou sans schéma http(s)"; return 1 ;; esac
  end=$(date -u +%s)
  start=$((end - WINDOW_DAYS * 86400))
  body=$(ro curl -sS -f --max-time 60 -G "${PROM_URL%/}/api/v1/query_range" --data-urlencode "query=$1" \
    --data-urlencode "start=$start" --data-urlencode "end=$end" --data-urlencode "step=300" 2> /dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then PROM_ERR=$(reason_rc curl "$rc"); return 1; fi
  case "$body" in *'"status":"success"'*) ;; *) PROM_ERR="réponse Prometheus sans status success"; return 1 ;; esac
  n=$(printf '%s' "$body" | grep -o '"metric"' | wc -l)
  if [ "$n" -eq 0 ]; then PROM_ERR="la requête ne renvoie aucune série"; return 1; fi
  if [ "$n" -gt 1 ]; then PROM_ERR="la requête renvoie $n séries ; en fournir une seule"; return 1; fi
  printf '%s' "$body" | grep -oE '\[[0-9]+(\.[0-9]+)?,"[-+0-9.eE]+"\]' | sed -E 's/.*,"([^"]*)"\]/\1/'
  return 0
}
# rrd_pairs JSON CLE : "temps valeur" pour les 14 derniers jours
rrd_pairs() {
  local since
  since=$(($(date -u +%s) - WINDOW_DAYS * 86400))
  printf '%s' "$1" | tr -d '\n' | sed 's/},[[:space:]]*{/}\n{/g' | awk -v since="$since" -v key="$2" '
    { t = ""; v = ""
      if (match($0, /"time":[0-9]+/)) t = substr($0, RSTART + 7, RLENGTH - 7)
      if (match($0, "\"" key "\":-?[0-9.eE+-]+")) { v = substr($0, RSTART, RLENGTH); sub(/^[^:]*:/, "", v) }
      if (t != "" && v != "" && t + 0 >= since) print t, v }'
}
rrd_json() { # VMID CF
  local node="$NODE_NAME" out rc
  [ -n "$node" ] || return 125
  out=$(ro pvesh get "/nodes/$node/qemu/$1/rrddata" --timeframe month --cf "$2" --output-format json 2> /dev/null)
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  printf '%s' "$out"
}

# usage_vm INDENT LABEL VMID IDX : bloc `usage_14d`. Retourne 0 si mesuré.
USAGE_NEEDS_SAR=0
usage_vm() {
  local ind="$1" label="$2" id="$3" up cq rq cpu ram pairs peakpair json cstat rstat gran n src="" why="" rc=0
  up=$(printf '%s' "$label" | tr 'a-z-' 'A-Z_')
  if [ -z "$id" ]; then na "$ind" "VM non identifiée"; USAGE_NEEDS_SAR=1; return 1; fi
  vm_config "$id" || true
  # 1. Prometheus
  if [ -n "${PROM_URL:-}" ]; then
    local vcq="PROM_${up}_CPU_QUERY" vrq="PROM_${up}_RAM_QUERY"
    cq="${!vcq:-pve_cpu_usage_ratio{id=\"qemu/$id\"}}"
    rq="${!vrq:-pve_memory_usage_bytes{id=\"qemu/$id\"}}"
    if cpu=$(prom_values "$cq") && ram=$(prom_values "$rq"); then
      src="prometheus"; gran=300
      cstat=$(printf '%s\n' "$cpu" | stats 1); rstat=$(printf '%s\n' "$ram" | stats 9.313225746154785e-10)
      n=$(printf '%s' "$cstat" | awk '{print $1}')
    else
      why="Prometheus : $PROM_ERR"
    fi
  else
    why="PROM_URL non fournie"
  fi
  # 2. RRD de Proxmox (pvesh)
  if [ -z "$src" ]; then
    if json=$(rrd_json "$id" AVERAGE); then
      pairs=$(rrd_pairs "$json" cpu); cpu=$(printf '%s\n' "$pairs" | awk 'NF{print $2}')
      ram=$(rrd_pairs "$json" mem | awk 'NF{print $2}')
      if [ -n "$cpu" ] && [ -n "$ram" ]; then
        src="pvesh_rrd"
        gran=$(printf '%s\n' "$pairs" | awk 'NF { t = $1; if (!a || t < a) a = t; if (t > b) b = t; n++ } END { if (n > 1) printf "%d", (b - a) / (n - 1) }')
        cstat=$(printf '%s\n' "$cpu" | stats 1); rstat=$(printf '%s\n' "$ram" | stats 9.313225746154785e-10)
        n=$(printf '%s' "$cstat" | awk '{print $1}')
        if json=$(rrd_json "$id" MAX); then
          peakpair=$(rrd_pairs "$json" cpu | awk '{print $2}' | maxof 1) || peakpair=""
          CPU_PEAK="$peakpair"
          RAM_PEAK=$(rrd_pairs "$json" mem | awk '{print $2}' | maxof 9.313225746154785e-10) || RAM_PEAK=""
        fi
      else
        why="$why ; pvesh : aucun point RRD sur $WINDOW_DAYS jours"
      fi
    else
      rc=$?
      why="$why ; pvesh : $(reason_rc pvesh "$rc")"
    fi
  fi
  if [ -z "$src" ]; then na "$ind" "${why# ; }"; USAGE_NEEDS_SAR=1; return 1; fi
  printf '%sstatus: MEASURED\n%ssource: %s\n%swindow_days: %s\n%ssamples: %s\n%sgranularity_s: %s\n' \
    "$ind" "$ind" "$src" "$ind" "$WINDOW_DAYS" "$ind" "$n" "$ind" "${gran:-unknown}"
  if [ "$src" = pvesh_rrd ]; then
    printf '%snote: "p50 et p95 sur des moyennes RRD (lissées, sous-estiment les pointes) ; peak = maximum RRD (cf MAX)"\n' "$ind"
  else
    printf '%snote: "p50, p95 et peak sur des échantillons de 5 min (peak lissé sur 5 min)"\n' "$ind"
  fi
  printf '%smethod: nearest-rank\n' "$ind"
  emit_stat "$ind" cpu_ratio ratio_0_1 "$cstat" "${CPU_PEAK:-}"
  if [ -n "$CFG_VCPUS" ]; then
    emit_stat "$ind" cpu_cores_equiv cores "$(printf '%s\n' "$cpu" | stats "$CFG_VCPUS")" \
      "$([ -n "${CPU_PEAK:-}" ] && awk -v p="$CPU_PEAK" -v v="$CFG_VCPUS" 'BEGIN{printf "%.4f", p*v}')"
  fi
  emit_stat "$ind" ram_gib GiB "$rstat" "${RAM_PEAK:-}"
  if [ -n "$CFG_MEM_MIB" ]; then
    emit_stat "$ind" ram_pct_of_configured percent \
      "$(printf '%s\n' "$ram" | stats "$(awk -v m="$CFG_MEM_MIB" 'BEGIN{printf "%.10f", 100 / (m * 1048576)}')")" \
      "$([ -n "${RAM_PEAK:-}" ] && awk -v p="$RAM_PEAK" -v m="$CFG_MEM_MIB" 'BEGIN{printf "%.4f", p * 1024 / m * 100}')"
  fi
  return 0
}

# sar_host : p50/p95/max hôte (CPU occupé, % mémoire utilisée) sur les fichiers sysstat des 14 derniers jours
sar_values() { # OPTION COLONNE -> valeurs
  local f files
  files=$(find "$SA_DIR" -maxdepth 1 -type f -name 'sa[0-9][0-9]' -mtime "-$((WINDOW_DAYS + 1))" 2> /dev/null | sort)
  [ -n "$files" ] || return 1
  for f in $files; do
    ro sar "$1" -f "$f" 2> /dev/null | awk -v col="$2" '
      $0 ~ col && !idx { for (i = 1; i <= NF; i++) if ($i == col) idx = i; nf = NF; next }
      idx && $1 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/ && NF >= nf { v = $idx; if (v ~ /^[0-9.]+$/) print v }'
  done
}

# ---------------------------------------------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------------------------------------------
sec_host() {
  local threads load mt ma
  echo "host:"
  threads=$(grep -c '^processor' "$PROC/cpuinfo" 2> /dev/null)
  mt=$(meminfo_kb MemTotal)
  if [ -z "$mt" ] && [ -z "$threads" ]; then na "  " "lecture de /proc impossible"; return; fi
  echo "  status: MEASURED"
  [ -n "$threads" ] && echo "  cpu_threads: $threads"
  load=$(awk '{ printf "{1m: %s, 5m: %s, 15m: %s}", $1, $2, $3 }' "$PROC/loadavg" 2> /dev/null)
  [ -n "$load" ] && echo "  load_average: $load"
  if [ -n "$mt" ]; then
    ma=$(meminfo_kb MemAvailable)
    echo "  mem_total_gib: $(div "$mt" 1048576)"
    [ -n "$ma" ] && echo "  mem_available_gib: $(div "$ma" 1048576)"
  fi
}

sec_vms() {
  local lbl id idx state rss n_run=0 alloc=0 i
  echo "vms:"
  if [ -n "$VM_REASON" ] && [ -z "$KO_ID" ] && [ -z "$LAB_ID" ]; then na "  " "$VM_REASON"; return; fi
  echo "  status: MEASURED"
  if [ -z "$VM_REASON" ]; then
    for i in "${!VM_ID[@]}"; do
      if [ "${VM_STATE[$i]}" = running ]; then n_run=$((n_run + 1)); alloc=$((alloc + ${VM_MEM[$i]:-0})); fi
    done
    echo "  total: ${#VM_ID[@]}"
    echo "  running: $n_run"
    echo "  memory_allocated_running_gib: $(div "$alloc" 1024)"
  fi
  for lbl in kube-ops lab; do
    if [ "$lbl" = kube-ops ]; then id="$KO_ID"; idx="$KO_IDX"; else id="$LAB_ID"; idx="$LAB_IDX"; fi
    echo "  vm-$lbl:"
    if [ -z "$id" ]; then na "    " "$([ "$lbl" = kube-ops ] && echo "$KO_REASON" || echo "$LAB_REASON")"; continue; fi
    state=""; [ "$idx" -ge 0 ] && state="${VM_STATE[$idx]}"
    echo "    identified: true"
    [ -n "$state" ] && echo "    state: $state"
    if vm_config "$id"; then
      echo "    configured: {vcpus: ${CFG_VCPUS:-unknown}, memory_mib: ${CFG_MEM_MIB:-unknown}, balloon_mib: ${CFG_BALLOON_MIB:-unknown}}"
    else
      echo "    configured: NOT_AVAILABLE"
    fi
    rss=$(vm_rss_mib "$id") && echo "    host_rss_mib: $rss"
  done
}

sec_usage() {
  local lbl id sar_cpu sar_mem cs rs
  echo "usage_14d:"
  USAGE_NEEDS_SAR=0
  for lbl in kube-ops lab; do
    if [ "$lbl" = kube-ops ]; then id="$KO_ID"; else id="$LAB_ID"; fi
    echo "  vm-$lbl:"
    CPU_PEAK="" RAM_PEAK=""
    usage_vm "    " "$lbl" "$id" || true
  done
  if [ "$USAGE_NEEDS_SAR" = 1 ]; then
    echo "  host_sar:"
    sar_cpu=$(sar_values -u '%idle' | awk '{ print 100 - $1 }')
    sar_mem=$(sar_values -r '%memused')
    if [ -z "$sar_cpu" ] && [ -z "$sar_mem" ]; then
      if ! command -v sar > /dev/null 2>&1; then na "    " "commande absente : sar"; else na "    " "aucun fichier sysstat sur $WINDOW_DAYS jours"; fi
    else
      echo "    status: MEASURED"
      echo "    scope: host   # PAS la VM : repli quand ni Prometheus ni pvesh ne donnent la VM"
      echo "    source: sar"
      if cs=$(printf '%s\n' "$sar_cpu" | stats 1); then emit_stat "    " cpu_busy_percent percent "$cs"; fi
      if rs=$(printf '%s\n' "$sar_mem" | stats 1); then emit_stat "    " mem_used_percent percent "$rs"; fi
    fi
  fi
}

sec_storage() {
  local out rc n=0 name size alloc free frag cap health st media layout label
  echo "storage:"
  echo "  zfs_pools:"
  out=$(ro zpool list -H -p 2> /dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then na "    " "$(reason_rc zpool "$rc")"; else
    while IFS=$'\t' read -r name size alloc free _ _ frag cap _ health _; do
      [ -n "$name" ] || continue
      n=$((n + 1)); label="pool-$n"
      st=$(ro zpool status -P "$name" 2> /dev/null)
      media="unknown"; layout="unknown"
      if [ -n "$st" ]; then
        if printf '%s' "$st" | grep -qi 'nvme'; then media="nvme"; else media="non-nvme"; fi
        if printf '%s' "$st" | grep -qE '^[[:space:]]+mirror-'; then layout="mirror"
        elif printf '%s' "$st" | grep -qE '^[[:space:]]+raidz'; then layout="raidz"
        else layout="single_or_stripe"; fi
      fi
      echo "    $label:"
      echo "      media_guess: $media   # d'après le type des disques ; à confirmer par Paul (NVMe ou miroir HDD)"
      echo "      layout: $layout"
      echo "      health: $health"
      echo "      size_gib: $(div "$size" 1073741824)"
      echo "      allocated_gib: $(div "$alloc" 1073741824)"
      echo "      free_gib: $(div "$free" 1073741824)"
      echo "      used_percent: ${cap:-unknown}"
      echo "      fragmentation_percent: ${frag:--}"
    done <<< "$out"
    [ "$n" -eq 0 ] && na "    " "aucun pool ZFS"
  fi
  echo "  proxmox_storages:"
  out=$(ro pvesm status 2> /dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then na "    " "$(reason_rc pvesm "$rc")"; else
    n=0
    while read -r name typ stat total used _ pct; do
      [ "$name" = Name ] && continue
      [[ "$total" =~ ^[0-9]+$ ]] || continue
      n=$((n + 1))
      echo "    storage-$n: {type: $typ, status: $stat, total_gib: $(div "$total" 1048576), used_gib: $(div "$used" 1048576), used_percent: ${pct%\%}}"
    done <<< "$out"
    [ "$n" -eq 0 ] && na "    " "aucun stockage Proxmox lisible"
  fi
  echo "  filesystems:"
  out=$(ro df -P -T -B1 2> /dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then na "    " "$(reason_rc df "$rc")"; else
    n=0
    while read -r name typ total used _ pct mnt; do
      case "$typ" in ext4 | xfs | btrfs | vfat | ext3) ;; *) continue ;; esac
      [[ "$total" =~ ^[0-9]+$ ]] || continue
      if [ "$mnt" = "/" ]; then label="root"; else n=$((n + 1)); label="fs-$n"; fi
      echo "    $label: {type: $typ, size_gib: $(div "$total" 1073741824), used_gib: $(div "$used" 1073741824), used_percent: ${pct%\%}}"
    done <<< "$out"
  fi
}

sec_temperature() {
  local out rc t="" src="" d nm v vals st
  echo "temperature_tctl:"
  out=$(ro sensors 2> /dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    t=$(printf '%s\n' "$out" | sed -nE 's/^Tctl:[[:space:]]*\+?(-?[0-9.]+).*/\1/p' | head -n1)
    [ -n "$t" ] && src="sensors"
  fi
  if [ -z "$t" ]; then
    for d in "$SYS"/class/hwmon/hwmon*; do
      [ -r "$d/name" ] || continue
      read -r nm < "$d/name"
      [ "$nm" = k10temp ] || continue
      [ -r "$d/temp1_input" ] || continue
      read -r v < "$d/temp1_input"
      [[ "$v" =~ ^[0-9]+$ ]] && { t=$(div "$v" 1000); src="sysfs_k10temp"; break; }
    done
  fi
  if [ -z "$t" ]; then
    if [ "$rc" -ne 0 ]; then na "  " "sensors : $(reason_rc sensors "$rc") ; ni capteur k10temp dans sysfs"
    else na "  " "aucune ligne Tctl dans sensors ; ni capteur k10temp dans sysfs"; fi
  else
    echo "  status: MEASURED"
    echo "  source: $src"
    echo "  instantaneous_c: $t   # un seul relevé : ni p50 ni p95"
  fi
  echo "  history_14d:"
  if [ -z "${PROM_TCTL_QUERY:-}" ]; then na "    " "PROM_TCTL_QUERY non fournie : pas d'historique sur $WINDOW_DAYS jours"
  elif vals=$(prom_values "$PROM_TCTL_QUERY") && st=$(printf '%s\n' "$vals" | stats 1); then
    echo "    status: MEASURED"
    echo "    source: prometheus"
    echo "    samples: $(printf '%s' "$st" | awk '{print $1}')"
    emit_stat "    " tctl celsius "$st"
  else na "    " "Prometheus : $PROM_ERR"; fi
}

sec_arc() {
  local c_max c_min c size hits miss param raw
  echo "zfs_arc:"
  c_max=$(arcstat c_max); c_min=$(arcstat c_min); c=$(arcstat c); size=$(arcstat size)
  hits=$(arcstat hits); miss=$(arcstat misses)
  if [ -n "$c_max" ]; then
    echo "  status: MEASURED"
    echo "  source: arcstats"
    echo "  scope: instantaneous"
    echo "  c_max_gib: $(div "$c_max" 1073741824)   # plafond effectif de l'ARC"
    [ -n "$c_min" ] && echo "  c_min_gib: $(div "$c_min" 1073741824)"
    [ -n "$c" ] && echo "  target_gib: $(div "$c" 1073741824)"
    [ -n "$size" ] && echo "  size_gib: $(div "$size" 1073741824)"
    if [ -n "$hits" ] && [ -n "$miss" ] && [ $((hits + miss)) -gt 0 ]; then
      echo "  hit_ratio_percent: $(awk -v h="$hits" -v m="$miss" 'BEGIN{printf "%.1f", 100 * h / (h + m)}')"
    fi
    if [ -r "$SYS/module/zfs/parameters/zfs_arc_max" ]; then
      read -r param < "$SYS/module/zfs/parameters/zfs_arc_max"
      [[ "$param" =~ ^[0-9]+$ ]] && echo "  zfs_arc_max_param_bytes: $param   # 0 = défaut du module"
    fi
    return
  fi
  raw=$(ro arc_summary 2> /dev/null)
  local rc=$?
  if [ "$rc" -ne 0 ]; then na "  " "arcstats illisible ; arc_summary : $(reason_rc arc_summary "$rc")"; return; fi
  raw=$(printf '%s\n' "$raw" | grep -E 'Max size|Target size|ARC size' | head -n 4 | sed -E 's/^[[:space:]]+//; s/"/'"'"'/g')
  if [ -z "$raw" ]; then na "  " "arcstats illisible ; arc_summary sans ligne exploitable"; return; fi
  echo "  status: MEASURED"
  echo "  source: arc_summary"
  echo "  scope: instantaneous"
  echo "  raw_lines:"
  printf '%s\n' "$raw" | sed 's/^/    - "/; s/$/"/'
}

sec_ram() {
  local mt ma mf sw sf size c_min shrink est alloc i
  echo "ram_reclaimable:"
  mt=$(meminfo_kb MemTotal); ma=$(meminfo_kb MemAvailable); mf=$(meminfo_kb MemFree)
  sw=$(meminfo_kb SwapTotal); sf=$(meminfo_kb SwapFree)
  if [ -z "$mt" ] || [ -z "$ma" ]; then na "  " "/proc/meminfo illisible"; return; fi
  echo "  status: MEASURED"
  echo "  scope: instantaneous   # relever avant et après tout arrêt de service (--label avant|apres)"
  echo "  label: $LABEL"
  echo "  host_mem_total_gib: $(div "$mt" 1048576)"
  echo "  host_mem_available_gib: $(div "$ma" 1048576)"
  [ -n "$mf" ] && echo "  host_mem_free_gib: $(div "$mf" 1048576)"
  [ -n "$sw" ] && [ -n "$sf" ] && echo "  host_swap_used_mib: $(div $((sw - sf)) 1024)"
  size=$(arcstat size); c_min=$(arcstat c_min)
  est="$ma"
  if [ -n "$size" ] && [ -n "$c_min" ]; then
    shrink=$(awk -v s="$size" -v m="$c_min" 'BEGIN{ d = (s - m) / 1024; if (d < 0) d = 0; printf "%.0f", d }')
    echo "  arc_shrinkable_gib: $(div "$shrink" 1048576)   # size - c_min"
    est=$((ma + shrink))
  else
    echo "  arc_shrinkable_gib: NOT_AVAILABLE   # arcstats illisible"
  fi
  echo "  reclaimable_estimate_gib: $(div "$est" 1048576)   # MemAvailable + (ARC size - c_min) ; estimation, pas une garantie"
  if [ -z "$VM_REASON" ]; then
    alloc=0
    for i in "${!VM_ID[@]}"; do [ "${VM_STATE[$i]}" = running ] && alloc=$((alloc + ${VM_MEM[$i]:-0})); done
    echo "  vm_memory_allocated_running_gib: $(div "$alloc" 1024)"
    echo "  vm_memory_allocated_percent_of_host: $(awk -v a="$alloc" -v t="$mt" 'BEGIN{printf "%.1f", a * 1024 * 100 / t}')"
  fi
}

# ---------------------------------------------------------------------------------------------------------------
# Anonymisation de secours : la sortie ne contient déjà aucune valeur identifiante ; cette passe garantit qu'aucun
# motif d'IP, de MAC, d'UUID ni aucun nom réellement lu (hôte, VM) ne passe, même par erreur.
# ---------------------------------------------------------------------------------------------------------------
esc_sed() { printf '%s' "$1" | sed 's/[][\.*^$/|&-]/\\&/g'; }
sanitize() {
  local -a args=()
  local n i lbl
  args+=(-E
    -e 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/<ip-redacted>/g'
    -e 's/([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}/<ip-redacted>/g'
    -e 's/[0-9A-Fa-f:]*::[0-9A-Fa-f:]*/<ip-redacted>/g'
    -e 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/<mac-redacted>/g'
    -e 's/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/<uuid-redacted>/g')
  for i in "${!VM_NAME[@]}"; do
    n="${VM_NAME[$i]}"; [ ${#n} -ge 3 ] || continue
    lbl="vm-other"; [ "$i" = "$KO_IDX" ] && lbl="vm-kube-ops"; [ "$i" = "$LAB_IDX" ] && lbl="vm-lab"
    args+=(-e "s/$(esc_sed "$n")/$lbl/g")
  done
  if [ ${#NODE_NAME} -ge 3 ]; then args+=(-e "s/$(esc_sed "$NODE_NAME")/<host-redacted>/g"); fi
  sed "${args[@]}"
}

# ---------------------------------------------------------------------------------------------------------------
# Programme principal
# ---------------------------------------------------------------------------------------------------------------
discover_vms
identify_vms

report=$(
  {
    echo "schema: $SCHEMA"
    echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "label: $LABEL"
    echo "window_days: $WINDOW_DAYS"
    echo "anonymization: \"aucune IP, aucun nom d'hôte, aucun UUID ni nom de VM ; VM désignées vm-kube-ops et vm-lab\""
    echo "prometheus_configured: $([ -n "${PROM_URL:-}" ] && echo true || echo false)"
    echo "tools_present:"
    for t in qm pvesh pvesm zpool sensors sar arc_summary curl; do
      echo "  $t: $(command -v "$t" > /dev/null 2>&1 && echo true || echo false)"
    done
    echo "measures:"
    for s in $ALL_SECTIONS; do
      want "$s" || continue
      progress "section $s"
      "sec_${s//-/_}" | sed 's/^/  /'
    done
  }
)
report=$(printf '%s\n' "$report" | sanitize)

if [ -n "$OUT_FILE" ]; then
  if (
    set -C
    printf '%s\n' "$report" > "$OUT_FILE"
  ) 2> /dev/null; then progress "écrit : $OUT_FILE"; else
    echo "impossible de créer $OUT_FILE (existe déjà ou dossier non inscriptible) ; rien écrasé" >&2
    exit 1
  fi
else
  printf '%s\n' "$report"
fi
exit 0
