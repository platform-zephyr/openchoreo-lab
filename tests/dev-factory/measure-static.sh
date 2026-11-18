#!/usr/bin/env bash
# Mesure de `tools/dev/check --static` sous 1 vCPU et 1 GiB (T-471, SL-8, ADR-0022).
# Imprime : mode, limites demandées et si elles sont appliquées, durée, code de sortie, pic mémoire, verdict.
# Verdict contre le budget L2 de docs/research/SHIFT-LEFT-DEV-ENV.md §3 : 90 s (cible 60 s), pic < 1 GiB.
#
# Modes (--mode auto|docker|cgroup|partial ; auto prend le premier disponible) :
#   docker   `docker run --cpus=1 --memory=1g --memory-swap=1g` ; exige un démon joignable et MEASURE_IMAGE (image du
#            devcontainer contenant l'outillage du lock). Pic lu dans le cgroup du conteneur.
#   cgroup   cgroup v1 ou v2 créé par le script (root, hiérarchie inscriptible) : cpu 1.0, mémoire 1 GiB, swap total
#            1 GiB. Les limites sont relues après écriture ; une limite non relue = non appliquée.
#   partial  aucune limite appliquée : `taskset -c 0` si disponible, pic = plus gros processus enfant (ru_maxrss).
#            Les valeurs sont imprimées comme « HORS LIMITES » et le verdict reste NOT_TESTED.
# Statuts : PASS seulement si limites appliquées ET code 0 ET verdict de check PASS ET budget tenu. FAIL si limites
# appliquées et (code ≠ 0, mort OOM, dépassement du budget). NOT_TESTED sinon : jamais PASS sans les limites demandées.
# Usage : tests/dev-factory/measure-static.sh [--mode MODE] [--budget-s N] [-- args de check, ex. --changed]
# Code de sortie : 0 PASS, 1 FAIL, 3 NOT_TESTED, 2 usage.
# shellcheck disable=SC2329  # cleanup est appelée par trap
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
ROOT="$PWD"
MODE=auto
BUDGET_S=90
CHECK_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --budget-s)
      BUDGET_S="${2:-}"
      shift 2
      ;;
    --)
      shift
      CHECK_ARGS=("$@")
      break
      ;;
    *)
      echo "usage: $0 [--mode auto|docker|cgroup|partial] [--budget-s N] [-- args de check]" >&2
      exit 2
      ;;
  esac
done
[[ "$MODE" =~ ^(auto|docker|cgroup|partial)$ && "$BUDGET_S" =~ ^[0-9]+$ ]] || {
  echo "usage: argument invalide" >&2
  exit 2
}

MEM_BYTES=$((1024 * 1024 * 1024))
W="$(mktemp -d "${TMPDIR:-/tmp}/measure-static.XXXXXX")"
CG=()
cleanup() {
  local d
  for d in "${CG[@]}"; do rmdir "$d" 2>/dev/null; done
  rm -rf "$W"
}
trap cleanup EXIT
OUT="$W/check.out"
ENFORCED=no
NOTE=""
LIMITS_DESC=""
PEAK_B=""
RC=""
T0=0
T1=0
CHECK_CMD=(env CHECK_RECEIPT="$W/receipt.json" tools/dev/check --static "${CHECK_ARGS[@]}")

now_ms() {
  local t="${EPOCHREALTIME/./}"
  echo $((t / 1000))
}

have_docker() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

# Écrit une limite et la relit ; échec = limite non appliquée.
setlim() { # fichier valeur
  echo "$2" >"$1" 2>/dev/null && [[ "$(tr -d '[:space:]' <"$1" 2>/dev/null)" == "$2" ]]
}

run_cgroup() {
  [[ "$(id -u)" -eq 0 ]] || {
    NOTE="cgroup : root requis"
    return 1
  }
  local base=/sys/fs/cgroup PROCS=() PEAKF=""
  if [[ -f $base/cgroup.controllers ]]; then
    # v2 : sous-groupe du groupe courant ; contrôleurs cpu et memory à activer dans le parent.
    local cur d
    cur="$base$(sed -n 's/^0:://p' /proc/self/cgroup)"
    d="$cur/measure-static.$$"
    echo "+cpu +memory" >"$cur/cgroup.subtree_control" 2>/dev/null
    mkdir "$d" 2>/dev/null || {
      NOTE="cgroup v2 : création refusée"
      return 1
    }
    CG+=("$d")
    if setlim "$d/memory.max" "$MEM_BYTES" && setlim "$d/memory.swap.max" 0 &&
      echo "100000 100000" >"$d/cpu.max" 2>/dev/null && [[ "$(cat "$d/cpu.max")" == "100000 100000" ]]; then
      :
    else
      NOTE="cgroup v2 : limites non relues"
      return 1
    fi
    PROCS=("$d/cgroup.procs")
    PEAKF="$d/memory.peak"
    LIMITS_DESC="cgroup v2 : cpu.max=100000/100000, memory.max=$MEM_BYTES, memory.swap.max=0"
  elif [[ -d $base/memory && -d $base/cpu ]]; then
    local m="$base/memory/measure-static.$$" c="$base/cpu/measure-static.$$" swapdesc
    mkdir "$m" 2>/dev/null && CG+=("$m")
    mkdir "$c" 2>/dev/null && CG+=("$c")
    [[ -d $m && -d $c ]] || {
      NOTE="cgroup v1 : création refusée"
      return 1
    }
    setlim "$m/memory.limit_in_bytes" "$MEM_BYTES" || {
      NOTE="cgroup v1 : memory.limit_in_bytes non relu"
      return 1
    }
    # RAM + swap = 1 GiB via memsw ; sans memsw, le swap n'est limité que s'il n'existe pas.
    if [[ -f $m/memory.memsw.limit_in_bytes ]]; then
      setlim "$m/memory.memsw.limit_in_bytes" "$MEM_BYTES" || {
        NOTE="cgroup v1 : memsw non relu"
        return 1
      }
      swapdesc="memsw=$MEM_BYTES"
    elif [[ "$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)" == 0 ]]; then
      swapdesc="aucun swap sur l'hôte (SwapTotal=0)"
    else
      NOTE="cgroup v1 : swap présent et non limitable (pas de memsw)"
      return 1
    fi
    if ! { setlim "$c/cpu.cfs_period_us" 100000 && setlim "$c/cpu.cfs_quota_us" 100000; }; then
      NOTE="cgroup v1 : quota cpu non relu"
      return 1
    fi
    PROCS=("$m/cgroup.procs" "$c/cgroup.procs")
    PEAKF="$m/memory.max_usage_in_bytes"
    LIMITS_DESC="cgroup v1 : cfs_quota/period=100000/100000, limit_in_bytes=$MEM_BYTES, swap : $swapdesc"
  else
    NOTE="cgroup : hiérarchie inconnue"
    return 1
  fi
  # Le sous-shell entre dans les groupes puis exec : tous ses descendants héritent des limites.
  T0="$(now_ms)"
  (
    for p in "${PROCS[@]}"; do echo $BASHPID >"$p" || exit 125; done
    exec "${CHECK_CMD[@]}"
  ) >"$OUT" 2>&1
  RC=$?
  T1="$(now_ms)"
  PEAK_B="$(cat "$PEAKF" 2>/dev/null)"
  ENFORCED=yes
  return 0
}

run_docker() {
  have_docker || {
    NOTE="docker : démon injoignable"
    return 1
  }
  [[ -n "${MEASURE_IMAGE:-}" ]] || {
    NOTE="docker : MEASURE_IMAGE absente (image du devcontainer, outillage du lock)"
    return 1
  }
  LIMITS_DESC="docker run --cpus=1 --memory=1g --memory-swap=1g"
  # shellcheck disable=SC2016  # le script interne est évalué dans le conteneur
  local inner='tools/dev/check --static "$@"; rc=$?
    for f in /sys/fs/cgroup/memory.peak /sys/fs/cgroup/memory/memory.max_usage_in_bytes; do
      [ -r "$f" ] && { echo "MEASURE_PEAK_B=$(cat "$f")"; break; }
    done
    exit $rc'
  T0="$(now_ms)"
  docker run --rm --cpus=1 --memory=1g --memory-swap=1g -v "$ROOT:/work" -w /work \
    -e CHECK_RECEIPT=/tmp/receipt.json "$MEASURE_IMAGE" bash -c "$inner" check "${CHECK_ARGS[@]}" >"$OUT" 2>&1
  RC=$?
  T1="$(now_ms)"
  PEAK_B="$(sed -n 's/^MEASURE_PEAK_B=//p' "$OUT" | tail -1)"
  ENFORCED=yes
  return 0
}

run_partial() {
  LIMITS_DESC="aucune limite appliquée (taskset -c 0 si disponible)"
  local pre=()
  command -v taskset >/dev/null 2>&1 && pre=(taskset -c 0)
  T0="$(now_ms)"
  python3 -I - "$OUT" "${pre[@]}" "${CHECK_CMD[@]}" >"$W/peak" <<'PY'
import resource, subprocess, sys
out, argv = sys.argv[1], sys.argv[2:]
with open(out, "wb") as f:
    rc = subprocess.call(argv, stdout=f, stderr=subprocess.STDOUT)
# ru_maxrss (Ko sous Linux) : plus gros processus enfant, pas la somme de l'arbre.
print(rc, resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss * 1024)
PY
  read -r RC PEAK_B <"$W/peak"
  T1="$(now_ms)"
  return 0
}

case "$MODE" in
  docker) run_docker ;;
  cgroup) run_cgroup ;;
  partial) run_partial ;;
  auto) run_docker || run_cgroup ;;
esac
if [[ -z "$RC" ]]; then
  # Le mode demandé n'a pas pu s'appliquer : mesure partielle, signalée comme telle (jamais comme limitée).
  REASON="$NOTE"
  LIMITS_DESC=""
  run_partial
  [[ "$MODE" == partial ]] || NOTE="mode $MODE indisponible ($REASON) ; mesure partielle"
fi

DUR_MS=$((T1 - T0))
DUR_S="$((DUR_MS / 1000)).$(printf '%03d' $((DUR_MS % 1000)))"
PEAK_MIB="n/a"
[[ "$PEAK_B" =~ ^[0-9]+$ ]] && PEAK_MIB="$((PEAK_B / 1048576))"
CHECK_VERDICT="$(sed -nE 's/^RESULT: (PASS|INCOMPLET|FAIL).*/\1/p' "$OUT" | tail -1)"
CHECK_VERDICT="${CHECK_VERDICT:-inconnu}"
CHECK_SUMMARY="$(grep -E '^-- PASS=' "$OUT" | tail -1)"

HORS=""
[[ "$ENFORCED" == yes ]] || HORS=" (HORS LIMITES : 1 vCPU / 1 GiB non appliqués)"
echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "sha=$(git rev-parse --short HEAD 2>/dev/null || echo inconnu)"
echo "limites_demandees=1 vCPU, 1 GiB (swap compris)"
echo "limites_appliquees=$ENFORCED ; ${LIMITS_DESC:-aucune}${NOTE:+ ; $NOTE}"
echo "duree_s=$DUR_S$HORS"
echo "code_sortie=$RC"
echo "pic_memoire_mib=$PEAK_MIB$HORS"
echo "verdict_check=$CHECK_VERDICT ${CHECK_SUMMARY:+($CHECK_SUMMARY)}"
grep -E 'NOT_TESTED|^FAIL' "$OUT" | head -20 | sed 's/^/  check : /'
echo "budget=${BUDGET_S} s, pic < 1024 MiB"

if [[ "$ENFORCED" != yes ]]; then
  echo "NOT_TESTED : limites 1 vCPU / 1 GiB non appliquées ; valeurs ci-dessus indicatives, aucun verdict contre le budget"
  exit 3
fi
verdict=PASS
if [[ "$RC" != 0 ]]; then
  verdict=FAIL
  echo "FAIL : code de sortie $RC (137 = mort OOM)"
fi
if ((DUR_MS > BUDGET_S * 1000)); then
  verdict=FAIL
  echo "FAIL : durée > ${BUDGET_S} s"
fi
if [[ "$verdict" == PASS && ! "$PEAK_B" =~ ^[0-9]+$ ]]; then
  verdict=NOT_TESTED
  echo "NOT_TESTED : pic mémoire illisible"
fi
if [[ "$verdict" == PASS && "$CHECK_VERDICT" != PASS ]]; then
  verdict=NOT_TESTED
  echo "NOT_TESTED : verdict de check = $CHECK_VERDICT"
fi
echo "$verdict"
case "$verdict" in PASS) exit 0 ;; FAIL) exit 1 ;; *) exit 3 ;; esac
