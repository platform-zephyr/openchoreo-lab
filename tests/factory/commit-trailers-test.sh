#!/usr/bin/env bash
# shellcheck disable=SC2016 # les scripts `bash -c '...'` recoivent leurs valeurs en arguments ($1, $2).
# Tests hors ligne du hook des trailers (T-474) : tools/factory/commit-trailers.sh dans des depots git temporaires,
# garde Bash (--no-verify, -n) et structure de .github/workflows/claude-agent.yml. Aucun reseau, aucun secret.
# Usage : tests/factory/commit-trailers-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="${WORKFLOW:-$ROOT/.github/workflows/claude-agent.yml}"  # WORKFLOW : copie mutee (test du test)
SCRIPT="$ROOT/tools/factory/commit-trailers.sh"
GUARD="$ROOT/.claude/hooks/pretool-bash-guard.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/commit-trailers-tests.XXXXXX")"
trap 'chmod -R u+w "$W" 2>/dev/null; rm -rf "$W"' EXIT
export PYTHONDONTWRITEBYTECODE=1
# Depots isoles de la configuration de l'utilisateur (signature, hooks globaux, alias).
export HOME="$W/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null TMPDIR="$W"
mkdir -p "$HOME"
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE 2>/dev/null || true
export GIT_AUTHOR_NAME=Claude GIT_AUTHOR_EMAIL=noreply@anthropic.com GIT_COMMITTER_NAME=Claude GIT_COMMITTER_EMAIL=noreply@anthropic.com
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else ko "$name"; fi; }

SESSION="https://github.com/o/r/actions/runs/123"
inst() { # inst <dir> [ESCALATED_FROM] : installation nominale
  TICKET_ID=T-474 MODEL=claude-opus-5-5 EFFORT=high CLAUDE_SESSION="$SESSION" ESCALATED_FROM="${2:-}" \
    "$SCRIPT" install "$1" >/dev/null
}
newrepo() { rm -rf "$1"; git init -q -b main "$1"; git -C "$1" config core.hooksPath "$2"; }
trailers() { git -C "$1" log -1 --format=%B "${2:-HEAD}" | git interpret-trailers --parse --no-divider; }
count() { grep -c "^$2:" <<<"$1" || true; }

# 1. Cas negatifs de l'installation : variable absente ou invalide => code 2, message explicite, rien d'installe.
neg() {
  local name="$1" want="$2"; shift 2
  local out rc=0
  out="$(env "$@" "$SCRIPT" install "$W/neg" 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$out" == *"$want"* && ! -e "$W/neg/prepare-commit-msg" ]]; then ok "$name"; else ko "$name (rc=$rc : $out)"; fi
}
neg "install : TICKET_ID absent => echec explicite" "TICKET_ID absente" -u TICKET_ID MODEL=claude-opus-5-5 EFFORT=high CLAUDE_SESSION="$SESSION"
neg "install : MODEL absent => echec explicite" "MODEL absente" -u MODEL TICKET_ID=T-1 EFFORT=high CLAUDE_SESSION="$SESSION"
neg "install : EFFORT absent => echec explicite" "EFFORT absente" TICKET_ID=T-1 MODEL=claude-opus-5-5 EFFORT= CLAUDE_SESSION="$SESSION"
neg "install : CLAUDE_SESSION absent => echec explicite" "CLAUDE_SESSION absente" -u CLAUDE_SESSION TICKET_ID=T-1 MODEL=claude-opus-5-5 EFFORT=high
neg "install : ticket invalide (issue nue) => refus" "TICKET_ID invalide" TICKET_ID=74 MODEL=claude-opus-5-5 EFFORT=high CLAUDE_SESSION="$SESSION"
neg "install : effort invalide => refus" "EFFORT invalide" TICKET_ID=T-1 MODEL=claude-opus-5-5 EFFORT=huge CLAUDE_SESSION="$SESSION"
neg "install : URL de session non https => refus" "CLAUDE_SESSION invalide" TICKET_ID=T-1 MODEL=claude-opus-5-5 EFFORT=high CLAUDE_SESSION="http://x/y"
neg "install : valeur multi-lignes => refus" "MODEL invalide" TICKET_ID=T-1 "MODEL=claude-opus-5-5
Ticket: T-9" EFFORT=high CLAUDE_SESSION="$SESSION"
neg "install : ESCALATED_FROM invalide => refus" "ESCALATED_FROM invalide" TICKET_ID=T-1 MODEL=claude-opus-5-5 EFFORT=high CLAUDE_SESSION="$SESSION" ESCALATED_FROM="gpt"

# 2. Installation nominale : hooks et valeurs sans droit d'ecriture.
H="$W/hooks"
inst "$H" claude-sonnet-5-5
check "install : prepare-commit-msg et commit-msg 0555, valeurs 0444, repertoire 0555" bash -c '
  [[ "$(stat -c %a "$1/prepare-commit-msg")" == 555 && "$(stat -c %a "$1/commit-msg")" == 555 ]] &&
  [[ "$(stat -c %a "$1/trailers.values")" == 444 && "$(stat -c %a "$1")" == 555 ]]' _ "$H"
check "install : reinstallation idempotente (repertoire deja verrouille)" inst "$H" claude-sonnet-5-5

R="$W/repo"
EXPECT_ORDER="Ticket Model Effort Escalated-from Claude-Session"
order_ok() { # order_ok <trailers> <cles attendues dans l'ordre>
  local got; got="$(sed -n 's/^\([A-Za-z-]*\):.*/\1/p' <<<"$1" | tr '\n' ' ' | sed 's/ $//')"
  [[ "$got" == "$2" ]] || { echo "ordre obtenu : $got" >&2; return 1; }
}
values_ok() {
  grep -qx "Ticket: T-474" <<<"$1" && grep -qx "Model: claude-opus-5-5" <<<"$1" && grep -qx "Effort: high" <<<"$1" &&
    grep -qx "Escalated-from: claude-sonnet-5-5" <<<"$1" && grep -qx "Claude-Session: $SESSION" <<<"$1"
}
judge() { (cd "$1" && "$ROOT/tools/factory/run-ticket.sh" check-trailers "${2:-HEAD~1..HEAD}" 2>&1); }

# 3. Commit sans trailers.
newrepo "$R" "$H"
echo a >"$R/a"; git -C "$R" add a
git -C "$R" commit -q -m "base"
echo b >"$R/b"; git -C "$R" add b
git -C "$R" commit -q -m "feat: sans trailers"
T="$(trailers "$R")"
check "sans trailers : les 5 trailers ajoutes, valeurs du workflow" values_ok "$T"
check "sans trailers : ordre Ticket, Model, Effort, Escalated-from, Claude-Session" order_ok "$T" "$EXPECT_ORDER"
check "sans trailers : check-trailers PASS" judge "$R"
check "identite : auteur et committer noreply@anthropic.com" \
  test "$(git -C "$R" log -1 --format='%ae %ce')" = "noreply@anthropic.com noreply@anthropic.com"

# 4. Trailers partiels : pas de doublon, Co-Authored-By garde, valeur fausse remplacee sur place.
echo c >"$R/c"; git -C "$R" add c
git -C "$R" commit -q -F - <<'EOF'
fix: trailers partiels

Corps du message.

Ticket: T-474
Model: claude-haiku-5-5
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
T="$(trailers "$R")"
check "partiels : un seul Ticket, un seul Model" test "$(count "$T" Ticket)$(count "$T" Model)" = "11"
check "partiels : valeur fausse remplacee par la valeur du workflow" values_ok "$T"
check "partiels : Co-Authored-By garde, trailers du workflow a la fin dans l'ordre canonique" order_ok "$T" \
  "Co-Authored-By $EXPECT_ORDER"

echo c2 >"$R/c2"; git -C "$R" add c2
git -C "$R" commit -q -F - <<'EOF'
fix: trailers en double

Ticket: T-1
Ticket: T-2
Effort: low
EOF
T="$(trailers "$R")"
check "doublons de l'agent : un seul Ticket et un seul Effort apres le hook" test "$(count "$T" Ticket)$(count "$T" Effort)" = "11"
check "doublons de l'agent : valeurs du workflow" values_ok "$T"

# 5. Message multi-lignes avec une ligne --- (pas un patch : --no-divider).
echo d >"$R/d"; git -C "$R" add d
git -C "$R" commit -q -F - <<'EOF'
docs: message multi-lignes

Premier paragraphe
sur deux lignes.

---
Une ligne de separation n'est pas la fin du message.

- point 1
- point 2
EOF
T="$(trailers "$R")"
check "multi-lignes : trailers dans le dernier paragraphe, ordre attendu" order_ok "$T" "$EXPECT_ORDER"
check "multi-lignes : corps conserve" bash -c 'git -C "$1" log -1 --format=%B | grep -q "^- point 2$"' _ "$R"
check "multi-lignes : check-trailers PASS" judge "$R"

# 6. Commit vide (--allow-empty) et message avec commentaires de l'editeur.
git -C "$R" commit -q --allow-empty -m "chore: commit vide"
check "commit vide (--allow-empty) : trailers ajoutes" values_ok "$(trailers "$R")"
GIT_EDITOR=true git -C "$R" commit -q --allow-empty -e -m "chore: via l'editeur"
T="$(trailers "$R")"
check "editeur (commentaires) : trailers presents une fois" bash -c '[[ "$(grep -c "^Ticket:" <<<"$1")" == 1 ]]' _ "$T"
check "editeur : aucun commentaire dans le message" bash -c '! git -C "$1" log -1 --format=%B | grep -q "^#"' _ "$R"

# 7. Message vide : git annule le commit (le hook ne fabrique pas un message de trailers seuls).
head="$(git -C "$R" rev-parse HEAD)"
check "message vide : commit annule" bash -c '! git -C "$1" commit -q --allow-empty -m "" 2>/dev/null' _ "$R"
check "message vide : HEAD inchange" test "$(git -C "$R" rev-parse HEAD)" = "$head"

# 8. --amend : pas de doublon.
git -C "$R" commit -q --amend --allow-empty --no-edit
T="$(trailers "$R")"
check "amend : un seul exemplaire de chaque trailer" test \
  "$(count "$T" Ticket)$(count "$T" Model)$(count "$T" Effort)$(count "$T" Escalated-from)$(count "$T" Claude-Session)" = "11111"

# 9. --no-verify : commit-msg saute, prepare-commit-msg tourne quand meme (githooks(5)).
git -C "$R" commit -q --allow-empty --no-verify -m "chore: no-verify"
check "--no-verify : trailers ajoutes par prepare-commit-msg" values_ok "$(trailers "$R")"

# 10. Merge commit (--no-ff) : trailers sur le commit de fusion.
git -C "$R" switch -q -c topic
echo e >"$R/e"; git -C "$R" add e
git -C "$R" commit -q -m "feat: branche"
git -C "$R" switch -q main
echo f >"$R/f"; git -C "$R" add f
git -C "$R" commit -q -m "feat: main"
GIT_EDITOR=true git -C "$R" merge -q --no-ff --no-edit topic
check "merge : commit a deux parents" test "$(git -C "$R" rev-list --parents -n 1 HEAD | wc -w)" = "3"
T="$(trailers "$R")"
check "merge : trailers ajoutes dans l'ordre" order_ok "$T" "$EXPECT_ORDER"
check "merge : toute la branche passe check-trailers" judge "$R" "$(git -C "$R" rev-list --max-parents=0 HEAD)..HEAD"

# 11. Identite : un auteur ou un committer autre que noreply est refuse.
head="$(git -C "$R" rev-parse HEAD)"
check "identite : --author autre e-mail => commit refuse" bash -c \
  '! git -C "$1" commit -q --allow-empty --author="X <x@example.com>" -m "chore: autre auteur" 2>/dev/null' _ "$R"
check "identite : committer autre e-mail => commit refuse" bash -c \
  '! GIT_COMMITTER_EMAIL=x@example.com git -C "$1" commit -q --allow-empty -m "chore: autre committer" 2>/dev/null' _ "$R"
check "identite : HEAD inchange apres les refus" test "$(git -C "$R" rev-parse HEAD)" = "$head"

# 12. Hook sans fichier de valeurs ou avec une valeur alteree : echec explicite.
H2="$W/hooks-novalues"; mkdir -p "$H2"
cp "$SCRIPT" "$H2/prepare-commit-msg"; cp "$SCRIPT" "$H2/commit-msg"
R2="$W/repo2"; newrepo "$R2" "$H2"
out="$(git -C "$R2" commit --allow-empty -m "x" 2>&1)" && rc=0 || rc=$?
check "hook sans valeurs : commit refuse avec message explicite" bash -c '[[ "$1" -ne 0 && "$2" == *"fichier de valeurs absent"* ]]' _ "$rc" "$out"
printf 'TICKET_ID=T-474\nMODEL=claude-opus-5-5\nEFFORT=high\nCLAUDE_SESSION=\n' >"$H2/trailers.values"
out="$(git -C "$R2" commit --allow-empty -m "x" 2>&1)" && rc=0 || rc=$?
check "hook avec CLAUDE_SESSION vide : commit refuse" bash -c '[[ "$1" -ne 0 && "$2" == *"CLAUDE_SESSION absente ou invalide"* ]]' _ "$rc" "$out"
check "hook : l'environnement de l'agent ne change pas les valeurs" bash -c '
  R3="$1/repo3"; git init -q "$R3"; git -C "$R3" config core.hooksPath "$2"
  TICKET_ID=T-999 MODEL=claude-haiku-5-5 git -C "$R3" commit -q --allow-empty -m "x"
  git -C "$R3" log -1 --format=%B | grep -qx "Ticket: T-474"' _ "$W" "$H"

# 13. Sans Escalated-from : pas de trailer vide.
H3="$W/hooks-noesc"; inst "$H3"
R4="$W/repo4"; newrepo "$R4" "$H3"
git -C "$R4" commit -q --allow-empty -m "chore: sans escalade"
T="$(trailers "$R4")"
check "sans ESCALATED_FROM : pas de trailer Escalated-from" order_ok "$T" "Ticket Model Effort Claude-Session"

# 14. Garde Bash (T-331) : --no-verify et -n restent refuses ; un commit normal passe. Limite connue de la garde :
# `git -C <dir> commit --no-verify` passe (option a argument) ; le hook prepare-commit-msg tourne quand meme (cas 9).
guard() { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | "$GUARD" >/dev/null 2>&1; }
for c in 'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -anm x'; do
  if guard "$c"; then ko "garde Bash : '$c' accepte"; else ok "garde Bash : refuse '$c'"; fi
done
check "garde Bash : autorise 'git commit -am x'" guard 'git commit -am x'

# 15. Structure du workflow : installation avant l'etape claude, valeurs du workflow, jamais d'un secret.
if python3 -I - "$WF" <<'PY'; then ok "workflow : hook installe avant l'etape claude, valeurs sans secret"; else ko "workflow : structure T-474"; fi
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
dev = wf["jobs"]["dev"]
env = dev.get("env") or {}
for k in ("GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL"):
    assert env.get(k) == "noreply@anthropic.com", f"env du job dev : {k}"
for k in ("GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME"):
    assert env.get(k), f"env du job dev : {k}"
ds = dev["steps"]
by_id = {s.get("id"): i for i, s in enumerate(ds) if s.get("id")}
assert "ticket" in by_id and "hooks" in by_id, "etapes ticket et hooks"
assert by_id["ticket"] < by_id["hooks"] < by_id["claude"], by_id
h = ds[by_id["hooks"]]
run = h["run"]
assert "tools/factory/commit-trailers.sh install" in run
assert "core.hooksPath" in run and "GIT_CONFIG_COUNT" in run and "$GITHUB_ENV" in run
assert "AGENT_TICKET_ID" in run, "Ticket depuis run-ticket.sh ticket-env"
assert "sudo chown" in run, "repertoire des hooks non modifiable par l'agent"
assert "${{" not in run, "aucune expression interpolee dans le script"
he = h["env"]
assert he["MODEL"] == "${{ inputs.model }}" and he["EFFORT"] == "${{ inputs.effort }}"
assert he["ESCALATED_FROM"] == "${{ inputs.escalated_from }}"
assert he["CLAUDE_SESSION"] == "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
assert "secrets." not in str(h), "aucun secret dans l'etape du hook"
assert "always()" not in h["if"] and "always()" not in ds[by_id["claude"]]["if"], "hook en echec => agent non lance"
assert "steps.limit.outputs.limited == 'false'" in h["if"] and "steps.pause.outputs.paused == 'false'" in h["if"]
# Le controle des trailers reste le juge final.
assert "run-ticket.sh check-trailers" in ds[by_id["trailers"]]["run"]
PY

echo "---"
if [[ "$fails" -eq 0 ]]; then echo "commit-trailers-test : PASS"; else echo "commit-trailers-test : FAIL ($fails)"; exit 1; fi
