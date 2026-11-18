#!/usr/bin/env bash
# Concordance tools/dev/toolchain.lock = .devcontainer/Dockerfile = ci.yaml (versions et sha256), sans réseau.
#  - chaque clé du lock figure dans le Dockerfile avec la même valeur ;
#  - chaque ARG *_VERSION / *_SHA256 du Dockerfile figure dans le lock ;
#  - chaque clé du lock qui figure aussi dans l'env de ci.yaml a la même valeur ;
#  - SL-2 (T-454) : chaque clé <OUTIL>_AMD64_SHA256 est une empreinte valide, a sa <OUTIL>_VERSION dans le lock et est
#    lue par tools/dev/cloud-setup.sh ; les outils propres à la VM cloud (RUFF_*, PRECOMMIT_*) sont absents du Dockerfile
#    par conception, RUFF_VERSION = ruff== de ci.yaml ; doctor couvre les mêmes outils ;
#  - les paquets pip (yamllint, PyYAML, jsonschema) sont identiques dans le Dockerfile, ci.yaml (yamllint, PyYAML)
#    et tools/appgen/requirements.txt (PyYAML, jsonschema) ; ruff et pre-commit (wheels) = versions du lock ;
#  - T-470, deux architectures : le Dockerfile déclare ARG TARGETARCH, n'écrit aucune archive ni URL d'une architecture
#    en dur, porte l'ARG <OUTIL>_AMD64_SHA256 (= lock) de chaque outil qui en a une, et s'arrête avec « BLOCKED » pour
#    chaque outil sans empreinte amd64 au lock (rien n'est inventé). Verdicts séparés : arm64 PASS|FAIL, amd64
#    PASS|BLOCKED|FAIL. Un amd64 BLOCKED ne fait pas échouer le script (code 0, dit en clair) sauf STRICT_AMD64=1.
# Usage : tests/dev-factory/lock-concordance.sh      (LOCK, DF, CI, REQ surchargeables : sert aux cas négatifs ;
#         STRICT_AMD64=1 : un amd64 BLOCKED devient FAIL)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
LOCK="${LOCK:-tools/dev/toolchain.lock}"
DF="${DF:-.devcontainer/Dockerfile}"
# CI vaut « true » sur GitHub Actions : ce n'est une surcharge (cas négatifs) que si la valeur désigne un fichier.
[[ -f "${CI:-}" ]] || CI=".github/workflows/ci.yaml"
REQ="${REQ:-tools/appgen/requirements.txt}"
SETUP="${SETUP:-tools/dev/cloud-setup.sh}"
DOCTOR="${DOCTOR:-tools/dev/doctor}"
fails=0
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

declare -A lock=()
while IFS='=' read -r k v; do
  [[ -z "$k" || "$k" == \#* ]] && continue
  [[ "$k" =~ ^[A-Z0-9_]+$ && -n "$v" ]] || { ko "ligne invalide dans $LOCK : $k"; continue; }
  [[ -z "${lock[$k]:-}" ]] || ko "clé en double dans $LOCK : $k"
  lock[$k]="$v"
done <"$LOCK"
[[ "${#lock[@]}" -gt 0 ]] || { echo "FAIL lock vide ou illisible : $LOCK"; exit 1; }

pip_name() { case "$1" in YAMLLINT) echo yamllint ;; PYYAML) echo PyYAML ;; JSONSCHEMA) echo jsonschema ;; *) return 1 ;; esac; }

# Clés propres à la VM cloud (linux-amd64) : hors Dockerfile (arm64), contrôlées par les règles SL-2 ci-dessous.
cloud_only() { [[ "$1" == *_AMD64_SHA256 || "$1" == RUFF_* || "$1" == PRECOMMIT_* ]]; }

for k in "${!lock[@]}"; do
  v="${lock[$k]}"
  if cloud_only "$k"; then
    grep -Fq "$k" "$SETUP" || ko "$k : clé non lue par $SETUP"
    if [[ "$k" == *_AMD64_SHA256 ]]; then
      # Outil aussi présent dans le Dockerfile (il a une empreinte arm64 au lock) : même empreinte amd64 dans l'image.
      if [[ -n "${lock[${k%_AMD64_SHA256}_SHA256]:-}" ]]; then
        grep -Eq "^ARG ${k}=${v}\$" "$DF" || ko "$k : valeur du lock absente du Dockerfile (ARG $k=...)"
      fi
      [[ "$v" =~ ^[0-9a-f]{64}$ ]] || ko "$k : empreinte invalide"
      tool="${k%_AMD64_SHA256}"
      [[ -n "${lock[${tool}_VERSION]:-}" ]] || ko "$k : ${tool}_VERSION absente du lock"
      [[ "$v" != "${lock[${tool}_SHA256]:-}" ]] || ko "$k : identique à l'empreinte arm64 (${tool}_SHA256)"
    fi
    if [[ "$k" == RUFF_VERSION ]]; then
      grep -Fq "\"ruff==$v\"" "$CI" || ko "$k : 'ruff==$v' absent de ci.yaml"
    fi
    continue
  fi
  if [[ "$k" == *_SHA256 && ! "$v" =~ ^[0-9a-f]{64}$ ]]; then ko "$k : empreinte invalide"; fi
  base="${k%_VERSION}"
  if [[ "$k" == *_VERSION ]] && p="$(pip_name "$base")"; then
    grep -Fq "\"$p==$v\"" "$DF" || ko "$k : '$p==$v' absent du Dockerfile"
    case "$p" in
      yamllint | PyYAML) grep -Fq "\"$p==$v\"" "$CI" || ko "$k : '$p==$v' absent de ci.yaml" ;;
    esac
    case "$p" in
      PyYAML | jsonschema) grep -Fxq "$p==$v" "$REQ" || ko "$k : '$p==$v' absent de $REQ" ;;
    esac
    continue
  fi
  grep -Eq "^ARG ${k}=${v}\$" "$DF" || ko "$k : valeur du lock absente du Dockerfile (ARG $k=...)"
  if grep -Eq "^[[:space:]]+${k}:" "$CI"; then
    cv="$(sed -n "s/^[[:space:]]*${k}:[[:space:]]*\"\\{0,1\\}\\([^\"# ]*\\)\"\\{0,1\\}.*/\\1/p" "$CI" | head -n1)"
    [[ "$cv" == "$v" ]] || ko "$k : lock=$v mais ci.yaml=$cv"
  fi
done

while IFS= read -r k; do
  [[ -n "${lock[$k]:-}" ]] || ko "$k : ARG du Dockerfile absent du lock"
done < <(sed -n 's/^ARG \([A-Z0-9_]*_\(VERSION\|SHA256\)\)=.*/\1/p' "$DF")

# T-470 : le Dockerfile sert amd64 et arm64 (TARGETARCH), sans rien en dur.
arm_fail0="$fails"
grep -Eq '^ARG TARGETARCH$' "$DF" || ko "Dockerfile : ARG TARGETARCH absent"
if grep -Ev '^[[:space:]]*#' "$DF" | grep -Eq 'linux[-_/.](arm64|amd64|aarch64|x86_64|x64)|--platform'; then
  ko "Dockerfile : archive, URL ou plateforme d'une architecture écrite en dur (utiliser TARGETARCH)"
fi
for p in ruff:RUFF_VERSION pre-commit:PRECOMMIT_VERSION; do
  pv="${lock[${p#*:}]:-}"
  [[ -n "$pv" ]] || { ko "${p#*:} absente du lock"; continue; }
  grep -Fq "\"${p%%:*}==$pv\"" "$DF" || ko "${p#*:} : '${p%%:*}==$pv' absent du Dockerfile"
done
# Par outil du Dockerfile : branche arm64 sur <OUTIL>_SHA256 ; branche amd64 sur <OUTIL>_AMD64_SHA256 ou BLOCKED.
blocked=()
amd_fail0="$fails"
for k in "${!lock[@]}"; do
  [[ "$k" == *_SHA256 ]] || continue
  ! cloud_only "$k" || continue
  t="${k%_SHA256}"
  grep -Fq "arm64) sha=\"\${${t}_SHA256}\"" "$DF" || ko "$t : branche arm64 sur \${${t}_SHA256} absente du Dockerfile"
  if [[ -n "${lock[${t}_AMD64_SHA256]:-}" ]]; then
    grep -Fq "amd64) sha=\"\${${t}_AMD64_SHA256}\"" "$DF" || ko "$t : branche amd64 sur \${${t}_AMD64_SHA256} absente du Dockerfile"
  else
    grep -Fq "amd64) echo \"BLOCKED: ${t}_AMD64_SHA256" "$DF" || ko "$t : pas d'empreinte amd64 au lock et pas d'arrêt BLOCKED dans le Dockerfile"
    blocked+=("$t")
  fi
done
arm_status=PASS
amd_status=PASS
[[ "$fails" -eq "$arm_fail0" ]] || arm_status=FAIL
[[ "$fails" -eq "$amd_fail0" ]] || amd_status=FAIL

# Chaque outil requis de doctor a sa version épinglée dans le lock et son installation dans cloud-setup.sh.
for t in helm kubeconform actionlint gitleaks shellcheck ruff yq pre-commit; do
  grep -Eq "(^|[^a-z-])${t}\)" "$DOCTOR" || ko "$t : absent de $DOCTOR"
  grep -Eq "^    ${t}\)" "$SETUP" || ko "$t : installation absente de $SETUP"
done

if [[ "$fails" -gt 0 ]]; then
  printf 'TOOLCHAIN-LOCK: FAIL (%s)\n' "$fails"
  exit 1
fi
if [[ "${#blocked[@]}" -gt 0 ]]; then
  IFS=' ' read -r -a sorted <<<"$(printf '%s\n' "${blocked[@]}" | sort | tr '\n' ' ')"
  printf 'arm64 : PASS\namd64 : BLOCKED (empreinte amd64 absente du lock : %s) ; les autres outils amd64 : PASS\n' "${sorted[*]}"
  if [[ "${STRICT_AMD64:-0}" == 1 ]]; then
    printf 'TOOLCHAIN-LOCK: FAIL (STRICT_AMD64=1, amd64 BLOCKED)\n'
    exit 1
  fi
  printf 'TOOLCHAIN-LOCK: PASS (%s clés : lock = Dockerfile = ci.yaml ; arm64 PASS ; amd64 BLOCKED : %s)\n' "${#lock[@]}" "${sorted[*]}"
  exit 0
fi
printf 'arm64 : %s\namd64 : %s\n' "$arm_status" "$amd_status"
printf 'TOOLCHAIN-LOCK: PASS (%s clés : lock = Dockerfile = ci.yaml ; arm64 et amd64 PASS)\n' "${#lock[@]}"
