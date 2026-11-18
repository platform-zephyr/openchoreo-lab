#!/usr/bin/env bash
# Tests statiques de la Development Factory, SANS Docker, cluster ni réseau.
#  1. Garde-fou : le cas propre passe ; chaque injection (variable OKE/Doppler/GitHub, identifiant de l'hôte,
#     contexte kubectl joignant un cluster) doit échouer (test négatif).
#  2. Deux architectures (T-470) : Dockerfile piloté par TARGETARCH, empreintes du lock par architecture (cas négatifs).
#  3. Pins et montages : base par digest, sha256 pour chaque téléchargement, concordance avec ci.yaml et
#     tools/appgen/requirements.txt, aucun montage d'identifiant dans devcontainer.json.
# Usage : tests/dev-factory/run.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
GUARD="$PWD/tools/dev/guard-check.sh"
DF=".devcontainer/Dockerfile"
DJ=".devcontainer/devcontainer.json"
CI=".github/workflows/ci.yaml"
W="$(mktemp -d "${TMPDIR:-/tmp}/dev-factory-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# Faux HOME et faux kubectl (aucun chemin réel de l'hôte n'est lu).
mkdir -p "$W/home" "$W/h-kube/.kube" "$W/h-gh/.config/gh" "$W/h-oke/.cache/oke-access" "$W/h-dop/.config/doppler" "$W/bin"
printf '#!/usr/bin/env bash\necho context-fake-cluster\n' >"$W/bin/kubectl"
chmod +x "$W/bin/kubectl"

# check NOM pass|fail PREFIXE_PATH [VAR=VAL ...] : exécute le garde-fou dans un environnement vide.
check() {
  local name="$1" want="$2" pfx="$3" rc=0
  shift 3
  env -i PATH="${pfx}/usr/bin:/bin" HOME="$W/home" "$@" bash "$GUARD" >"$W/out" 2>&1 || rc=$?
  if [[ "$want" == pass && "$rc" -eq 0 ]]; then
    ok "garde-fou : $name"
  elif [[ "$want" == fail && "$rc" -ne 0 ]] && grep -q '^FAIL' "$W/out"; then
    ok "garde-fou refuse : $name"
  else
    ko "garde-fou : $name (attendu $want, rc=$rc)"
    sed 's/^/      | /' "$W/out"
  fi
}

check "environnement propre" pass ""
check "KUBECONFIG injecté" fail "" KUBECONFIG=/x
check "OKE_* injecté" fail "" OKE_CONTEXT=x
check "OCI_* injecté" fail "" OCI_CLI_PROFILE=x
check "DOPPLER_TOKEN injecté" fail "" DOPPLER_TOKEN=x
check "AWS_* injecté" fail "" AWS_PROFILE=x
check "GH_TOKEN (admin) injecté" fail "" GH_TOKEN=x
check "GITHUB_TOKEN injecté" fail "" GITHUB_TOKEN=x
check "HOME/.kube présent" fail "" HOME="$W/h-kube"
check "HOME/.config/gh présent" fail "" HOME="$W/h-gh"
check "HOME/.cache/oke-access présent" fail "" HOME="$W/h-oke"
check "HOME/.config/doppler présent" fail "" HOME="$W/h-dop"
check "kubectl joint un cluster" fail "$W/bin:" 

# Deux architectures (T-470) : lock-concordance.sh (PASS arm64, amd64 PASS ou BLOCKED dit en clair) + cas négatifs.
CONC="$PWD/tests/dev-factory/lock-concordance.sh"
if "$CONC" >"$W/conc" 2>&1; then ok "lock-concordance : $(tail -n1 "$W/conc")"; else ko "lock-concordance"; sed 's/^/      | /' "$W/conc"; fi
if grep -q '^arm64 : PASS$' "$W/conc"; then ok "arm64 : PASS"; else ko "arm64 : pas de verdict PASS"; fi
if grep -Eq '^amd64 : (PASS|BLOCKED \(empreinte amd64 absente du lock : [A-Z ]+\))' "$W/conc"; then ok "$(grep '^amd64' "$W/conc" | cut -c1-72)"; else ko "amd64 : verdict absent ou invalide"; fi
neg() { # neg NOM SED_EXPR : copie du Dockerfile modifiée ; la concordance doit échouer
  sed -E "$2" "$DF" >"$W/Dockerfile.neg"
  if DF="$W/Dockerfile.neg" "$CONC" >"$W/neg" 2>&1; then ko "concordance accepte : $1"; else ok "concordance refuse : $1"; fi
}
neg "ARG TARGETARCH retiré" '/^ARG TARGETARCH$/d'
neg "URL arm64 écrite en dur" 's#linux-\$\{TARGETARCH\}\.tar\.gz#linux-arm64.tar.gz#'
neg "empreinte amd64 de helm modifiée" 's/^(ARG HELM_AMD64_SHA256=)./\1f/'
neg "branche amd64 de yq retirée" '/amd64\) sha="\$\{YQ_AMD64_SHA256\}"/d'
neg "arrêt BLOCKED de kubectl retiré" '/BLOCKED: KUBECTL_AMD64_SHA256/d'
neg "empreinte amd64 inventée pour jq" 's/^(ARG JQ_SHA256=.*)$/\1\nARG JQ_AMD64_SHA256=0000000000000000000000000000000000000000000000000000000000000000/'
neg "ruff du Dockerfile désaligné" 's/"ruff==[0-9.]+"/"ruff==0.0.1"/'
if grep -q '^amd64 : BLOCKED' "$W/conc"; then
  if STRICT_AMD64=1 "$CONC" >"$W/strict" 2>&1; then ko "STRICT_AMD64=1 accepte un amd64 BLOCKED"; else ok "STRICT_AMD64=1 refuse un amd64 BLOCKED"; fi
fi
if grep -Eq -- '--platform' "$DJ"; then ko "devcontainer.json impose une plateforme (--platform)"; else ok "devcontainer.json : plateforme de l'hôte (aucun --platform)"; fi
if grep -Eq '"postCreateCommand": "tools/dev/guard-check.sh && tools/dev/setup"' "$DJ"; then ok "postCreateCommand : guard-check puis setup (hooks + doctor)"; else ko "postCreateCommand inattendu"; fi

# Pins : base par digest, un sha256 par téléchargement.
if grep -Eq '^FROM python:[^@ ]+@sha256:[0-9a-f]{64}$' "$DF"; then ok "image de base épinglée par digest"; else ko "image de base non épinglée par digest"; fi
dl="$(grep -cE 'curl -fsSL[Oo]' "$DF")"; ver="$(grep -c 'sha256sum -c' "$DF")"
if [[ "$dl" -gt 0 && "$dl" -eq "$ver" ]]; then ok "chaque téléchargement ($dl) a un sha256sum -c ($ver)"; else ko "téléchargements $dl / vérifications sha256 $ver"; fi

# Concordance avec ci.yaml pour les outils déjà épinglés dans la CI (version et sha256).
for tool in HELM KUBECONFORM YQ GITLEAKS ACTIONLINT; do
  v="$(sed -n "s/^  ${tool}_VERSION: \"\\(.*\\)\"/\\1/p" "$CI")"
  s="$(sed -n "s/^  ${tool}_SHA256: \"\\([0-9a-f]*\\)\"/\\1/p" "$CI")"
  if [[ -n "$v" ]] && grep -Eq "^ARG ${tool}_VERSION=v?${v}\$" "$DF" && grep -Fq "ARG ${tool}_SHA256=${s}" "$DF"; then
    ok "$tool : version $v et sha256 identiques à ci.yaml"
  else
    ko "$tool : désaccord Dockerfile / ci.yaml (version=$v sha=${s:0:12}...)"
  fi
done

# Outils Python : mêmes versions que la CI et que tools/appgen/requirements.txt.
for pin in "yamllint==1.38.0" "PyYAML==6.0.2" "jsonschema==4.23.0"; do
  if grep -Fq "\"$pin\"" "$DF"; then ok "Dockerfile pin $pin"; else ko "Dockerfile sans $pin"; fi
done
for pin in PyYAML==6.0.2 jsonschema==4.23.0; do
  grep -Fxq "$pin" tools/appgen/requirements.txt || ko "requirements.txt ne contient pas $pin"
done
grep -Fq "yamllint==1.38.0" "$CI" && ok "yamllint 1.38.0 identique à ci.yaml"

# Montages et options : aucun identifiant ni socket de l'hôte, pas de privilège.
if grep -Eiq '\.kube|\.oci|oke-access|config/gh|doppler|docker\.sock|privileged|\.aws|\.ssh' "$DJ" "$DF"; then
  ko "devcontainer/Dockerfile référence un identifiant, un socket ou --privileged"
else
  ok "aucun montage d'identifiant, de socket Docker ni de privilège"
fi
if python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); a=" ".join(d["runArgs"]); sys.exit(0 if all(x in a for x in ["--cpus=","--memory=","--cap-drop=ALL"]) else 1)' "$DJ"; then
  ok "limites CPU/RAM et cap-drop dans runArgs"
else
  ko "runArgs sans limites CPU/RAM ou sans --cap-drop=ALL"
fi

# Hooks git locaux (SL-4, T-459) : NOT_TESTED (rc 0) si pre-commit ou un outil manque.
if "$PWD/tests/dev-factory/precommit-test.sh" >"$W/precommit" 2>&1; then
  ok "hooks git : $(tail -n1 "$W/precommit")"
else
  ko "hooks git (tests/dev-factory/precommit-test.sh)"
  sed 's/^/      | /' "$W/precommit"
fi

if [[ "$fails" -gt 0 ]]; then
  printf 'DEV-FACTORY-STATIC: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'DEV-FACTORY-STATIC: PASS\n'
