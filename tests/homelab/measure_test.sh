#!/usr/bin/env bash
# Test de tools/homelab/measure.sh (T-360) : commandes simulées (PATH factice), sans hôte Proxmox, sans réseau.
# Vérifie : forme du YAML, anonymisation (IP, hôte, noms de VM, MAC, UUID, URL Prometheus, numéros de série),
# lecture seule (aucune commande d'écriture appelée, aucune commande hors liste, aucun fichier créé), dégradation
# en NOT_AVAILABLE. Les valeurs factices sont documentaires (RFC 5737, example.com).
# shellcheck disable=SC2016,SC2034  # les tests sont des chaînes évaluées par `check` (eval) ; variables lues par eval
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/tools/homelab/measure.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; FAILS=$((FAILS + 1)); }
check() { # description, commande de test (eval)
  if eval "$2"; then pass "$1"; else fail "$1"; fi
}

BIN="$WORK/bin"; BASIC="$WORK/basic"; FIX="$WORK/fix"; CALLS="$WORK/calls.log"; RUN="$WORK/run"
mkdir -p "$BIN" "$BASIC" "$FIX/proc/spl/kstat/zfs" "$FIX/proc/sys/kernel" "$FIX/proc/4242" \
  "$FIX/sys/module/zfs/parameters" "$FIX/qemu" "$FIX/sysstat" "$RUN"
: > "$CALLS"

HOST="pve-secret-host"
echo "$HOST" > "$FIX/proc/sys/kernel/hostname"
printf 'processor\t: 0\nprocessor\t: 1\nprocessor\t: 2\nprocessor\t: 3\n' > "$FIX/proc/cpuinfo"
echo "0.20 0.30 0.40 1/100 123" > "$FIX/proc/loadavg"
printf 'MemTotal:       65536000 kB\nMemFree:         8000000 kB\nMemAvailable:   20000000 kB\nSwapTotal:       8000000 kB\nSwapFree:        7999000 kB\n' > "$FIX/proc/meminfo"
printf 'name type data\nhits 4 900\nmisses 4 100\nsize 4 8589934592\nc 4 10737418240\nc_min 4 1073741824\nc_max 4 17179869184\n' > "$FIX/proc/spl/kstat/zfs/arcstats"
echo 0 > "$FIX/sys/module/zfs/parameters/zfs_arc_max"
echo 4242 > "$FIX/qemu/101.pid"
printf 'Name:\tqemu\nVmRSS:\t 25165824 kB\n' > "$FIX/proc/4242/status"

# --- commandes simulées : chaque appel est journalisé ---
mkstub() { printf '#!/usr/bin/env bash\necho "$(basename "$0") $*" >> "%s"\n%s\n' "$CALLS" "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }

mkstub qm 'case "$1" in
  list) printf "      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID\n       101 kube-ops-prod        running    24576             200.00 4242\n       102 lab-vm               running    16384             100.00 4343\n       103 dns-box              running     1024              10.00 4444\n" ;;
  config) printf "cores: 6\nsockets: 1\nmemory: 24576\nballoon: 0\nnet0: virtio=BC:24:11:AA:BB:CC,bridge=vmbr0,ip=192.0.2.60\nsmbios1: uuid=123e4567-e89b-12d3-a456-426614174000\nscsi0: tank:vm-101-disk-0,size=200G,serial=SERIAL12345\n" ;;
  *) echo "WRITE-LIKE qm $*" >> "'"$CALLS"'"; exit 99 ;;
esac'
mkstub pvesh 'if [ "$1" != get ]; then exit 99; fi
cf=AVERAGE; for a in "$@"; do prev="${cur:-}"; cur="$a"; [ "$prev" = "--cf" ] && cf="$a"; done
now=$(date -u +%s)
awk -v now="$now" -v cf="$cf" "BEGIN { printf \"[\"; for (i = 0; i < 200; i++) { t = now - i * 7200; c = (i % 100) / 200; m = 8000000000 + i * 10000000; if (cf == \"MAX\") { c = c + 0.1; m = m + 500000000 }; printf \"%s{\\\"time\\\":%d,\\\"cpu\\\":%.4f,\\\"maxcpu\\\":6,\\\"mem\\\":%d,\\\"maxmem\\\":25769803776}\", (i ? \",\" : \"\"), t, c, m }; printf \"]\" }"'
mkstub pvesm 'printf "Name   Type  Status  Total  Used  Available  %%\nlocal-secret dir active 100000000 40000000 60000000 40.00%%\ntank zfspool active 900000000 450000000 450000000 50.00%%\n"'
mkstub zpool 'case "$1" in
  list) printf "tank\t1000204886016\t500102443008\t500102443008\t-\t-\t12\t50\t1.00x\tONLINE\t-\nhddmirror\t4000787030016\t2000393515008\t2000393515008\t-\t-\t3\t50\t1.00x\tONLINE\t-\n" ;;
  status) case "$*" in *hddmirror*) printf "  pool: hddmirror\n  config:\n\tNAME\n\t  mirror-0\n\t    /dev/disk/by-id/ata-WDC_SERIALHDD1\n\t    /dev/disk/by-id/ata-WDC_SERIALHDD2\n" ;; *) printf "  pool: tank\n  config:\n\tNAME\n\t  /dev/disk/by-id/nvme-Samsung_SERIALNVME1\n" ;; esac ;;
  *) exit 99 ;;
esac'
mkstub sensors 'printf "k10temp-pci-00c3\nAdapter: PCI adapter\nTctl:         +51.5°C\n"'
mkstub df 'printf "Filesystem Type 1-blocks Used Available Capacity Mounted on\n/dev/mapper/pve-root ext4 100000000000 20000000000 80000000000 20%% /\ntank zfs 900000000000 1 1 1%% /tank\ntmpfs tmpfs 1000 0 1000 0%% /run\n"'
# curl : la valeur RAM se distingue par la requête ; on la simule en lisant la requête
cat > "$BIN/curl" << 'EOF'
#!/usr/bin/env bash
echo "$*" >> "$MEASURE_TEST_CURL_LOG"
echo "curl $*" >> "$MEASURE_TEST_CALLS"
case "$*" in *tctl*) kind=tctl ;; *memory*) kind=ram ;; *) kind=cpu ;; esac
awk -v kind="$kind" 'BEGIN {
  printf "{\"status\":\"success\",\"data\":{\"resultType\":\"matrix\",\"result\":[{\"metric\":{},\"values\":["
  for (i = 1; i <= 100; i++) {
    if (kind == "tctl") v = 40 + i / 5; else if (kind == "ram") v = 8000000000 + i * 10000000; else v = i / 200
    printf "%s[%d,\"%s\"]", (i > 1 ? "," : ""), 1700000000 + i * 300, v
  }
  printf "]}]}}"
}'
EOF
chmod +x "$BIN/curl"
mkstub sar 'echo "Linux 6.8 (pve-secret-host)  11/17/2026"; echo "00:00:01 CPU %user %nice %system %iowait %steal %idle"; echo "00:10:01 all 10.0 0 5.0 0 0 85.0"; echo "00:20:01 all 20.0 0 5.0 0 0 75.0"'

# pièges : toute commande d'écriture ou de réseau hors liste est journalisée « WRITE » et échoue
for w in sudo rm mv cp tee dd mkdir touch chmod chown systemctl service apt apt-get kill reboot shutdown zfs mount umount ssh scp wget nc ping hostname; do
  printf '#!/usr/bin/env bash\necho "WRITE: %s $*" >> "%s"\nexit 99\n' "$w" "$CALLS" > "$BIN/$w"; chmod +x "$BIN/$w"
done

# outils de base (filtres) pour le scénario « aucun outil Proxmox » : liens vers les vrais binaires
for t in awk sed grep sort head tr cut date cat wc find bash env basename dirname; do
  p="$(command -v "$t")"; [ -n "$p" ] && ln -s "$p" "$BASIC/$t"
done
# la copie pour le scénario complet : filtres + simulacres (les pièges et simulacres passent devant)
FULLPATH="$BIN:$BASIC"

export MEASURE_PROC="$FIX/proc" MEASURE_SYS="$FIX/sys" MEASURE_QEMU_RUN="$FIX/qemu" MEASURE_SA_DIR="$FIX/nosysstat"
export MEASURE_TEST_CURL_LOG="$WORK/curl-args.log" MEASURE_TEST_CALLS="$CALLS"
: > "$MEASURE_TEST_CURL_LOG"

CWD="$WORK/cwd"; mkdir -p "$CWD"

run() { # PATH, sortie, erreur, args...
  local p="$1" o="$2" e="$3"; shift 3
  (cd "$CWD" && env -i PATH="$p" HOME="$WORK" MEASURE_PROC="$MEASURE_PROC" MEASURE_SYS="$MEASURE_SYS" MEASURE_QEMU_RUN="$MEASURE_QEMU_RUN" \
    MEASURE_SA_DIR="$MEASURE_SA_DIR" MEASURE_TEST_CURL_LOG="$MEASURE_TEST_CURL_LOG" MEASURE_TEST_CALLS="$MEASURE_TEST_CALLS" \
    ${PROM_URL:+PROM_URL="$PROM_URL"} ${PROM_TCTL_QUERY:+PROM_TCTL_QUERY="$PROM_TCTL_QUERY"} \
    "$BASH" "$SCRIPT" "$@" > "$o" 2> "$e")
}

# ---------- 1. scénario complet sans Prometheus (pvesh) ----------
OUT1="$WORK/out1.yaml"
run "$FULLPATH" "$OUT1" "$WORK/err1.log"
rc=$?
check "rc 0" '[ "$rc" -eq 0 ]'
check "schéma et sections présents" 'for k in "schema: homelab-mesures.v1" "  host:" "  vms:" "  usage_14d:" "  storage:" "  temperature_tctl:" "  zfs_arc:" "  ram_reclaimable:"; do grep -qF "$k" "$OUT1" || { echo "manque: $k"; false; break; }; done'
check "YAML valide" 'python3 -c "import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); assert d[\"schema\"] == \"homelab-mesures.v1\"; assert \"measures\" in d" "$OUT1"'
check "étiquettes vm-kube-ops et vm-lab" 'python3 -c "import sys, yaml; m = yaml.safe_load(open(sys.argv[1]))[\"measures\"]; assert m[\"vms\"][\"vm-kube-ops\"][\"identified\"] is True; assert m[\"vms\"][\"vm-lab\"][\"identified\"] is True; assert m[\"vms\"][\"vm-kube-ops\"][\"configured\"][\"vcpus\"] == 6" "$OUT1"'
check "usage via pvesh : p50 <= p95 <= peak" 'python3 -c "
import sys, yaml
u = yaml.safe_load(open(sys.argv[1]))[\"measures\"][\"usage_14d\"][\"vm-kube-ops\"]
assert u[\"status\"] == \"MEASURED\" and u[\"source\"] == \"pvesh_rrd\", u
for k in (\"cpu_ratio\", \"ram_gib\"):
    s = u[k]; assert s[\"p50\"] <= s[\"p95\"] <= s[\"peak\"], (k, s)
assert u[\"samples\"] >= 100
" "$OUT1"'
check "ARC c_max = 16 GiB" 'grep -q "c_max_gib: 16.00" "$OUT1"'
check "Tctl 51.5" 'grep -q "instantaneous_c: 51.5" "$OUT1"'
check "pools : NVMe et miroir détectés" 'grep -q "media_guess: nvme" "$OUT1" && grep -q "layout: mirror" "$OUT1" && grep -q "media_guess: non-nvme" "$OUT1"'
check "RAM libérable = disponible + ARC réductible (20e6 kB + 7 GiB = 26.05 GiB)" 'grep -q "reclaimable_estimate_gib: 26.0[0-9]" "$OUT1"'
check "historique Tctl sans PROM : NOT_AVAILABLE avec raison" 'grep -A2 "history_14d" "$OUT1" | grep -q "NOT_AVAILABLE"'

# ---------- 2. anonymisation ----------
leak=""
for pat in "$HOST" "kube-ops-prod" "lab-vm" "dns-box" "SERIAL" "BC:24:11" "123e4567" "192\.0\.2" "vmbr0" "local-secret" "tank" "hddmirror"; do
  grep -q -- "$pat" "$OUT1" "$WORK/err1.log" && leak="$leak $pat"
done
check "aucune fuite (hôte, noms de VM, pools, série, MAC, UUID, IP) :$leak" '[ -z "$leak" ]'
check "aucune IPv4 dans la sortie" '! grep -qE "[0-9]{1,3}(\.[0-9]{1,3}){3}" "$OUT1"'

# ---------- 3. lecture seule ----------
check "aucun piège d'écriture appelé" '! grep -q "^WRITE" "$CALLS"'
check "aucune commande refusée par la garde" '! grep -q REFUSED "$WORK/err1.log"'
allowed='^(qm (list|config [0-9]+)|pvesh get /nodes/[^ ]+/qemu/[0-9]+/rrddata .*|pvesm status|zpool (list -H -p|status -P [^ ]+)|sensors ?|df -P -T -B1)$'
bad=$(grep -vE "$allowed" "$CALLS" | grep -v '^curl ' || true)
check "toutes les commandes journalisées sont dans la liste de lecture seule" '[ -z "$bad" ]'
check "aucun fichier créé dans le dossier courant" '[ -z "$(ls -A "$CWD")" ]'
code=$(grep -vE '^[[:space:]]*#' "$SCRIPT")
for pat in '\bsudo\b' '\brm\b' '\bmv\b' '\btee\b' '\bdd\b' '>>' 'mktemp' 'qm (set|start|stop|create|destroy|migrate|shutdown|reset|resume|suspend|snapshot|rollback)' \
  'zpool (scrub|clear|import|export|destroy|create|add|remove|set|offline|online|replace|attach|detach|trim|upgrade)' 'zfs (set|destroy|create|snapshot|rollback)' 'pvesh (set|create|delete)' 'systemctl' 'curl.*(-X|--request|--data |-d )'; do
  if printf '%s\n' "$code" | grep -qE -- "$pat"; then fail "script : motif d'écriture interdit présent : $pat"; else pass "script : absence de $pat"; fi
done
# la garde refuse bel et bien une sous-commande d'écriture (appel direct de ro)
guard=$(cd "$CWD" && env -i PATH="$FULLPATH" bash -c 'source <(sed -n "/^refuse()/,/^reason_rc()/p" "$0" | sed "$d"); ro qm set 101 --memory 1; echo "rc=$?"' "$SCRIPT" 2>&1)
check "la garde refuse « qm set » (rc 126)" 'printf "%s" "$guard" | grep -q "rc=126" && ! grep -q "WRITE-LIKE" "$CALLS"'

# ---------- 4. avec Prometheus (GET seulement, URL jamais écrite) ----------
OUT4="$WORK/out4.yaml"; : > "$MEASURE_TEST_CURL_LOG"
PROM_URL="http://prom.example.com:9090" PROM_TCTL_QUERY='node_hwmon_temp_celsius{chip="tctl"}' run "$FULLPATH" "$OUT4" "$WORK/err4.log"
check "usage via Prometheus" 'python3 -c "
import sys, yaml
m = yaml.safe_load(open(sys.argv[1]))[\"measures\"]
u = m[\"usage_14d\"][\"vm-kube-ops\"]
assert u[\"source\"] == \"prometheus\", u
assert u[\"samples\"] == 100 and u[\"ram_gib\"][\"p95\"] > u[\"ram_gib\"][\"p50\"]
assert m[\"temperature_tctl\"][\"history_14d\"][\"status\"] == \"MEASURED\"
" "$OUT4"'
check "curl : toujours -G, jamais -X ni données POST" '[ -s "$MEASURE_TEST_CURL_LOG" ] && ! grep -qE -- "(^| )(-X|-d|--data|-T|-F|-o)( |$)" "$MEASURE_TEST_CURL_LOG" && ! grep -qv -- "-G" "$MEASURE_TEST_CURL_LOG"'
check "l'URL Prometheus n'apparaît pas dans la sortie" '! grep -q "prom.example.com" "$OUT4" "$WORK/err4.log"'
check "aucun piège d'écriture (Prometheus)" '! grep -q "^WRITE" "$CALLS"'

# ---------- 5. repli sar quand ni Prometheus ni pvesh ----------
SARBIN="$WORK/sarbin"; mkdir -p "$SARBIN" "$FIX/sysstat"
ln -s "$BIN/sar" "$SARBIN/sar"; ln -s "$BIN/qm" "$SARBIN/qm"
touch "$FIX/sysstat/sa17"
OUT5="$WORK/out5.yaml"
MEASURE_SA_DIR="$FIX/sysstat" run "$SARBIN:$BASIC" "$OUT5" "$WORK/err5.log"
check "repli sar : scope host, CPU 15-25 %" 'grep -q "scope: host" "$OUT5" && grep -q "cpu_busy_percent: {unit: percent, p50: 15.0000" "$OUT5"'

# ---------- 6. dégradation : aucun outil, aucun /proc ----------
OUT6="$WORK/out6.yaml"
MEASURE_PROC="$WORK/absent" MEASURE_SYS="$WORK/absent" MEASURE_QEMU_RUN="$WORK/absent" run "$BASIC" "$OUT6" "$WORK/err6.log"
rc=$?
check "rc 0 sans aucun outil" '[ "$rc" -eq 0 ]'
check "YAML valide et NOT_AVAILABLE partout avec une raison" 'python3 -c "
import sys, yaml
m = yaml.safe_load(open(sys.argv[1]))[\"measures\"]
def walk(d, path=\"\"):
    if isinstance(d, dict):
        if d.get(\"status\") == \"NOT_AVAILABLE\":
            assert d.get(\"reason\"), path
        for k, v in d.items(): walk(v, path + \"/\" + k)
walk(m)
assert m[\"vms\"][\"status\"] == \"NOT_AVAILABLE\" and m[\"zfs_arc\"][\"status\"] == \"NOT_AVAILABLE\"
assert m[\"temperature_tctl\"][\"status\"] == \"NOT_AVAILABLE\" and m[\"host\"][\"status\"] == \"NOT_AVAILABLE\"
" "$OUT6"'

# ---------- 7. --out : un seul fichier, jamais d'écrasement ; --only ----------
OUT7="$CWD/mesures.yaml"
run "$FULLPATH" /dev/null "$WORK/err7.log" --out mesures.yaml; rc=$?
check "--out crée un seul fichier" '[ "$rc" -eq 0 ] && [ "$(ls -A "$CWD")" = "mesures.yaml" ] && grep -q "^schema:" "$OUT7"'
run "$FULLPATH" /dev/null "$WORK/err7b.log" --out mesures.yaml; rc=$?
check "--out refuse d'écraser" '[ "$rc" -eq 1 ]'
rm -f "$OUT7"
OUT8="$WORK/out8.yaml"
run "$FULLPATH" "$OUT8" "$WORK/err8.log" --only ram,arc --label avant
check "--only et --label" 'grep -q "ram_reclaimable" "$OUT8" && grep -q "label: avant" "$OUT8" && ! grep -q "  storage:" "$OUT8"'
run "$FULLPATH" /dev/null "$WORK/err9.log" --only inconnue; rc=$?
check "--only inconnue : rc 2" '[ "$rc" -eq 2 ]'

echo
if [ "$FAILS" -eq 0 ]; then echo "measure_test : PASS"; exit 0; fi
echo "measure_test : FAIL ($FAILS)"; exit 1
