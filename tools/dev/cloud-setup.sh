#!/usr/bin/env bash
# cloud-setup.sh : installe les outils de contrôle du labo dans la VM cloud des agents (linux x86_64), aux versions et
# empreintes de tools/dev/toolchain.lock (SL-2, T-454, réalise T-334). À brancher comme script de setup de
# l'environnement cloud (docs/DEV-FACTORY.md).
#
# - Installation dans un dossier utilisateur (CLOUD_BIN_DIR, défaut ~/.local/bin) : jamais de sudo, jamais de curl | sh.
# - Chaque téléchargement est vérifié par sha256 AVANT toute extraction ; une empreinte différente rend l'outil FAIL et
#   n'installe rien.
# - Idempotent : un outil déjà présent à la version épinglée (tools/dev/doctor --tool) n'est pas retéléchargé.
# - Aucun secret, aucun jeton ; seul accès réseau : téléchargement des archives publiques (HTTPS, proxy de l'environnement
#   respecté par curl).
#
# Usage : tools/dev/cloud-setup.sh [--only outil[,outil...]]
# Outils : helm kubeconform actionlint gitleaks shellcheck ruff yq pre-commit kubectl jq gh
# Sortie : une ligne PASS / FAIL par outil, puis tools/dev/doctor. Code 0 si tous PASS, 1 sinon, 2 usage ou architecture
# non prise en charge (les empreintes du lock sont linux-amd64 ; sur arm64 utiliser .devcontainer/Dockerfile).
# Variables : CLOUD_BIN_DIR, LOCK (tests).
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${LOCK:-$SELF_DIR/toolchain.lock}"
BIN_DIR="${CLOUD_BIN_DIR:-$HOME/.local/bin}"
ALL_TOOLS=(helm kubeconform actionlint gitleaks shellcheck ruff yq pre-commit kubectl jq gh)
ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:-}"; [[ -n "$ONLY" ]] || { echo "cloud-setup: --only demande une liste" >&2; exit 2; }; shift ;;
    -h | --help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "cloud-setup: option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "cloud-setup: cible linux x86_64 seulement (ici $(uname -s) $(uname -m)) ; sur arm64, utiliser .devcontainer/Dockerfile" >&2
  exit 2
fi
[[ -r "$LOCK" ]] || { echo "cloud-setup: lock illisible : $LOCK" >&2; exit 2; }
for c in curl tar sha256sum install; do
  command -v "$c" >/dev/null 2>&1 || { echo "cloud-setup: commande requise absente : $c" >&2; exit 2; }
done

lockval() { # CLÉ : valeur, vide si absente
  sed -n "s/^$1=//p" "$LOCK" | head -n1
}
need() { # CLÉ : valeur ou échec explicite
  local v
  v="$(lockval "$1")"
  [[ -n "$v" ]] || { echo "clé absente du lock : $1" >&2; return 1; }
  printf '%s' "$v"
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cloud-setup.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$BIN_DIR" || { echo "cloud-setup: dossier non créable : $BIN_DIR" >&2; exit 2; }

# fetch URL SHA256 FICHIER : télécharge puis vérifie ; rien n'est extrait si l'empreinte diffère.
fetch() {
  local url="$1" sha="$2" out="$3" got
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300 -o "$out" "$url" || { echo "téléchargement KO : $url" >&2; return 1; }
  got="$(sha256sum "$out" | awk '{print $1}')"
  [[ "$got" == "$sha" ]] || { echo "empreinte différente pour $(basename "$url") : attendu $sha, obtenu $got" >&2; return 1; }
}

# put FICHIER NOM : installe atomiquement dans BIN_DIR.
put() { install -m 0755 "$1" "$BIN_DIR/.$2.new" && mv -f "$BIN_DIR/.$2.new" "$BIN_DIR/$2"; }

# extrait_et_pose ARCHIVE MEMBRE NOM : cherche le fichier MEMBRE dans l'archive (tar.gz ou tar.xz) et le pose.
extrait_et_pose() {
  local arc="$1" member="$2" name="$3" d found
  d="$WORK/x.$name"
  mkdir -p "$d" && tar -xf "$arc" -C "$d" || return 1
  found="$(find "$d" -type f -name "$member" | head -n1)"
  [[ -n "$found" ]] || { echo "fichier $member absent de l'archive" >&2; return 1; }
  put "$found" "$name"
}

install_tool() { # NOM : télécharge, vérifie, pose
  local t="$1" v sha d="$WORK/dl.$1"
  mkdir -p "$d"
  case "$t" in
    helm)
      v="$(need HELM_VERSION)" && sha="$(need HELM_AMD64_SHA256)" || return 1
      fetch "https://get.helm.sh/helm-${v}-linux-amd64.tar.gz" "$sha" "$d/a.tar.gz" && extrait_et_pose "$d/a.tar.gz" helm helm ;;
    kubeconform)
      v="$(need KUBECONFORM_VERSION)" && sha="$(need KUBECONFORM_AMD64_SHA256)" || return 1
      fetch "https://github.com/yannh/kubeconform/releases/download/v${v}/kubeconform-linux-amd64.tar.gz" "$sha" "$d/a.tar.gz" &&
        extrait_et_pose "$d/a.tar.gz" kubeconform kubeconform ;;
    actionlint)
      v="$(need ACTIONLINT_VERSION)" && sha="$(need ACTIONLINT_AMD64_SHA256)" || return 1
      fetch "https://github.com/rhysd/actionlint/releases/download/v${v}/actionlint_${v}_linux_amd64.tar.gz" "$sha" "$d/a.tar.gz" &&
        extrait_et_pose "$d/a.tar.gz" actionlint actionlint ;;
    gitleaks)
      v="$(need GITLEAKS_VERSION)" && sha="$(need GITLEAKS_AMD64_SHA256)" || return 1
      fetch "https://github.com/gitleaks/gitleaks/releases/download/v${v}/gitleaks_${v}_linux_x64.tar.gz" "$sha" "$d/a.tar.gz" &&
        extrait_et_pose "$d/a.tar.gz" gitleaks gitleaks ;;
    shellcheck)
      v="$(need SHELLCHECK_VERSION)" && sha="$(need SHELLCHECK_AMD64_SHA256)" || return 1
      fetch "https://github.com/koalaman/shellcheck/releases/download/${v}/shellcheck-${v}.linux.x86_64.tar.xz" "$sha" "$d/a.tar.xz" &&
        extrait_et_pose "$d/a.tar.xz" shellcheck shellcheck ;;
    ruff)
      v="$(need RUFF_VERSION)" && sha="$(need RUFF_AMD64_SHA256)" || return 1
      fetch "https://github.com/astral-sh/ruff/releases/download/${v}/ruff-x86_64-unknown-linux-gnu.tar.gz" "$sha" "$d/a.tar.gz" &&
        extrait_et_pose "$d/a.tar.gz" ruff ruff ;;
    yq)
      v="$(need YQ_VERSION)" && sha="$(need YQ_AMD64_SHA256)" || return 1
      fetch "https://github.com/mikefarah/yq/releases/download/v${v}/yq_linux_amd64" "$sha" "$d/yq" && put "$d/yq" yq ;;
    pre-commit)
      command -v python3 >/dev/null 2>&1 || { echo "python3 requis pour pre-commit (zipapp .pyz)" >&2; return 1; }
      v="$(need PRECOMMIT_VERSION)" && sha="$(need PRECOMMIT_PYZ_SHA256)" || return 1
      fetch "https://github.com/pre-commit/pre-commit/releases/download/v${v}/pre-commit-${v}.pyz" "$sha" "$d/pre-commit.pyz" &&
        put "$d/pre-commit.pyz" pre-commit ;;
    kubectl)
      v="$(need KUBECTL_VERSION)" && sha="$(need KUBECTL_AMD64_SHA256)" || return 1
      fetch "https://dl.k8s.io/release/${v}/bin/linux/amd64/kubectl" "$sha" "$d/kubectl" && put "$d/kubectl" kubectl ;;
    jq)
      v="$(need JQ_VERSION)" && sha="$(need JQ_AMD64_SHA256)" || return 1
      fetch "https://github.com/jqlang/jq/releases/download/${v}/jq-linux-amd64" "$sha" "$d/jq" && put "$d/jq" jq ;;
    gh)
      v="$(need GH_VERSION)" && sha="$(need GH_AMD64_SHA256)" || return 1
      fetch "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_linux_amd64.tar.gz" "$sha" "$d/a.tar.gz" &&
        extrait_et_pose "$d/a.tar.gz" gh gh ;;
    *) echo "outil inconnu : $t" >&2; return 1 ;;
  esac
}

if [[ -n "$ONLY" ]]; then
  IFS=',' read -r -a TOOLS <<<"$ONLY"
else
  TOOLS=("${ALL_TOOLS[@]}")
fi

n_pass=0 n_fail=0
for t in "${TOOLS[@]}"; do
  t0="$(date +%s)"
  if [[ ! " ${ALL_TOOLS[*]} " == *" $t "* ]]; then
    printf 'FAIL %-12s outil inconnu\n' "$t"
    n_fail=$((n_fail + 1))
    continue
  fi
  if CLOUD_BIN_DIR="$BIN_DIR" LOCK="$LOCK" "$SELF_DIR/doctor" --tool "$t"; then
    printf 'PASS %-12s déjà à la version épinglée (rien téléchargé)\n' "$t"
    n_pass=$((n_pass + 1))
    continue
  fi
  err="$WORK/err.$t"
  if install_tool "$t" 2>"$err" && CLOUD_BIN_DIR="$BIN_DIR" LOCK="$LOCK" "$SELF_DIR/doctor" --tool "$t"; then
    printf 'PASS %-12s installé, sha256 vérifié (%ss)\n' "$t" "$(($(date +%s) - t0))"
    n_pass=$((n_pass + 1))
  else
    printf 'FAIL %-12s %s\n' "$t" "$(head -n1 "$err" 2>/dev/null || echo 'version installée différente de l'"'"'épingle')"
    n_fail=$((n_fail + 1))
  fi
done

printf -- '-- PASS=%s FAIL=%s (dossier : %s)\n' "$n_pass" "$n_fail" "$BIN_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note : $BIN_DIR n'est pas dans le PATH ; l'ajouter (export PATH=\"$BIN_DIR:\$PATH\") dans le shell des agents" ;;
esac
CLOUD_BIN_DIR="$BIN_DIR" LOCK="$LOCK" "$SELF_DIR/doctor" || true
[[ "$n_fail" -eq 0 ]]
