#!/usr/bin/env bash
# Test hors ligne de admin-password.sh (T-501) avec un faux client cluster : la valeur ne doit être ni en argument, ni sur
# la sortie, et un Secret existant ne doit pas être remplacé. Aucun cluster, aucun réseau.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/admin-password.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/bench-adminpw.XXXXXX")"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin"
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# Faux client : journalise ses arguments ; `get secret -o name` réussit si $W/exists ; `create` garde stdin.
cat >"$W/bin/kubectl" <<'F'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG"
case "$*" in
  *"get secret"*"-o name"*) [[ -e "$FAKE_DIR/exists" ]] && exit 0 || exit 1 ;;
  *"get secret"*jsonpath*) printf '%s' "$FAKE_B64" ;;
  *"create secret"*) cat >"$FAKE_DIR/stdin" ;;
esac
F
chmod +x "$W/bin/kubectl"
export PATH="$W/bin:$PATH" FAKE_DIR="$W" FAKE_LOG="$W/log"
: >"$W/log"

rc=0
"$SCRIPT" seed >"$W/out" 2>&1 || rc=$?
if [[ $rc -eq 2 ]]; then ok "contexte obligatoire"; else ko "contexte obligatoire (code $rc)"; fi

"$SCRIPT" seed --context ctx-test --dry-run >"$W/out" 2>&1
if grep -q "dry-run" "$W/out" && ! grep -q "create secret" "$W/log"; then ok "dry-run ne crée rien"; else ko "dry-run ne crée rien"; fi

"$SCRIPT" seed --context ctx-test >"$W/out" 2>&1
value="$(cat "$W/stdin")"
if [[ ${#value} -ge 40 ]]; then ok "valeur aléatoire non triviale (${#value} car.)"; else ko "valeur trop courte"; fi
if grep -q -- "--context ctx-test" "$W/log" && grep -q -- "--from-file=MINIFLUX_ADMIN_PASSWORD=/dev/stdin" "$W/log"; then
  ok "contexte explicite, clé, stdin"
else ko "arguments du client"; fi
if grep -Fq -- "$value" "$W/log" "$W/out"; then ko "valeur absente des arguments et de la sortie"; else ok "valeur absente des arguments et de la sortie"; fi

"$SCRIPT" seed --context ctx-test >/dev/null 2>&1
if [[ "$(cat "$W/stdin")" != "$value" ]]; then ok "valeur différente à chaque création"; else ko "valeur différente à chaque création"; fi

touch "$W/exists"
: >"$W/stdin"
"$SCRIPT" seed --context ctx-test >"$W/out" 2>&1
if [[ ! -s "$W/stdin" ]] && grep -q "déjà présent" "$W/out"; then ok "Secret existant conservé"; else ko "Secret existant conservé"; fi

# exec : la valeur arrive dans l'environnement de la commande, rien d'autre n'est affiché.
FAKE_B64="$(printf 'valeur-factice-test' | base64)"
export FAKE_B64
"$SCRIPT" exec --context ctx-test -- bash -c 'test "$MINIFLUX_ADMIN_PASSWORD" = valeur-factice-test && echo env-ok' >"$W/out" 2>&1
if [[ "$(cat "$W/out")" == "env-ok" ]]; then ok "exec : variable posée"; else ko "exec : variable posée"; fi
rm "$W/exists"
rc=0
"$SCRIPT" exec --context ctx-test -- true >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 3 ]]; then ok "exec : Secret absent = code 3"; else ko "exec : Secret absent (code $rc)"; fi

if [[ "$fails" -eq 0 ]]; then printf 'OK\n'; else printf '%s échec(s)\n' "$fails"; exit 1; fi
