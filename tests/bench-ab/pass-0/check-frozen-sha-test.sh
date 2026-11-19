#!/usr/bin/env bash
# Test hors ligne de check-frozen-sha.sh (T-501) sur un dépôt Git jetable : commit vierge = PASS, commit avec
# apps/miniflux, apps/echo-bench ou leur sortie generated/ = FAIL, entrées invalides = code 2. Aucun réseau.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/check-frozen-sha.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/bench-frozen.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
expect() { # NOM CODE commande...
  local name="$1" want="$2" rc=0
  shift 2
  "$@" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then ok "$name"; else ko "$name (code $rc, attendu $want)"; sed 's/^/  /' "$W/out"; fi
}

R="$W/repo"
git init -q "$R"
g() { git -C "$R" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
mkdir -p "$R/apps/ntfy" "$R/apps/whoami" "$R/generated/namespaces/default/projects/ntfy"
echo a >"$R/apps/ntfy/app.yaml"
echo a >"$R/apps/whoami/app.yaml"
echo a >"$R/generated/namespaces/default/projects/ntfy/project.yaml"
g add -A && g commit -q -m clean
clean="$(g rev-parse HEAD)"

mkdir -p "$R/apps/miniflux"
echo a >"$R/apps/miniflux/app.yaml"
g add -A && g commit -q -m miniflux
mini="$(g rev-parse HEAD)"

mkdir -p "$R/generated/namespaces/default/projects/echo-bench"
echo a >"$R/generated/namespaces/default/projects/echo-bench/project.yaml"
g rm -rq apps/miniflux && g add -A && g commit -q -m gen-only
genonly="$(g rev-parse HEAD)"

expect "arbre vierge" 0 "$SCRIPT" "$clean" --repo-dir "$R"
expect "apps/miniflux présent" 1 "$SCRIPT" "$mini" --repo-dir "$R"
if grep -q "apps/miniflux/app.yaml" "$W/out"; then ok "chemin fautif listé"; else ko "chemin fautif listé"; fi
expect "generated/ d'echo-bench présent" 1 "$SCRIPT" "$genonly" --repo-dir "$R"
expect "SHA court refusé" 2 "$SCRIPT" "${clean:0:7}" --repo-dir "$R"
expect "branche refusée" 2 "$SCRIPT" main --repo-dir "$R"
expect "SHA inconnu" 2 "$SCRIPT" 0000000000000000000000000000000000000000 --repo-dir "$R"
expect "sans argument" 2 "$SCRIPT" --repo-dir "$R"

# Un nom voisin ne doit pas déclencher : « miniflux-doc » reste signalé (préfixe), « myminiflux » non.
mkdir -p "$R/apps/myminiflux" && echo a >"$R/apps/myminiflux/app.yaml"
g add -A && g commit -q -m neighbor
g rm -rq generated/namespaces/default/projects/echo-bench && g commit -q -m rm-gen
expect "nom voisin sans faux positif" 0 "$SCRIPT" "$(g rev-parse HEAD)" --repo-dir "$R"

if [[ "$fails" -eq 0 ]]; then printf 'OK\n'; else printf '%s échec(s)\n' "$fails"; exit 1; fi
