#!/usr/bin/env bash
# Tests statiques de l'executant minimal (T-313) : plafonds, arguments claude, trailers, mission-result.v1, workflow.
# Aucun reseau, aucun cluster, aucun secret. Usage : tests/factory/run-ticket-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RT="$ROOT/tools/factory/run-ticket.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/run-ticket-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
expect() {
  local name="$1" want="$2" rc=0
  shift 2
  "$@" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then ok "$name"; else ko "$name (code $rc, attendu $want)"; sed 's/^/  /' "$W/out"; fi
}
eq() { if [[ "$2" == "$3" ]]; then ok "$1"; else ko "$1 (obtenu '$2', attendu '$3')"; fi; }

# 1. Plafonds par modele.
eq "Opus 90 min / 150 tours" "$("$RT" limits claude-opus-5-5 | tr '\n' ' ')" "timeout_minutes=90 max_turns=150 "
eq "Sonnet 45 min / 60 tours" "$("$RT" limits claude-sonnet-5-5 | tr '\n' ' ')" "timeout_minutes=45 max_turns=60 "
eq "Haiku 45 min / 60 tours" "$("$RT" limits claude-haiku-5-5 | tr '\n' ' ')" "timeout_minutes=45 max_turns=60 "
expect "modele inconnu refuse" 2 "$RT" limits gpt-x

# 2. Effort : Sonnet plafonne a xhigh.
expect "Sonnet xhigh accepte" 0 "$RT" effort claude-sonnet-5-5 xhigh
expect "Sonnet max refuse" 2 "$RT" effort claude-sonnet-5-5 max
expect "Haiku max refuse" 2 "$RT" effort claude-haiku-5-5 max
expect "Opus max accepte" 0 "$RT" effort claude-opus-5-5 max
expect "effort inconnu refuse" 2 "$RT" effort claude-opus-5-5 ultra
eq "claude-args Sonnet" "$("$RT" claude-args claude-sonnet-5-5 high | tr '\n' ' ')" "--model claude-sonnet-5-5 --effort high --max-turns 60 "

# 3. Trailers et identite : depot jetable.
mkdir "$W/repo"
cd "$W/repo"
git init -q -b main .
git -c user.name=t -c user.email=noreply@anthropic.com commit -q --allow-empty -m base
base="$(git rev-parse HEAD)"
good_msg=$'feat: x\n\nTicket: T-999\nModel: claude-sonnet-5-5\nEffort: high\nClaude-Session: https://example.invalid/s/1'
commit() { git -c user.name=t -c "user.email=$1" -c "committer.email=$1" commit -q --allow-empty -m "$2"; }
GIT_COMMITTER_EMAIL=noreply@anthropic.com GIT_COMMITTER_NAME=t commit noreply@anthropic.com "$good_msg"
expect "commit conforme accepte" 0 "$RT" check-trailers "$base..HEAD"
GIT_COMMITTER_EMAIL=noreply@anthropic.com GIT_COMMITTER_NAME=t commit noreply@anthropic.com "feat: sans trailer"
expect "commit sans trailer refuse" 1 "$RT" check-trailers "$base..HEAD"
git reset -q --hard HEAD~1
GIT_COMMITTER_EMAIL=perso@example.invalid GIT_COMMITTER_NAME=t commit perso@example.invalid "$good_msg"
expect "e-mail personnel refuse" 1 "$RT" check-trailers "$base..HEAD"
git reset -q --hard HEAD~1
GIT_COMMITTER_EMAIL=noreply@anthropic.com GIT_COMMITTER_NAME=t commit noreply@anthropic.com $'feat: y\n\nTicket: T-999\nModel: claude-sonnet-5-5\nEffort: high'
expect "Claude-Session absent refuse" 1 "$RT" check-trailers "$base..HEAD"
cd "$ROOT"

# 4. mission-result.v1 : sortie synthetique (aucun prompt ne doit y figurer), validation par le schema.
cat >"$W/exec.json" <<'JSON'
[{"type":"system","subtype":"init","model":"claude-sonnet-5-5","prompt":"SECRET-PROMPT"},
 {"type":"assistant","message":{"content":[{"type":"text","text":"SECRET-PROMPT"}]}},
 {"type":"result","is_error":false,"num_turns":12,"duration_ms":93000,"total_cost_usd":0.4321,
  "usage":{"input_tokens":100,"output_tokens":200,"cache_read_input_tokens":300,"cache_creation_input_tokens":400}}]
JSON
"$RT" result "$W/exec.json" 42 claude-sonnet-5-5 high "" claude/t-999 >"$W/res.json"
if python3 -I - "$ROOT/docs/schema/mission-result.v1.json" "$W/res.json" <<'PY'; then ok "mission-result.v1 conforme au schema"; else ko "mission-result.v1 non conforme"; fi
import json, sys
import jsonschema
schema, doc = (json.load(open(p)) for p in sys.argv[1:3])
jsonschema.Draft202012Validator(schema).validate(doc)
assert doc["model_observed"] == "claude-sonnet-5-5" and doc["num_turns"] == 12 and doc["status"] == "PASS"
assert doc["escalated_from"] is None and doc["effort"] == "high" and doc["total_cost_usd"] == 0.4321
PY
if grep -q "SECRET-PROMPT" "$W/res.json"; then ko "le prompt fuit dans mission-result"; else ok "aucun prompt dans mission-result"; fi
GITHUB_STEP_SUMMARY="$W/summary.md" "$RT" result "$W/exec.json" 42 claude-sonnet-5-5 high >/dev/null
if grep -q "total_cost_usd" "$W/summary.md" && grep -q "num_turns" "$W/summary.md" && ! grep -q "SECRET-PROMPT" "$W/summary.md"; then
  ok "resume du job : cout et tours, aucune sortie d'outil"
else ko "resume du job incorrect"; fi
"$RT" result "$W/exec.json" 42 claude-opus-5-5 high >"$W/mismatch.json"
if grep -q '"failure": "model_mismatch"' "$W/mismatch.json" && grep -q '"status": "FAIL"' "$W/mismatch.json"; then
  ok "modele observe different du modele demande : FAIL"
else ko "ecart de modele non detecte"; fi

# 5. Workflow.
wf="$ROOT/.github/workflows/claude-agent.yml"
if grep -qE '^ *show_full_output: \$\{\{ inputs\.debug \}\}$' "$wf" && ! grep -qE '^ *show_full_output: *true' "$wf"; then ok "show_full_output seulement via l'entree debug"; else ko "show_full_output non borne a l'entree debug"; fi
grep -qE '^ *debug:' "$wf" && grep -A4 -E '^ *debug:' "$wf" | grep -q 'default: false' && ok "debug faux par defaut" || ko "debug doit etre faux par defaut"
eq "secrets : jeton Claude et identite de l'executant (T-304) seulement" "$(grep -o 'secrets\.[A-Z_]*' "$wf" | sort -u | tr '\n' ' ')" "secrets.APP_ID secrets.APP_PRIVATE_KEY secrets.CLAUDE_CODE_OAUTH_TOKEN secrets.FACTORY_GH_TOKEN "
if grep -qE '^  issues:|label_trigger' "$wf"; then ko "declencheur par label encore present"; else ok "declencheur par label retire"; fi
# shellcheck disable=SC2016
if grep -q -- '--model \${{ inputs.model }}' "$wf" && grep -q -- '--effort \${{ inputs.effort }}' "$wf" \
  && grep -q -- '--max-turns \${{ needs.plan.outputs.max_turns }}' "$wf" && grep -q 'timeout-minutes: \${{ fromJSON(needs.plan.outputs.timeout_minutes) }}' "$wf"; then
  ok "model, effort, max-turns et timeout branches sur le workflow"
else ko "arguments claude_args ou timeout non branches"; fi

# 6. Branchement dans ci.yaml : job agent-trailers, appelle check-trailers, present dans needs de ci-ok, jamais `skipped` au niveau du job.
ci="$ROOT/.github/workflows/ci.yaml"
if python3 -I - "$ci" <<'PY'; then ok "ci.yaml : agent-trailers branche dans ci-ok sans condition de job"; else ko "ci.yaml : agent-trailers mal branche"; fi
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
job = wf["jobs"]["agent-trailers"]
assert "if" not in job, "un if de job le rendrait skipped, donc ferait echouer ci-ok"
assert "agent-trailers" in wf["jobs"]["ci-ok"]["needs"]
steps = "\n".join(s.get("run", "") for s in job["steps"])
assert "run-ticket.sh check-trailers origin/main..HEAD" in steps
assert "claude/" in job["env"]["IS_AGENT_PR"] and "agent/" in job["env"]["IS_AGENT_PR"]
PY

# 7. Ligne de commentaire de PR : modele observe, tours, cout, duree ; aucun prompt.
line="$("$RT" comment "$W/res.json")"
if [[ "$line" == *"claude-sonnet-5-5"* && "$line" == *"12 tours"* && "$line" == *"0.432 USD"* && "$line" == *"93 s"* && "$line" != *"SECRET-PROMPT"* && "$(wc -l <<<"$line")" -eq 1 ]]; then
  ok "ligne de commentaire de PR (une ligne, sans sortie d'outil)"
else ko "ligne de commentaire de PR incorrecte : $line"; fi
if grep -q 'run-ticket.sh comment' "$wf" && grep -q 'gh pr comment' "$wf" && grep -q 'steps.app.outputs.token' "$wf"; then ok "workflow : commentaire de PR via le jeton de l'App"; else ko "commentaire de PR non branche"; fi

if [[ "$fails" -gt 0 ]]; then printf '%s test(s) en echec\n' "$fails"; exit 1; fi
echo "tous les tests de l'executant passent"
