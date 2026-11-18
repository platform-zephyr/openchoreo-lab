#!/usr/bin/env bash
# Concordance tools/dev/toolchain.lock = .devcontainer/Dockerfile = ci.yaml (versions et sha256), sans réseau.
#  - chaque clé du lock figure dans le Dockerfile avec la même valeur ;
#  - chaque ARG *_VERSION / *_SHA256 du Dockerfile figure dans le lock ;
#  - chaque clé du lock qui figure aussi dans l'env de ci.yaml a la même valeur ;
#  - les paquets pip (yamllint, PyYAML, jsonschema) sont identiques dans le Dockerfile, ci.yaml (yamllint, PyYAML)
#    et tools/appgen/requirements.txt (PyYAML, jsonschema).
# Usage : tests/dev-factory/lock-concordance.sh      (LOCK, DF, CI, REQ surchargeables : sert aux cas négatifs)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
LOCK="${LOCK:-tools/dev/toolchain.lock}"
DF="${DF:-.devcontainer/Dockerfile}"
CI="${CI:-.github/workflows/ci.yaml}"
REQ="${REQ:-tools/appgen/requirements.txt}"
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

for k in "${!lock[@]}"; do
  v="${lock[$k]}"
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

if [[ "$fails" -gt 0 ]]; then
  printf 'TOOLCHAIN-LOCK: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'TOOLCHAIN-LOCK: PASS (%s clés : lock = Dockerfile = ci.yaml)\n' "${#lock[@]}"
