#!/usr/bin/env bash
# Test STATIQUE de tools/oke/verify.sh --all (T-487) : sans cluster. Extrait la boucle --all du script,
# l'exécute avec des v<N>() factices et vérifie que 6b n'est exécutée qu'avec --with-portal.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
V="$REPO/tools/oke/verify.sh"
fail=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fail=1; }

if bash -n "$V"; then ok "syntaxe verify.sh"; else ko "syntaxe verify.sh"; fi

# Bloc `--all) ... security;;` du dispatch final.
block="$(awk '/^  --all\)/{f=1} f{print} f&&/^    security;;/{exit}' "$V")"
[[ -n "$block" ]] || { ko "bloc --all introuvable"; exit 1; }

run_all() { # WITH_PORTAL(0|1) -> trace des étapes exécutées
  local script
  # shellcheck disable=SC2016  # le script est évalué par le bash fils, pas ici
  script='res() { echo "RES $1 $2"; }
security() { echo "CALL security"; }
for n in 0 1 2 3 4 5 6 6b 7 8 9 10 11; do eval "v$n() { echo CALL v$n; }"; done
case "--all" in
'"$block"'
esac'
  WITH_PORTAL="$1" bash -c "$script"
}

out="$(run_all 0)"
if grep -q '^CALL v6b$' <<<"$out"; then ko "sans --with-portal : v6b exécutée"; else ok "sans --with-portal : v6b non exécutée"; fi
if grep -q '^RES NOT_TESTED B6b-portal$' <<<"$out"; then ok "sans --with-portal : NOT_TESTED B6b-portal"; else ko "sans --with-portal : NOT_TESTED absent"; fi
if grep -qE '^RES (PASS|FAIL|BLOCKED) B6b' <<<"$out"; then ko "sans --with-portal : PASS/FAIL/BLOCKED B6b émis"; else ok "sans --with-portal : aucun PASS/FAIL/BLOCKED B6b"; fi
for n in 0 1 2 3 4 5 6 7 8 9 10 11; do
  grep -q "^CALL v$n\$" <<<"$out" || ko "v$n non exécutée"
done
if grep -q '^CALL security$' <<<"$out"; then ok "security exécutée"; else ko "security non exécutée"; fi

out="$(run_all 1)"
if grep -q '^CALL v6b$' <<<"$out"; then ok "avec --with-portal : v6b exécutée"; else ko "avec --with-portal : v6b non exécutée"; fi
if grep -q 'NOT_TESTED' <<<"$out"; then ko "avec --with-portal : NOT_TESTED émis"; else ok "avec --with-portal : pas de NOT_TESTED"; fi

# shellcheck disable=SC2016
if grep -qF -- '--step) declare -F "v$N"' "$V"; then ok "--step N inchangé (v6b atteignable)"; else ko "--step modifié"; fi
exit "$fail"
