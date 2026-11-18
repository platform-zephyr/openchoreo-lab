#!/usr/bin/env bash
# Tests de tools/dev/check et de la concordance toolchain.lock, SANS Docker, cluster ni réseau.
#  1. Concordance : le dépôt passe ; une version ou un sha256 modifié (lock, Dockerfile, ci.yaml) échoue (cas négatifs).
#  2. check : un contrôle PASS donne rc 0 ; un FAIL donne rc 1 ; un outil absent donne NOT_TESTED (jamais PASS), rc 0,
#     et rc 3 avec --strict ; --k3d sans kubectl donne NOT_TESTED ; usage incorrect donne rc 2.
# Usage : tests/dev-factory/check-test.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
CHECK="$PWD/tools/dev/check"
CONC="$PWD/tests/dev-factory/lock-concordance.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/check-test.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# expect NOM RC_ATTENDU CMD... : exécute, compare le code de sortie ; la sortie reste dans $W/out.
expect() {
  local name="$1" want="$2" rc=0
  shift 2
  "$@" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then ok "$name (rc=$rc)"; else ko "$name (attendu rc=$want, obtenu $rc)"; sed 's/^/      | /' "$W/out"; fi
}
out_has() { # NOM MOTIF
  if grep -Eq "$2" "$W/out"; then ok "$1"; else ko "$1 (motif absent : $2)"; sed 's/^/      | /' "$W/out"; fi
}

# ---- 1. concordance ----
expect "concordance : dépôt en accord" 0 "$CONC"

cp tools/dev/toolchain.lock "$W/lock.bad-version"
sed -i 's/^HELM_VERSION=.*/HELM_VERSION=v4.9.9/' "$W/lock.bad-version"
expect "concordance refuse une version modifiée (lock)" 1 env LOCK="$W/lock.bad-version" "$CONC"
out_has "  … nomme HELM_VERSION" 'HELM_VERSION'

cp tools/dev/toolchain.lock "$W/lock.bad-sha"
sed -i 's/^GITLEAKS_SHA256=.*/GITLEAKS_SHA256=0000000000000000000000000000000000000000000000000000000000000000/' "$W/lock.bad-sha"
expect "concordance refuse un sha256 modifié (lock)" 1 env LOCK="$W/lock.bad-sha" "$CONC"

cp .devcontainer/Dockerfile "$W/Dockerfile.bad"
sed -i 's/^ARG KUBECONFORM_VERSION=.*/ARG KUBECONFORM_VERSION=0.0.1/' "$W/Dockerfile.bad"
expect "concordance refuse une version modifiée (Dockerfile)" 1 env DF="$W/Dockerfile.bad" "$CONC"

cp .github/workflows/ci.yaml "$W/ci.bad"
sed -i 's/^  ACTIONLINT_VERSION: .*/  ACTIONLINT_VERSION: "0.0.1"/' "$W/ci.bad"
expect "concordance refuse une version modifiée (ci.yaml)" 1 env CI="$W/ci.bad" "$CONC"

cp .devcontainer/Dockerfile "$W/Dockerfile.extra"
printf 'ARG NEWTOOL_VERSION=1.0.0\n' >>"$W/Dockerfile.extra"
expect "concordance refuse un ARG du Dockerfile absent du lock" 1 env DF="$W/Dockerfile.extra" "$CONC"

cp tools/dev/toolchain.lock "$W/lock.bad-pip"
sed -i 's/^YAMLLINT_VERSION=.*/YAMLLINT_VERSION=0.0.1/' "$W/lock.bad-pip"
expect "concordance refuse un pip modifié" 1 env LOCK="$W/lock.bad-pip" "$CONC"

# ---- 2. check ----
expect "check sans argument : usage" 2 "$CHECK"
expect "check option inconnue" 2 "$CHECK" --bogus
expect "check --static : un contrôle PASS" 0 env CHECK_ONLY=toolchain-lock "$CHECK" --static
out_has "  … ligne PASS et verdict PASS" '^PASS +toolchain-lock'
out_has "  … RESULT: PASS" '^RESULT: PASS$'

expect "check --static : un FAIL donne rc 1" 1 env CHECK_ONLY=toolchain-lock LOCK="$W/lock.bad-version" "$CHECK" --static
out_has "  … ligne FAIL et RESULT: FAIL" '^FAIL +toolchain-lock'
out_has "  … RESULT: FAIL" '^RESULT: FAIL$'

# PATH restreint : aucun outil de lint, mais bash, python3, git et l'outillage de base.
mkdir -p "$W/bin"
for t in env date mktemp rm tail sed cat grep head uname awk dirname basename python3 git bash flock; do
  p="$(command -v "$t" || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$W/bin/$t"
done
expect "outil absent : NOT_TESTED et rc 0" 0 env PATH="$W/bin" CHECK_ONLY=shellcheck,gitleaks,actionlint "$CHECK" --static
out_has "  … shellcheck NOT_TESTED (outil absent)" '^NOT_TESTED +shellcheck .*outil absent : shellcheck'
out_has "  … gitleaks NOT_TESTED" '^NOT_TESTED +gitleaks'
out_has "  … verdict INCOMPLET, pas PASS" '^RESULT: INCOMPLET'
if grep -Eq '^PASS ' "$W/out"; then ko "un outil absent ne doit jamais apparaître PASS"; else ok "aucune ligne PASS pour les outils absents"; fi
expect "outil absent avec --strict : rc 3" 3 env PATH="$W/bin" CHECK_ONLY=shellcheck "$CHECK" --static --strict
expect "outil absent + un FAIL : rc 1 (FAIL prioritaire)" 1 env PATH="$W/bin" CHECK_ONLY=shellcheck,toolchain-lock LOCK="$W/lock.bad-version" "$CHECK" --static --strict
expect "CHECK_SKIP : exclu = NOT_TESTED" 0 env CHECK_ONLY=toolchain-lock CHECK_SKIP=toolchain-lock "$CHECK" --static
out_has "  … exclu (CHECK_SKIP)" '^NOT_TESTED +toolchain-lock .*exclu'
# Contrôles portés par un ticket futur : tant que le script manque, NOT_TESTED (jamais PASS).
for pair in leak-guard:tests/leak-guard/run.sh identities:tests/identities/run.sh settings:tests/hooks/settings.test.sh hooks:tests/hooks/run.sh; do
  if [[ ! -f "${pair#*:}" ]]; then
    expect "script absent (${pair#*:}) : NOT_TESTED" 0 env CHECK_ONLY="${pair%%:*}" "$CHECK" --static
    out_has "  … ${pair%%:*} NOT_TESTED, pas PASS" "^NOT_TESTED +${pair%%:*} .*absent du dépôt"
  fi
done
expect "--k3d sans kubectl : NOT_TESTED" 0 env PATH="$W/bin" "$CHECK" --k3d
out_has "  … k3d NOT_TESTED (outil absent)" '^NOT_TESTED +k3d .*kubectl'

if [[ "$fails" -gt 0 ]]; then
  printf 'CHECK-TEST: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'CHECK-TEST: PASS\n'
