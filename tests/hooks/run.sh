#!/usr/bin/env bash
# T-331 : tests des hooks Claude Code de .claude/hooks/ (SL-5). Une entrée JSON par cas dans tests/hooks/cases/ :
#   { "name", "hook", "stdin": {…JSON d'entrée du hook…}, "env": {…}, "expect": <code de sortie>,
#     "fixture": {"path","content"}, "leak_fixture": "<chemin>", "needs": "<outil>",
#     "stdout_contains": "<texte>", "budget_seconds": <n> }
# `hook` : bash-guard | scope-guard | post-edit | stop | session-start. `@ROOT@` dans stdin = racine du dépôt.
# Chaque cas lance le vrai script avec l'entrée sur stdin et compare le code de sortie (cas autorisés ET refusés).
# Les fixtures vivent dans apps/_hooktest/ (supprimé en sortie) ; la fuite factice est composée à l'exécution.
# Sortie : une ligne PASS / FAIL / NOT_TESTED par cas, bilan, rc 1 s'il y a un FAIL. Aucun secret, aucun réseau.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
ROOT="$PWD"
command -v jq >/dev/null 2>&1 || { echo "NOT_TESTED jq introuvable" >&2; exit 2; }
declare -A HOOK=(
  [bash-guard]=pretool-bash-guard.sh [scope-guard]=pretool-scope-guard.sh [post-edit]=post-edit-check.sh
  [stop]=stop-check.sh [session-start]=session-start.sh
)
pass=0 fail=0 nt=0
FIX="$ROOT/apps/_hooktest"
cleanup() { rm -rf "$FIX"; }
trap cleanup EXIT
cleanup

for cf in tests/hooks/cases/*.json; do
  name="$(jq -r .name "$cf")"
  hook="$(jq -r .hook "$cf")"
  want="$(jq -r .expect "$cf")"
  script=".claude/hooks/${HOOK[$hook]:-}"
  if [[ ! -x "$script" ]]; then printf 'FAIL        %s : script introuvable (%s)\n' "$name" "$script"; fail=$((fail + 1)); continue; fi
  need="$(jq -r '.needs // empty' "$cf")"
  if [[ -n "$need" ]] && ! command -v "$need" >/dev/null 2>&1; then
    printf 'NOT_TESTED  %s : %s absent\n' "$name" "$need"; nt=$((nt + 1)); continue
  fi
  cleanup
  if jq -e '.fixture' "$cf" >/dev/null 2>&1 && [[ "$(jq -r '.fixture' "$cf")" != null ]]; then
    p="$ROOT/$(jq -r .fixture.path "$cf")"
    mkdir -p "$(dirname "$p")"
    jq -j .fixture.content "$cf" >"$p"
  fi
  lf="$(jq -r '.leak_fixture // empty' "$cf")"
  if [[ -n "$lf" ]]; then
    mkdir -p "$(dirname "$ROOT/$lf")"
    # Adresse IPv4 privée composée à l'exécution (aucun littéral dans le dépôt).
    printf 'host=%s.%s.%s.%s\n' 172 16 3 9 >"$ROOT/$lf"
  fi
  envargs=()
  while IFS= read -r kv; do [[ -n "$kv" ]] && envargs+=("$kv"); done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "$cf")
  stdin="$(jq -c .stdin "$cf" | sed "s#@ROOT@#$ROOT#g")"
  t0=$(date +%s%N)
  out="$(printf '%s' "$stdin" | env -u LAB_COORDINATOR_SESSION -u AGENT_TICKET_SCOPE -u AGENT_TICKET_ID \
    CLAUDE_PROJECT_DIR="$ROOT" "${envargs[@]}" "$script" 2>"$FIX.err")"
  rc=$?
  secs=$((($(date +%s%N) - t0) / 1000000))
  rm -f "$FIX.err"
  ok=1
  [[ "$rc" == "$want" ]] || ok=0
  contains="$(jq -r '.stdout_contains // empty' "$cf")"
  if [[ -n "$contains" && "$out" != *"$contains"* ]]; then ok=0; fi
  budget="$(jq -r '.budget_seconds // empty' "$cf")"
  if [[ -n "$budget" && "$secs" -ge $((budget * 1000)) ]]; then ok=0; fi
  if [[ "$ok" == 1 ]]; then
    printf 'PASS        %s (rc %s, %s ms)\n' "$name" "$rc" "$secs"; pass=$((pass + 1))
  else
    printf 'FAIL        %s : rc %s (attendu %s), %s ms\n' "$name" "$rc" "$want" "$secs"; fail=$((fail + 1))
  fi
done
cleanup
echo "-- hooks : PASS=$pass FAIL=$fail NOT_TESTED=$nt"
[[ "$fail" -eq 0 ]]
