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
# ---- 3. contrôles miroirs de la CI (SL-1, T-453) ----
# 3a. chaque contrôle existe dans check (une étape oubliée ne produirait aucune ligne).
MIRRORS="quality ruff-bugs shellcheck-all backlog-unittest identities-lint yamllint-platform coverage leak-guard"
for n in $MIRRORS; do
  expect "contrôle $n présent dans --static" 0 env PATH="$W/bin" CHECK_ONLY="$n" "$CHECK" --static
  out_has "  … ligne de résultat pour $n" "^(PASS|NOT_TESTED|FAIL) +$n "
done
# 3b. outil absent : NOT_TESTED, jamais PASS ni FAIL (leak-guard sans gitleaks compris).
for n in quality ruff-bugs shellcheck-all yamllint-platform coverage leak-guard; do
  expect "$n sans outil : rc 0" 0 env PATH="$W/bin" CHECK_ONLY="$n" "$CHECK" --static
  out_has "  … $n NOT_TESTED" "^NOT_TESTED +$n .*outil absent"
  if grep -Eq "^(PASS|FAIL) " "$W/out"; then ko "$n absent ne doit être ni PASS ni FAIL"; else ok "$n absent : ni PASS ni FAIL"; fi
done
expect "leak-guard sans gitleaks avec --strict : rc 3, pas 1" 3 env PATH="$W/bin" CHECK_ONLY=leak-guard "$CHECK" --static --strict

# 3c. outils factices (cas négatifs) : un outil qui échoue donne FAIL ; un ruff d'une autre version donne NOT_TESTED.
PIN="$(grep -o 'ruff==[0-9][0-9.]*' .github/workflows/ci.yaml | head -n 1 | cut -d= -f3)"
mkdir -p "$W/fake"
for t in env date mktemp rm tail sed cat grep head cut awk uname dirname basename python3 git bash; do
  p="$(command -v "$t" || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$W/fake/$t"
done
# shellcheck disable=SC2016  # script factice : $1 doit rester littéral
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "ruff %s"; exit 0; }\necho "E9 factice"; exit 1\n' "$PIN" >"$W/fake/ruff"
printf '#!/bin/sh\necho "SC9999 factice"; exit 1\n' >"$W/fake/shellcheck"
printf '#!/bin/sh\necho "yamllint factice"; exit 1\n' >"$W/fake/yamllint"
chmod +x "$W/fake/ruff" "$W/fake/shellcheck" "$W/fake/yamllint"
expect "ruff-bugs : ruff qui échoue donne FAIL (rc 1)" 1 env PATH="$W/fake" CHECK_ONLY=ruff-bugs "$CHECK" --static
out_has "  … ligne FAIL ruff-bugs" '^FAIL +ruff-bugs'
expect "shellcheck-all : shellcheck qui échoue donne FAIL" 1 env PATH="$W/fake" CHECK_ONLY=shellcheck-all "$CHECK" --static
out_has "  … ligne FAIL shellcheck-all" '^FAIL +shellcheck-all'
expect "yamllint-platform : yamllint qui échoue donne FAIL" 1 env PATH="$W/fake" CHECK_ONLY=yamllint-platform "$CHECK" --static
out_has "  … ligne FAIL yamllint-platform" '^FAIL +yamllint-platform'
# shellcheck disable=SC2016  # script factice : $1 doit rester littéral
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "ruff 0.0.1"; exit 0; }\nexit 0\n' >"$W/fake/ruff"
expect "ruff d'une autre version : NOT_TESTED (rc 0), pas PASS" 0 env PATH="$W/fake" CHECK_ONLY=ruff-bugs "$CHECK" --static
out_has "  … ruff-bugs NOT_TESTED sur version" '^NOT_TESTED +ruff-bugs .*précondition'
expect "ruff d'une autre version : quality NOT_TESTED aussi" 0 env PATH="$W/fake" CHECK_ONLY=quality "$CHECK" --static
if grep -Eq '^(PASS|FAIL) ' "$W/out"; then ko "quality avec ruff non épinglé ne doit être ni PASS ni FAIL"; else ok "quality avec ruff non épinglé : ni PASS ni FAIL"; fi

# 3d. avec les vrais outils présents, les contrôles miroirs passent sur le dépôt (sinon NOT_TESTED : outil absent).
for n in backlog-unittest identities-lint; do
  expect "$n sur le dépôt" 0 env CHECK_ONLY="$n" "$CHECK" --static
  out_has "  … $n PASS" "^PASS +$n "
done
if command -v ruff >/dev/null 2>&1; then
  expect "ruff-bugs sur le dépôt (ruff réel)" 0 env CHECK_ONLY=ruff-bugs "$CHECK" --static
  out_has "  … ruff-bugs PASS ou NOT_TESTED (version)" '^(PASS|NOT_TESTED) +ruff-bugs '
fi

expect "--k3d sans kubectl : NOT_TESTED" 0 env PATH="$W/bin" "$CHECK" --k3d
out_has "  … k3d NOT_TESTED (outil absent)" '^NOT_TESTED +k3d .*kubectl'

if [[ "$fails" -gt 0 ]]; then
  printf 'CHECK-TEST: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'CHECK-TEST: PASS\n'
