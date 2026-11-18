#!/usr/bin/env bash
# Tests des hooks git locaux (SL-4, T-459) : tools/dev/setup et .pre-commit-config.yaml, SANS réseau, Docker ni cluster.
# Le test travaille dans une COPIE jetable de l'arbre (dépôt git temporaire) : le dépôt réel et ses hooks ne sont pas touchés.
#  1. Statique : aucun --no-verify hors commentaire (config, setup) ; tous les hooks sont `language: system` (aucun réseau).
#  2. Installation : setup installe pre-commit et pre-push ; une 2e exécution ne change rien (idempotence) ; --check
#     échoue sur un dépôt sans hooks (cas négatif).
#  3. Commits : un changement propre passe ; un commit fautif est REFUSÉ (ruff F821, YAML invalide, secret factice) et
#     l'index garde le fichier fautif sans commit créé (cas négatifs) ; durée du commit propre < 10 s.
# Outil absent (pre-commit, gitleaks, ruff, yamllint) : NOT_TESTED, rc 0 (la CI qui n'installe pas pre-commit ne casse pas).
# Usage : tests/dev-factory/precommit-test.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
export PATH="$HOME/.local/bin:$PATH"
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# ---- 1. statique ----
strip() { grep -v -E '^[[:space:]]*#' "$1"; }
for f in .pre-commit-config.yaml tools/dev/setup; do
  if strip "$f" | grep -q -- '--no-verify'; then ko "$f contient --no-verify hors commentaire"; else ok "$f : aucun --no-verify"; fi
done
if [[ "$(grep -c '^ *language:' .pre-commit-config.yaml)" -gt 0 ]] \
  && [[ "$(grep '^ *language:' .pre-commit-config.yaml | grep -vc 'language: system')" -eq 0 ]] \
  && ! grep -Eq '^ *- repo: (https?|git)' .pre-commit-config.yaml; then
  ok "hooks tous 'language: system', aucun dépôt distant"
else
  ko "un hook n'est pas 'language: system' ou un dépôt distant est déclaré"
fi

missing=""
for t in pre-commit gitleaks ruff yamllint shellcheck actionlint; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
if [[ -n "$missing" ]]; then
  printf 'NOT_TESTED hooks git (outils absents :%s)\n' "$missing"
  [[ "$fails" -eq 0 ]] && { echo 'PRECOMMIT-TEST: NOT_TESTED (statique PASS)'; exit 0; }
  echo "PRECOMMIT-TEST: FAIL ($fails)"
  exit 1
fi

W="$(mktemp -d "${TMPDIR:-/tmp}/precommit-test.XXXXXX")"
trap 'rm -rf "$W"' EXIT
export PRE_COMMIT_HOME="$W/pc-cache"
export CHECK_RECEIPT="$W/receipt.json"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=noreply@anthropic.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=noreply@anthropic.com

# Copie de l'arbre (suivi + nouveaux fichiers non ignorés) dans un dépôt temporaire, commit initial SANS hooks.
R="$W/repo"
mkdir -p "$R"
git ls-files -co --exclude-standard -z | tar --null -T - -cf - | tar -xf - -C "$R"
(
  cd "$R" && git init -q -b main . && git add -A && git commit -q -m "base" --no-gpg-sign
) || { ko "préparation du dépôt temporaire"; exit 1; }
cd "$R" || exit 2
hooks="$(git rev-parse --git-path hooks)"

# ---- 2. installation ----
if tools/dev/setup --check >"$W/out" 2>&1; then ko "setup --check réussit sans hooks installés"; else ok "setup --check échoue sans hooks (cas négatif)"; fi
if tools/dev/setup >"$W/out" 2>&1; then ok "setup installe les hooks"; else ko "setup a échoué"; sed 's/^/      | /' "$W/out"; fi
if [[ -f "$hooks/pre-commit" && -f "$hooks/pre-push" ]]; then ok "hooks pre-commit et pre-push présents"; else ko "hooks absents"; fi
h1="$(sha256sum "$hooks/pre-commit" "$hooks/pre-push")"
tools/dev/setup >"$W/out" 2>&1
h2="$(sha256sum "$hooks/pre-commit" "$hooks/pre-push")"
if [[ "$h1" == "$h2" ]]; then ok "setup idempotent (hooks identiques après 2e exécution)"; else ko "setup non idempotent"; fi

# ---- 3. commits ----
mkdir -p tools/dev/_t
commit_try() { # NOM FICHIER CONTENU ATTENDU(pass|fail) [MOTIF du hook en échec]
  local name="$1" file="$2" content="$3" want="$4" why="${5:-}" rc=0 before after
  printf '%s\n' "$content" >"$file"
  git add "$file"
  before="$(git rev-parse HEAD)"
  git commit -q -m "test: $name" --no-gpg-sign >"$W/out" 2>&1 || rc=$?
  after="$(git rev-parse HEAD)"
  if [[ "$want" == pass ]]; then
    if [[ "$rc" -eq 0 && "$before" != "$after" ]]; then ok "commit accepté : $name"; else ko "commit refusé à tort : $name (rc=$rc)"; sed 's/^/      | /' "$W/out"; fi
  else
    if [[ "$rc" -ne 0 && "$before" == "$after" ]] && { [[ -z "$why" ]] || grep -Eq "$why" "$W/out"; }; then ok "commit refusé : $name"; else ko "commit fautif accepté : $name (rc=$rc)"; sed 's/^/      | /' "$W/out"; fi
    git reset -q HEAD -- "$file"
    rm -f "$file"
  fi
}

t0=$(date +%s%N)
commit_try "python propre" tools/dev/_t/ok.py 'print("ok")' pass
t1=$(date +%s%N)
ms=$(((t1 - t0) / 1000000))
if [[ "$ms" -lt 10000 ]]; then ok "durée du commit propre ${ms} ms < 10 s"; else ko "durée du commit propre ${ms} ms >= 10 s"; fi

commit_try "ruff : nom indéfini (F821)" tools/dev/_t/bad.py 'print(nom_indefini)' fail 'check --file.*Failed'
commit_try "yaml invalide" tools/dev/_t/bad.yaml $'a: [1, 2\nb: : :' fail 'check --file.*Failed'
# Secret factice construit à l'exécution : aucune valeur de forme secrète n'est écrite dans le dépôt.
fake="ghp_$(python3 -I -c 'import random,string; r=random.SystemRandom(); print("".join(r.choice(string.ascii_letters+string.digits) for _ in range(36)))')"
commit_try "secret factice (jeton GitHub)" tools/dev/_t/secret.txt "token = ${fake}" fail 'gitleaks \(index\).*Failed'
commit_try "shell : variable non citée (shellcheck)" tools/dev/_t/bad.sh $'#!/usr/bin/env bash\nrm -rf $1/*\ncd $HOME\n' fail 'check --file.*Failed'

if [[ "$fails" -gt 0 ]]; then
  printf 'PRECOMMIT-TEST: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'PRECOMMIT-TEST: PASS\n'
