#!/usr/bin/env bash
# Tests statiques du gouverneur (T-311) : kill-switch factory/PAUSE, matrice, concordance max-parallel / config.yaml.
# Aucun reseau, aucun cluster, aucun secret. Usage : tests/factory/pause-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/factory-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
# expect NOM CODE_ATTENDU commande... : verifie le code de sortie.
expect() {
  local name="$1" want="$2" rc=0
  shift 2
  "$@" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then ok "$name"; else ko "$name (code $rc, attendu $want)"; sed 's/^/  /' "$W/out"; fi
}

# Copie isolee : les scripts font cd vers leur depot, on teste donc sur un depot jetable.
mkdir -p "$W/repo/factory"
cp "$ROOT/factory/pause-check.sh" "$ROOT/factory/plan-matrix.sh" "$W/repo/factory/"
cd "$W/repo"
git init -q -b main .
git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m base

# 1. Kill-switch dans l'arbre de travail.
expect "sans PAUSE : usine active" 0 factory/pause-check.sh
: >factory/PAUSE
expect "PAUSE present : arret (code 10)" 10 factory/pause-check.sh
GITHUB_OUTPUT="$W/gh-out" factory/pause-check.sh >/dev/null 2>&1 || true
if grep -qx 'paused=true' "$W/gh-out"; then ok "sortie paused=true ecrite"; else ko "sortie paused=true absente"; fi
rm factory/PAUSE
GITHUB_OUTPUT="$W/gh-out2" factory/pause-check.sh >/dev/null 2>&1
if grep -qx 'paused=false' "$W/gh-out2"; then ok "sortie paused=false ecrite"; else ko "sortie paused=false absente"; fi

# 2. Kill-switch lu dans une ref (origin/main) : la branche de travail ne contourne pas la pause.
: >factory/PAUSE
git add factory/PAUSE
git -c user.name=t -c user.email=t@example.invalid commit -q -m pause
git update-ref refs/remotes/origin/main HEAD
rm factory/PAUSE
git rm -q --cached factory/PAUSE
git -c user.name=t -c user.email=t@example.invalid commit -q -m "branche sans PAUSE"
expect "PAUSE sur origin/main, absente de la branche : arret" 10 env PAUSE_REF=origin/main factory/pause-check.sh
expect "meme branche sans PAUSE_REF : active" 0 factory/pause-check.sh

# 3. Matrice : 5 dispatchs -> 5 entrees, dedoublonnage, entrees invalides refusees.
out="$(TICKETS="11, 12 13,14,15" factory/plan-matrix.sh)"
if [[ "$out" == '{"issue":[11,12,13,14,15]}' ]]; then ok "5 issues -> 5 entrees de matrice"; else ko "matrice inattendue : $out"; fi
out="$(TICKETS="7,7,8" factory/plan-matrix.sh)"
if [[ "$out" == '{"issue":[7,8]}' ]]; then ok "doublons retires"; else ko "doublons : $out"; fi
out="$(TICKETS="" EVENT_ISSUE=42 factory/plan-matrix.sh)"
if [[ "$out" == '{"issue":[42]}' ]]; then ok "evenement label : une entree"; else ko "evenement : $out"; fi
expect "jeton non numerique refuse" 2 env TICKETS='1;rm -rf /' factory/plan-matrix.sh
expect "liste vide refusee" 2 env TICKETS='' EVENT_ISSUE='' factory/plan-matrix.sh
expect "plus de 20 issues refuse" 2 env TICKETS="$(seq -s, 1 21)" factory/plan-matrix.sh

# 4. Concordance : max-parallel du workflow = max_parallel de config.yaml = 3 ; aucun groupe de concurrence unique.
cd "$ROOT"
wf=.github/workflows/claude-agent.yml
mp="$(sed -n 's/^ *max-parallel: *\([0-9][0-9]*\) *$/\1/p' "$wf")"
cfg="$(sed -n 's/^ *max_parallel: *\([0-9][0-9]*\) *$/\1/p' factory/config.yaml)"
if [[ "$mp" == "3" && "$cfg" == "3" ]]; then ok "max-parallel workflow = config = 3"; else ko "max-parallel workflow='$mp' config='$cfg'"; fi
# Un groupe de concurrence sans matrice.issue annulerait ou bloquerait des runs : tout groupe doit etre indexe par issue.
bad="$(grep -E '^ *group:' "$wf" | grep -v 'matrix.issue' || true)"
if [[ -z "$bad" ]]; then ok "aucun groupe de concurrence unique"; else ko "groupe non indexe : $bad"; fi
if grep -q 'factory/pause-check.sh' "$wf" && grep -q "paused == 'false'" "$wf"; then ok "workflow branche sur le kill-switch"; else ko "workflow non branche sur le kill-switch"; fi

if [[ "$fails" -gt 0 ]]; then
  printf '%s test(s) en echec\n' "$fails"
  exit 1
fi
echo "tous les tests du gouverneur passent"
