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
# Le reçu de check (SL-3) ne doit jamais écraser celui de l'exécution qui lance ce test.
export CHECK_RECEIPT="$W/receipt.json"
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

# SL-2 (T-454) : empreintes linux-amd64 et outils de la VM cloud.
cp tools/dev/toolchain.lock "$W/lock.bad-amd64"
sed -i 's/^HELM_AMD64_SHA256=.*/HELM_AMD64_SHA256=pas-une-empreinte/' "$W/lock.bad-amd64"
expect "concordance refuse une empreinte amd64 invalide" 1 env LOCK="$W/lock.bad-amd64" "$CONC"
out_has "  … nomme HELM_AMD64_SHA256" 'HELM_AMD64_SHA256'

cp tools/dev/toolchain.lock "$W/lock.same-arch"
sed -i 's/^YQ_AMD64_SHA256=.*/YQ_AMD64_SHA256=cf0a663d8e4e00bb61507c5237b95b45a6aaa1fbedac77f4dc8abdadd5e2b745/' "$W/lock.same-arch"
expect "concordance refuse une empreinte amd64 égale à l'arm64" 1 env LOCK="$W/lock.same-arch" "$CONC"

grep -v '^KUBECONFORM_VERSION=' tools/dev/toolchain.lock >"$W/lock.no-version"
expect "concordance refuse une empreinte amd64 sans version" 1 env LOCK="$W/lock.no-version" "$CONC"

cp tools/dev/toolchain.lock "$W/lock.bad-ruff"
sed -i 's/^RUFF_VERSION=.*/RUFF_VERSION=0.0.1/' "$W/lock.bad-ruff"
expect "concordance refuse un ruff différent de ci.yaml" 1 env LOCK="$W/lock.bad-ruff" "$CONC"
out_has "  … nomme RUFF_VERSION" 'RUFF_VERSION'

cp tools/dev/toolchain.lock "$W/lock.extra-amd64"
printf 'NEWTOOL_VERSION=1.0.0\nNEWTOOL_AMD64_SHA256=%064d\n' 1 >>"$W/lock.extra-amd64"
expect "concordance refuse une clé amd64 non lue par cloud-setup.sh" 1 env LOCK="$W/lock.extra-amd64" "$CONC"
out_has "  … nomme NEWTOOL_AMD64_SHA256" 'NEWTOOL_AMD64_SHA256'

# doctor : sortie non nulle si un outil requis manque (PATH vide de ces outils, dossier vide), 0 si tout est présent.
mkdir -p "$W/emptybin" "$W/fakebin"
expect "doctor : outils requis absents donne rc 1" 1 env PATH="/usr/bin:/bin" CLOUD_BIN_DIR="$W/emptybin" "$PWD/tools/dev/doctor"
out_has "  … liste outil par outil (absent)" '^helm +absent'
for t in helm kubeconform actionlint gitleaks shellcheck ruff yq pre-commit; do
  printf '#!/bin/sh\nexit 0\n' >"$W/fakebin/$t"
  chmod +x "$W/fakebin/$t"
done
expect "doctor : outils présents mais version illisible donne rc 1" 1 env PATH="/usr/bin:/bin" CLOUD_BIN_DIR="$W/fakebin" "$PWD/tools/dev/doctor"
expect "doctor --tool : outil absent donne rc 1" 1 env PATH="/usr/bin:/bin" CLOUD_BIN_DIR="$W/emptybin" "$PWD/tools/dev/doctor" --tool helm
expect "doctor : option inconnue donne rc 2" 2 "$PWD/tools/dev/doctor" --bogus
expect "cloud-setup : option inconnue donne rc 2" 2 "$PWD/tools/dev/cloud-setup.sh" --bogus

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

# ---- 4. niveaux rapides, sélection, parallélisme, JSON et reçu (SL-3, T-455) ----
# Dépôt factice : copie de check et de sa table, ci.yaml (version de ruff), outils factices dans $W/f2.
R="$W/repo"
g() { git -C "$R" -c user.email=noreply@example.com -c user.name=test "$@"; }
mkdir -p "$R/tools/dev" "$R/.github/workflows" "$R/tools/backlog" "$R/tools/appgen" "$R/tools/x" "$R/docs" "$W/f2"
cp tools/dev/check tools/dev/check-paths.tsv "$R/tools/dev/"
cp .github/workflows/ci.yaml "$R/.github/workflows/"
printf 'import sys\nsys.exit(0)\n' >"$R/tools/backlog/check.py"
printf 'extends: default\n' >"$R/tools/appgen/yamllint.yaml"
printf 'base\n' >"$R/docs/base.md"
git init -q -b main "$R"
g add -A
g commit -q -m base
g update-ref refs/remotes/origin/main HEAD
for t in env date mktemp rm tail sed cat grep head cut awk uname dirname basename python3 git bash mkdir sleep cp; do
  p="$(command -v "$t" || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$W/f2/$t"
done
cat >"$W/f2/ruff" <<EOF
#!/bin/sh
[ "\$1" = "--version" ] && { echo "ruff $PIN"; exit 0; }
sleep "\${FAKE_SLEEP:-0}"
for a in "\$@"; do [ -f "\$a" ] && grep -q undefined_name "\$a" && { echo "F821 \$a"; exit 1; }; done
exit 0
EOF
for t in shellcheck yamllint; do
  cat >"$W/f2/$t" <<EOF
#!/bin/sh
sleep "\${FAKE_SLEEP:-0}"
[ "\${FAKE_FAIL:-}" = "$t" ] && { echo "$t factice : echec demande"; exit 1; }
for a in "\$@"; do [ -f "\$a" ] && grep -q FAILME "\$a" && { echo "$t factice : FAILME dans \$a"; exit 1; }; done
exit 0
EOF
done
# shellcheck disable=SC2016  # script factice : ${FAKE_SLEEP} doit rester littéral
printf '#!/bin/sh\nsleep "${FAKE_SLEEP:-0}"\nexit 0\n' >"$W/f2/actionlint"
cat >"$W/f2/gitleaks" <<EOF
#!/bin/sh
echo "\$*" >"$W/gl.args"
while [ \$# -gt 0 ]; do [ "\$1" = "--config" ] && cp "\$2" "$W/gl.cfg"; shift; done
[ "\${FAKE_FAIL:-}" = "gitleaks" ] && { echo "leaks found"; exit 1; }
exit 0
EOF
chmod +x "$W"/f2/*
cat >"$W/inmini.sh" <<EOF
#!/bin/bash
# RECEIPT_TO : chemin du reçu voulu ; sinon le reçu par défaut du dépôt factice (.git/check-receipt.json).
if [ -n "\${RECEIPT_TO:-}" ]; then export CHECK_RECEIPT="\$RECEIPT_TO"; else unset CHECK_RECEIPT; fi
cd "$R" && exec env PATH="$W/f2" "\$@"
EOF
chmod +x "$W/inmini.sh"
MINI="$W/inmini.sh"
mini_reset() { g reset -q --hard; g clean -fdq; mkdir -p "$R/tools/x" "$R/docs"; }
now_ms() { local t="$EPOCHREALTIME"; echo $((10#${t/./} / 1000)); }

# 4a. --file : un contrôle par type de fichier, FAIL = rc 2, rien sur stdout si FAIL.
mini_reset
printf 'x = 1\n' >"$R/tools/x/ok.py"
printf 'print(undefined_name)\n' >"$R/tools/x/bad.py"
printf '#!/bin/bash\necho ok\n' >"$R/tools/x/ok.sh"
printf '#!/bin/bash\necho FAILME\n' >"$R/tools/x/bad.sh"
printf '#!/bin/bash\necho FAILME\n' >"$R/tools/x/noext"
printf 'a: 1\n' >"$R/tools/x/ok.yaml"
printf 'a: FAILME\n' >"$R/tools/x/bad.yaml"
printf '{"a": 1}\n' >"$R/tools/x/ok.json"
printf '{"a": \n' >"$R/tools/x/bad.json"
printf 'texte\n' >"$R/docs/notes.md"
expect "--file py sain : PASS rc 0" 0 "$MINI" tools/dev/check --file tools/x/ok.py
out_has "  … PASS ruff:tools/x/ok.py" '^PASS +ruff:tools/x/ok.py'
expect "--file py fautif : FAIL rc 2" 2 "$MINI" tools/dev/check --file tools/x/bad.py
out_has "  … FAIL ruff:tools/x/bad.py" '^FAIL +ruff:tools/x/bad.py'
expect "--file shell fautif : rc 2" 2 "$MINI" tools/dev/check --file tools/x/bad.sh
out_has "  … FAIL shellcheck" '^FAIL +shellcheck:tools/x/bad.sh'
expect "--file shell sans extension (shebang) : contrôlé" 2 "$MINI" tools/dev/check --file tools/x/noext
out_has "  … shellcheck sur le fichier sans extension" '^FAIL +shellcheck:tools/x/noext'
expect "--file shell sain : rc 0" 0 "$MINI" tools/dev/check --file tools/x/ok.sh
expect "--file yaml fautif : rc 2" 2 "$MINI" tools/dev/check --file tools/x/bad.yaml
out_has "  … FAIL yamllint" '^FAIL +yamllint:tools/x/bad.yaml'
expect "--file yaml sain : rc 0" 0 "$MINI" tools/dev/check --file tools/x/ok.yaml
expect "--file json invalide : rc 2" 2 "$MINI" tools/dev/check --file tools/x/bad.json
out_has "  … FAIL json" '^FAIL +json:tools/x/bad.json'
expect "--file json valide : rc 0" 0 "$MINI" tools/dev/check --file tools/x/ok.json
expect "--file type sans contrôle : rc 0, jamais PASS" 0 "$MINI" tools/dev/check --file docs/notes.md
if grep -Eq '^PASS ' "$W/out"; then ko "un fichier sans contrôle ne doit pas apparaître PASS"; else ok "fichier sans contrôle : aucune ligne PASS"; fi
out_has "  … hors périmètre listé" 'hors périmètre'
expect "--file : chemin relatif depuis un sous-dossier" 2 bash -c "cd '$R/tools/x' && env PATH='$W/f2' '$R/tools/dev/check' --file bad.py"
expect "--file : chemin absolu" 2 "$MINI" tools/dev/check --file "$R/tools/x/bad.py"
expect "--file : fichier absent : rc 2" 2 "$MINI" tools/dev/check --file tools/x/nexiste.py
expect "--file sans chemin : rc 2" 2 "$MINI" tools/dev/check --file
expect "--file avec --static : rc 2" 2 "$MINI" tools/dev/check --file tools/x/ok.py --static
fail_stdout="$("$MINI" tools/dev/check --file tools/x/bad.py 2>/dev/null || true)"
if [[ -z "$fail_stdout" ]]; then ok "--file FAIL : stdout vide, détail sur stderr"; else ko "--file FAIL : stdout non vide"; fi
expect "--file sans outil : NOT_TESTED rc 0" 0 env PATH="$W/bin" "$CHECK" --file tools/dev/check-paths.tsv tools/backlog/check.py
out_has "  … ruff absent : NOT_TESTED" '^NOT_TESTED +ruff:tools/backlog/check.py .*outil absent'
expect "--file sans outil avec --strict : rc 3" 3 env PATH="$W/bin" "$CHECK" --file tools/backlog/check.py --strict
cp "$W/f2/ruff" "$W/ruff.keep"
# shellcheck disable=SC2016  # script factice : $1 doit rester littéral
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "ruff 0.0.1"; exit 0; }\nexit 0\n' >"$W/f2/ruff"
expect "--file ruff d'une autre version : NOT_TESTED, pas PASS" 0 "$MINI" tools/dev/check --file tools/x/ok.py
out_has "  … NOT_TESTED précondition" '^NOT_TESTED +ruff:tools/x/ok.py .*précondition'
cp "$W/ruff.keep" "$W/f2/ruff"
chmod +x "$W/f2/ruff"
if command -v ruff >/dev/null 2>&1; then
  t0="$(now_ms)"
  "$CHECK" --file tools/appgen/appgen.py tools/dev/check-paths.tsv >/dev/null 2>&1 || true
  t1="$(now_ms)"
  if [[ $((t1 - t0)) -lt 2000 ]]; then ok "--file (ruff réel) en moins de 2 s ($((t1 - t0)) ms)"; else ko "--file trop lent : $((t1 - t0)) ms"; fi
fi

# 4b. --fast : fichiers modifiés (non suivis, indexés), types séparés, fichiers supprimés ignorés.
mini_reset
printf 'print(undefined_name)\n' >"$R/tools/x/bad.py"
printf '#!/bin/bash\necho FAILME\n' >"$R/tools/x/bad.sh"
printf 'a: FAILME\n' >"$R/tools/x/bad.yaml"
expect "--fast : trois FAIL, rc 1" 1 "$MINI" tools/dev/check --fast
out_has "  … ruff-fast FAIL" '^FAIL +ruff-fast'
out_has "  … shellcheck-fast FAIL" '^FAIL +shellcheck-fast'
out_has "  … yamllint-fast FAIL" '^FAIL +yamllint-fast'
out_has "  … backlog PASS" '^PASS +backlog '
mini_reset
printf 'x = 1\n' >"$R/tools/x/ok.py"
printf '#!/bin/bash\necho ok\n' >"$R/tools/x/ok.sh"
printf 'a: 1\n' >"$R/tools/x/ok.yaml"
expect "--fast : fichiers sains, rc 0" 0 "$MINI" tools/dev/check --fast
out_has "  … RESULT: PASS" '^RESULT: PASS$'
mini_reset
printf 'texte\n' >"$R/docs/notes.md"
expect "--fast : seul du texte modifié, rc 0" 0 "$MINI" tools/dev/check --fast
out_has "  … contrôles par type hors périmètre" 'hors périmètre \(3\) : ruff-fast yamllint-fast shellcheck-fast'
mini_reset
printf 'x = 1\n' >"$R/tools/x/ok.py"
printf '#!/bin/bash\necho FAILME\n' >"$R/tools/x/bad.sh"
g add tools/x/ok.py
expect "--fast : seuls les fichiers indexés comptent" 0 "$MINI" tools/dev/check --fast
out_has "  … ruff-fast PASS sur l'indexé" '^PASS +ruff-fast'
if grep -q '^FAIL' "$W/out"; then ko "--fast ne doit pas lire le fichier non indexé"; else ok "--fast : fichier non indexé ignoré"; fi
mini_reset
rm "$R/tools/backlog/check.py"
printf 'import sys\nsys.exit(1)\n' >"$R/tools/backlog/check.py"
expect "--fast : un backlog en échec donne FAIL" 1 "$MINI" tools/dev/check --fast
out_has "  … FAIL backlog" '^FAIL +backlog '
mini_reset
rm "$R/docs/base.md"
expect "--fast : fichier supprimé ignoré, pas d'erreur" 0 "$MINI" tools/dev/check --fast
mini_reset
expect "--fast avec --static : rc 2" 2 "$MINI" tools/dev/check --fast --static
t0="$(now_ms)"
"$CHECK" --fast >/dev/null 2>&1 || true
t1="$(now_ms)"
if [[ $((t1 - t0)) -lt 10000 ]]; then ok "--fast sur le dépôt réel en moins de 10 s ($((t1 - t0)) ms)"; else ko "--fast trop lent : $((t1 - t0)) ms"; fi

# 4c. --changed : sélection par chemins (table), défaut sûr, sélection totale.
SEL="yamllint,actionlint,ruff-bugs,gitleaks,shellcheck"
expect "--changed sans --static : rc 2" 2 "$MINI" tools/dev/check --changed
mini_reset
printf 'texte\n' >"$R/docs/notes.md"
expect "--changed : un .md ne déclenche ni yamllint ni ruff, même si yamllint échouerait" 0 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … gitleaks (motif *) s'exécute" '^PASS +gitleaks'
out_has "  … yamllint hors périmètre" 'hors périmètre \([0-9]+\) :.*yamllint'
if grep -Eq '^(PASS|FAIL|NOT_TESTED) +(yamllint|ruff-bugs|actionlint) ' "$W/out"; then ko "contrôle hors périmètre exécuté"; else ok "contrôles hors périmètre non exécutés"; fi
mini_reset
printf 'a: 1\n' >"$R/tools/x/ok.yaml"
expect "--changed : un .yaml déclenche yamllint (FAIL visible)" 1 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … yamllint FAIL" '^FAIL +yamllint '
mini_reset
printf 'x = 1\n' >"$R/tools/x/ok.py"
expect "--changed : un .py déclenche ruff-bugs, pas yamllint" 0 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … ruff-bugs PASS" '^PASS +ruff-bugs '
mini_reset
printf '# x\n' >>"$R/tools/dev/check-paths.tsv"
expect "--changed : tools/dev/ sélectionne tout" 1 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … message de sélection totale" 'tous les contrôles sont sélectionnés'
out_has "  … yamllint s'exécute" '^FAIL +yamllint '
mini_reset
printf 'x: 1\n' >"$R/pyproject.toml"
expect "--changed : pyproject.toml sélectionne tout" 1 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
mini_reset
printf 'x: 1\n' >"$R/.github/workflows/z.yaml"
expect "--changed : .github/ sélectionne tout" 1 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
mini_reset
expect "--changed sans aucune modification : rien d'exécuté, rc 0" 0 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … aucun contrôle sélectionné" '^RESULT: PASS \(aucun contrôle sélectionné'
g update-ref -d refs/remotes/origin/main
printf 'texte\n' >"$R/docs/notes.md"
expect "--changed sans origin/main : tout sélectionné (défaut sûr)" 1 env CHECK_ONLY="$SEL" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … origin/main absent signalé" 'origin/main absent'
g update-ref refs/remotes/origin/main HEAD
mini_reset
expect "--changed : liste forcée (CHECK_CHANGED_FILES)" 0 env CHECK_ONLY="$SEL" CHECK_CHANGED_FILES=$'docs/a.md\ndocs/b.md' FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --changed
out_has "  … 2 fichiers" '2 fichier\(s\) modifié'
cp tools/dev/check-paths.tsv "$W/paths.bad"
sed -i '/^gitleaks\t/d' "$W/paths.bad"
printf 'gitleaks\tnexiste/*\n' >>"$W/paths.bad"
cp "$W/paths.bad" "$R/tools/dev/check-paths.tsv"
g add -A
g commit -q -m "table modifiée"
g update-ref refs/remotes/origin/main HEAD
printf 'texte\n' >"$R/docs/notes.md"
expect "--changed : la table fait foi (motif modifié, gitleaks non sélectionné)" 0 env CHECK_ONLY="$SEL" "$MINI" tools/dev/check --static --changed
if grep -Eq '^(PASS|FAIL|NOT_TESTED) +gitleaks' "$W/out"; then ko "gitleaks ne devait pas être sélectionné"; else ok "gitleaks hors périmètre après modification de la table"; fi
mini_reset
g revert --no-edit HEAD >/dev/null
g update-ref refs/remotes/origin/main HEAD
# Table et contrôles de --static : une ligne par contrôle, aucune ligne orpheline (cas négatifs par dérive).
"$CHECK" --list >"$W/steps.list"
miss=""
while IFS= read -r s; do grep -Eq "^${s}	" tools/dev/check-paths.tsv || miss="$miss $s"; done <"$W/steps.list"
if [[ -z "$miss" ]]; then ok "check-paths.tsv : chaque contrôle de --static a une ligne"; else ko "check-paths.tsv : lignes manquantes :$miss"; fi
orph=""
while IFS=$'\t' read -r s _; do
  [[ -z "$s" || "$s" == \#* ]] && continue
  grep -Fxq "$s" "$W/steps.list" || orph="$orph $s"
done <tools/dev/check-paths.tsv
if [[ -z "$orph" ]]; then ok "check-paths.tsv : aucune ligne orpheline"; else ko "check-paths.tsv : contrôles inconnus :$orph"; fi
grep -v '^cell-cpt	' tools/dev/check-paths.tsv >"$W/paths.nocell"
miss=""
while IFS= read -r s; do grep -Eq "^${s}	" "$W/paths.nocell" || miss="$miss $s"; done <"$W/steps.list"
if [[ "$miss" == " cell-cpt" ]]; then ok "le test de table détecte une ligne retirée (cell-cpt)"; else ko "le test de table n'a pas détecté la ligne retirée"; fi
expect "check --list : rc 0" 0 "$CHECK" --list

# 4d. --jobs : mêmes résultats qu'en série, plus rapide, ordre stable, FAIL conservé.
expect "--jobs 0 : rc 2" 2 "$CHECK" --static --jobs 0
expect "--jobs abc : rc 2" 2 "$CHECK" --static --jobs abc
expect "--jobs sans valeur : rc 2" 2 "$CHECK" --static --jobs
PAR="yamllint,shellcheck,actionlint"
t0="$(now_ms)"
env CHECK_ONLY="$PAR" FAKE_SLEEP=1 "$MINI" tools/dev/check --static --jobs 1 >"$W/serial.out" 2>&1 || true
t1="$(now_ms)"
env CHECK_ONLY="$PAR" FAKE_SLEEP=1 "$MINI" tools/dev/check --static --jobs 3 >"$W/par.out" 2>&1 || true
t2="$(now_ms)"
if [[ $((t1 - t0)) -ge 2800 && $((t2 - t1)) -lt $((t1 - t0)) && $((t2 - t1)) -lt 2500 ]]; then
  ok "--jobs 3 : $((t2 - t1)) ms contre $((t1 - t0)) ms en série"
else
  ko "--jobs 3 : $((t2 - t1)) ms contre $((t1 - t0)) ms en série (attendu : parallèle < 2,5 s, série >= 2,8 s)"
fi
if diff <(grep -E '^(PASS|FAIL|NOT_TESTED) ' "$W/serial.out" | awk '{print $1, $2}') \
  <(grep -E '^(PASS|FAIL|NOT_TESTED) ' "$W/par.out" | awk '{print $1, $2}') >/dev/null 2>&1; then
  ok "--jobs : mêmes statuts, même ordre qu'en série"
else
  ko "--jobs : statuts ou ordre différents de la série"
  sed 's/^/      | /' "$W/par.out"
fi
expect "--jobs : un FAIL reste rc 1, extrait conservé" 1 env CHECK_ONLY="$PAR" FAKE_FAIL=shellcheck "$MINI" tools/dev/check --static --jobs 3
out_has "  … FAIL shellcheck et son extrait" '^FAIL +shellcheck '
out_has "  … extrait du journal" 'shellcheck factice : echec demande'
expect "--jobs 2 : verdict identique au mode série" 0 env CHECK_ONLY="$PAR" "$MINI" tools/dev/check --static --jobs=2

# 4e. --json et reçu.
expect "--json : rc 0" 0 env CHECK_ONLY="$PAR" "$MINI" tools/dev/check --static --json
env CHECK_ONLY="$PAR" "$MINI" tools/dev/check --static --json 2>"$W/json.err" >"$W/json.out" || true
if python3 -I - "$W/json.out" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
steps = [r for r in rows if "name" in r]
last = rows[-1]
assert [s["name"] for s in steps] == ["shellcheck", "yamllint", "actionlint"], steps
assert all(s["status"] == "PASS" and s["level"] == "static" and isinstance(s["seconds"], (int, float)) for s in steps)
assert last["summary"] is True and last["result"] == "PASS" and last["pass"] == 3, last
PY
then ok "--json : stdout = une ligne JSON par contrôle + bilan"; else ko "--json : sortie invalide"; sed 's/^/      | /' "$W/json.out"; fi
if grep -q 'RESULT:' "$W/json.err" && ! grep -q 'RESULT:' "$W/json.out"; then ok "--json : texte lisible sur stderr seulement"; else ko "--json : texte lisible mal placé"; fi
env CHECK_ONLY="$PAR" FAKE_FAIL=yamllint "$MINI" tools/dev/check --static --json 2>/dev/null >"$W/json.fail" || true
if grep -q '"name":"yamllint","status":"FAIL"' "$W/json.fail" && grep -q '"result":"FAIL"' "$W/json.fail"; then ok "--json : un FAIL apparaît en JSON"; else ko "--json : FAIL absent"; sed 's/^/      | /' "$W/json.fail"; fi
env CHECK_ONLY=ruff-bugs PATH="$W/bin" "$CHECK" --static --json 2>/dev/null >"$W/json.nt" || true
if grep -q '"status":"NOT_TESTED"' "$W/json.nt" && ! grep -q '"status":"PASS"' "$W/json.nt"; then ok "--json : outil absent = NOT_TESTED, jamais PASS"; else ko "--json : NOT_TESTED attendu"; fi

rm -f "$W/receipt.json"
mini_reset
printf 'x = 1\n' >"$R/tools/x/ok.py"
HEAD_SHA="$(g rev-parse HEAD)"
env CHECK_ONLY="$PAR" "$MINI" tools/dev/check --static >/dev/null 2>&1 || true
if python3 -I - "$R/.git/check-receipt.json" "$HEAD_SHA" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
assert d["sha"] == sys.argv[2], d["sha"]
assert d["level"] == "static" and d["result"] == "PASS", d
assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", d["date"]), d["date"]
assert d["pass"] == 3 and d["fail"] == 0 and d["not_tested"] == 0, d
assert d["dirty"] is True, "un fichier non suivi existe : dirty attendu"
assert [s["name"] for s in d["steps"]] == ["shellcheck", "yamllint", "actionlint"]
assert d["only"] == "yamllint,shellcheck,actionlint"
PY
then ok "reçu : .git/check-receipt.json (SHA, niveau, résultats, date UTC, dirty)"; else ko "reçu invalide"; cat "$R/.git/check-receipt.json" 2>&1 | sed 's/^/      | /'; fi
if [[ -z "$(g status --porcelain | grep -F check-receipt || true)" ]]; then ok "reçu : hors de l'arbre suivi"; else ko "reçu visible dans l'arbre"; fi
mini_reset
env CHECK_ONLY="$PAR" FAKE_FAIL=shellcheck "$MINI" tools/dev/check --static >/dev/null 2>&1 || true
if grep -q '"result":"FAIL"' "$R/.git/check-receipt.json" && grep -q '"dirty":false' "$R/.git/check-receipt.json"; then ok "reçu : FAIL enregistré, arbre propre (dirty false)"; else ko "reçu FAIL attendu"; fi
env CHECK_ONLY=ruff-bugs PATH="$W/bin" "$MINI" tools/dev/check --static >/dev/null 2>&1 || true
env CHECK_ONLY=ruff-bugs CHECK_RECEIPT="$W/receipt.json" PATH="$W/bin" "$CHECK" --static >/dev/null 2>&1 || true
if grep -q '"result":"INCOMPLET"' "$W/receipt.json" && grep -q '"not_tested":1' "$W/receipt.json"; then ok "reçu : INCOMPLET et NOT_TESTED comptés (jamais PASS)"; else ko "reçu INCOMPLET attendu"; fi
env CHECK_ONLY=ruff-bugs RECEIPT_TO="$W/receipt.json" "$MINI" tools/dev/check --fast >/dev/null 2>&1 || true
if grep -q '"level":"fast"' "$W/receipt.json"; then ok "reçu : niveau fast"; else ko "reçu niveau fast attendu"; fi
env RECEIPT_TO="$W/receipt.json" CHECK_CHANGED_FILES="docs/a.md" CHECK_ONLY=gitleaks "$MINI" tools/dev/check --static --changed >/dev/null 2>&1 || true
if grep -q '"level":"static-changed"' "$W/receipt.json"; then ok "reçu : niveau static-changed"; else ko "reçu niveau static-changed attendu"; fi

# 4f. gitleaks : mêmes règles et même périmètre que le job `secrets` de ci.yaml (historique, config par défaut).
mini_reset
expect "gitleaks : appel du job secrets (git, config par défaut, valeurs masquées)" 0 env CHECK_ONLY=gitleaks "$MINI" tools/dev/check --static
if grep -Eq '^git --config [^ ]+ --redact --no-banner --log-level warn \.$' "$W/gl.args"; then ok "  … arguments : git --config <défaut> --redact ... ."; else ko "  … arguments inattendus : $(cat "$W/gl.args")"; fi
if [[ "$(cat "$W/gl.cfg")" == $'[extend]\nuseDefault = true' ]]; then ok "  … config = règles par défaut seules (pas .gitleaks.toml)"; else ko "  … config inattendue"; fi
# Depuis T-460 le job `secrets` appelle l'étape `gitleaks` de check (plus de commande inline) : on vérifie l'appel
# strict dans ci.yaml ET que l'appel gitleaks de check (git --config, useDefault) est celui testé ci-dessus.
if grep -q 'CHECK_ONLY="gitleaks" tools/dev/check --static --strict' .github/workflows/ci.yaml \
  && grep -q 'gitleaks git --config' tools/dev/check && grep -q 'useDefault = true' tools/dev/check; then ok "  … job secrets de ci.yaml = étape gitleaks de check (strict)"; else ko "  … ci.yaml n'appelle plus l'étape gitleaks de check, ou check a changé d'appel"; fi
expect "gitleaks : trouvaille = FAIL rc 1" 1 env CHECK_ONLY=gitleaks FAKE_FAIL=gitleaks "$MINI" tools/dev/check --static
out_has "  … FAIL gitleaks" '^FAIL +gitleaks '

# 4g. coverage et appgen-unittest : une seule exécution des tests appgen quand coverage tourne ; rien de perdu sinon.
if python3 -c 'import yaml, jsonschema, coverage, radon, mypy' >/dev/null 2>&1 && command -v ruff >/dev/null 2>&1; then
  env CHECK_ONLY=coverage,appgen-unittest "$CHECK" --static >"$W/out" 2>&1 || true
  if grep -Eq '^(PASS|FAIL) +coverage ' "$W/out"; then
    # coverage a tourné : appgen-unittest ne doit plus rejouer les mêmes tests.
    if grep -Eq '^(PASS|FAIL|NOT_TESTED) +appgen-unittest' "$W/out"; then ko "coverage a tourné : appgen-unittest ne doit pas rejouer les tests"; else ok "coverage actif : appgen-unittest fusionné"; fi
    out_has "  … fusion listée" 'hors périmètre \(1\) : appgen-unittest'
  else
    out_has "  … coverage NOT_TESTED (ruff non épinglé) : appgen-unittest tourne" '^(PASS|FAIL|NOT_TESTED) +appgen-unittest'
  fi
  env CHECK_ONLY=coverage,appgen-unittest CHECK_SKIP=coverage "$CHECK" --static >"$W/out" 2>&1 || true
  out_has "  … coverage exclu : appgen-unittest conservé" '^(PASS|FAIL|NOT_TESTED) +appgen-unittest'
  out_has "  … coverage exclu = NOT_TESTED" '^NOT_TESTED +coverage .*exclu'
else
  printf 'NOT_TESTED fusion coverage/appgen-unittest : outils absents ici (cas non exécuté)\n'
fi

expect "--k3d sans kubectl : NOT_TESTED" 0 env PATH="$W/bin" "$CHECK" --k3d
out_has "  … k3d NOT_TESTED (outil absent)" '^NOT_TESTED +k3d .*kubectl'

if [[ "$fails" -gt 0 ]]; then
  printf 'CHECK-TEST: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'CHECK-TEST: PASS\n'
