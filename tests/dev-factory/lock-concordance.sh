#!/usr/bin/env bash
# Concordance tools/dev/toolchain.lock = .devcontainer/Dockerfile = ci.yaml (versions et sha256), sans réseau.
#  - chaque clé du lock figure dans le Dockerfile avec la même valeur ;
#  - chaque ARG *_VERSION / *_SHA256 du Dockerfile figure dans le lock ;
#  - chaque clé du lock qui figure aussi dans l'env de ci.yaml a la même valeur ;
#  - SL-2 (T-454) : chaque clé <OUTIL>_AMD64_SHA256 est une empreinte valide, a sa <OUTIL>_VERSION dans le lock et est
#    lue par tools/dev/cloud-setup.sh ; les outils propres à la VM cloud (RUFF_*, PRECOMMIT_*) sont absents du Dockerfile
#    par conception, RUFF_VERSION = ruff== de ci.yaml ; doctor couvre les mêmes outils ;
#  - T-470, multi-arch : le Dockerfile déclare ARG TARGETARCH et, pour chaque outil qu'il installe, une paire
#    <OUTIL>_SHA256 (arm64) / <OUTIL>_AMD64_SHA256 (amd64) égale au lock, choisie par TARGETARCH. Un outil installé par
#    le Dockerfile dont le lock n'a pas l'empreinte amd64 est BLOCKED (ARG vide, build amd64 arrêté) : jamais inventée.
#    Verdict par architecture : PASS arm64 ; PASS amd64 seulement si aucune empreinte amd64 ne manque ;
#  - les paquets pip (yamllint, PyYAML, jsonschema) sont identiques dans le Dockerfile, ci.yaml (yamllint, PyYAML)
#    et tools/appgen/requirements.txt (PyYAML, jsonschema).
# Usage : tests/dev-factory/lock-concordance.sh      (LOCK, DF, CI, REQ surchargeables : sert aux cas négatifs)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
LOCK="${LOCK:-tools/dev/toolchain.lock}"
DF="${DF:-.devcontainer/Dockerfile}"
# CI vaut « true » sur GitHub (et dans les VM d'agents) : n'est un chemin surchargé que s'il désigne un fichier ; CI_YAML
# prime (ci-map.tsv notait ce défaut, corrigé ici).
CI="${CI_YAML:-${CI:-}}"
[[ -f "$CI" ]] || CI=".github/workflows/ci.yaml"
REQ="${REQ:-tools/appgen/requirements.txt}"
SETUP="${SETUP:-tools/dev/cloud-setup.sh}"
DOCTOR="${DOCTOR:-tools/dev/doctor}"
fails=0
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
blocked=()

# Outil installé par le Dockerfile (ARG <OUTIL>_VERSION) ?
in_dockerfile() { grep -Eq "^ARG ${1}_VERSION=" "$DF"; }
grep -Fxq 'ARG TARGETARCH' "$DF" || ko "Dockerfile : ARG TARGETARCH absent"
! grep -Eq -- '--platform[= ]linux/arm64' "$DF" .devcontainer/devcontainer.json 2>/dev/null ||
  ko "architecture imposée (--platform=linux/arm64) dans le Dockerfile ou devcontainer.json"

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
      [[ "$v" =~ ^[0-9a-f]{64}$ ]] || ko "$k : empreinte invalide"
      tool="${k%_AMD64_SHA256}"
      [[ -n "${lock[${tool}_VERSION]:-}" ]] || ko "$k : ${tool}_VERSION absente du lock"
      [[ "$v" != "${lock[${tool}_SHA256]:-}" ]] || ko "$k : identique à l'empreinte arm64 (${tool}_SHA256)"
      if in_dockerfile "$tool"; then
        grep -Eq "^ARG ${k}=${v}\$" "$DF" || ko "$k : valeur du lock absente du Dockerfile (ARG $k=...)"
      fi
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
  [[ -n "${lock[$k]:-}" ]] && continue
  # Empreinte amd64 vide et absente du lock : BLOCKED (le Dockerfile ne l'invente pas) ; toute autre valeur est une erreur.
  if [[ "$k" == *_AMD64_SHA256 ]] && grep -Eq "^ARG ${k}=\$" "$DF"; then
    blocked+=("$k")
  else
    ko "$k : ARG du Dockerfile absent du lock"
  fi
done < <(sed -n 's/^ARG \([A-Z0-9_]*_\(VERSION\|SHA256\)\)=.*/\1/p' "$DF")

# Chaque outil du Dockerfile : <OUTIL>_SHA256 et <OUTIL>_AMD64_SHA256 déclarés, RUN choisi par TARGETARCH (amd64 et arm64),
# vérification sha256 avant extraction, refus explicite d'une architecture inconnue ou d'une empreinte vide.
tools_df=()
while IFS= read -r t; do tools_df+=("$t"); done < <(sed -n 's/^ARG \([A-Z0-9]*\)_VERSION=.*/\1/p' "$DF" | grep -Ev '^(PYYAML|YAMLLINT|JSONSCHEMA)$')
for t in "${tools_df[@]}"; do
  grep -Eq "^ARG ${t}_SHA256=[0-9a-f]{64}\$" "$DF" || ko "$t : ARG ${t}_SHA256 (arm64) absent ou invalide dans le Dockerfile"
  grep -Eq "^ARG ${t}_AMD64_SHA256=([0-9a-f]{64})?\$" "$DF" || ko "$t : ARG ${t}_AMD64_SHA256 absent dans le Dockerfile"
  grep -Fq "sha=\"\${${t}_AMD64_SHA256}\"" "$DF" || ko "$t : branche amd64 de TARGETARCH absente"
  grep -Fq "sha=\"\${${t}_SHA256}\"" "$DF" || ko "$t : branche arm64 de TARGETARCH absente"
done
[[ "${#tools_df[@]}" -gt 0 ]] || ko "aucun outil binaire détecté dans le Dockerfile"

# Chaque outil requis de doctor a sa version épinglée dans le lock et son installation dans cloud-setup.sh.
for t in helm kubeconform actionlint gitleaks shellcheck ruff yq pre-commit; do
  grep -Eq "(^|[^a-z-])${t}\)" "$DOCTOR" || ko "$t : absent de $DOCTOR"
  grep -Eq "^    ${t}\)" "$SETUP" || ko "$t : installation absente de $SETUP"
done

if [[ "$fails" -gt 0 ]]; then
  printf 'TOOLCHAIN-LOCK: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'TOOLCHAIN-LOCK: PASS (%s clés : lock = Dockerfile = ci.yaml)\n' "${#lock[@]}"
printf 'ARCH arm64: PASS (%s outils : empreinte du lock = ARG du Dockerfile)\n' "${#tools_df[@]}"
if [[ "${#blocked[@]}" -gt 0 ]]; then
  printf 'ARCH amd64: BLOCKED (empreintes absentes de tools/dev/toolchain.lock, non inventées : %s)\n' "${blocked[*]}"
else
  printf 'ARCH amd64: PASS (%s outils : empreinte du lock = ARG du Dockerfile)\n' "${#tools_df[@]}"
fi
