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
eq "Opus 90 min / 200 tours" "$("$RT" limits claude-opus-5-5 | tr '\n' ' ')" "timeout_minutes=90 max_turns=200 "
eq "Sonnet 45 min / 100 tours" "$("$RT" limits claude-sonnet-5-5 | tr '\n' ' ')" "timeout_minutes=45 max_turns=100 "
eq "Haiku 45 min / 100 tours" "$("$RT" limits claude-haiku-5-5 | tr '\n' ' ')" "timeout_minutes=45 max_turns=100 "
# T-466 : le jeton d'App vit 1 h ; hors Opus, le job doit finir avant (timeout <= 55 min).
for m in claude-sonnet-5-5 claude-haiku-5-5; do
  t="$("$RT" limits "$m" | sed -n 's/^timeout_minutes=//p')"
  if [[ "$t" -le 55 ]]; then ok "$m : timeout $t min <= 55 (jeton d'App 1 h)"; else ko "$m : timeout $t min > 55"; fi
done
expect "modele inconnu refuse" 2 "$RT" limits gpt-x

# 2. Effort : Sonnet plafonne a xhigh.
expect "Sonnet xhigh accepte" 0 "$RT" effort claude-sonnet-5-5 xhigh
expect "Sonnet max refuse" 2 "$RT" effort claude-sonnet-5-5 max
expect "Haiku max refuse" 2 "$RT" effort claude-haiku-5-5 max
expect "Opus max accepte" 0 "$RT" effort claude-opus-5-5 max
expect "effort inconnu refuse" 2 "$RT" effort claude-opus-5-5 ultra
eq "claude-args Sonnet" "$("$RT" claude-args claude-sonnet-5-5 high | tr '\n' ' ')" "--model claude-sonnet-5-5 --effort high --max-turns 100 "

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

# 4 bis (T-466). Verdict : motifs, statut jamais PASS pour un job en echec, conformite au schema.
validate() { # $1 = mission-result ; valide le schema
  python3 -I - "$ROOT/docs/schema/mission-result.v1.json" "$1" <<'PY'
import json, sys
import jsonschema
schema, doc = (json.load(open(p)) for p in sys.argv[1:3])
jsonschema.Draft202012Validator(schema).validate(doc)
PY
}
field() { python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2]) or "")' "$1" "$2"; }
# Cas mesure du run 44313706955 : session reussie, 79 tours pour un plafond de 60, etape claude en echec.
cat >"$W/over.json" <<'JSON'
[{"type":"system","subtype":"init","model":"claude-sonnet-5-5"},
 {"type":"result","subtype":"success","is_error":false,"num_turns":79,"duration_ms":734000,"total_cost_usd":1.81}]
JSON
case_result() { # nom fichier_exec branche outcome max trailers statut_attendu motif_attendu verdict_attendu
  local name="$1" exec="$2" br="$3" oc="$4" mx="$5" tr="$6" want_st="$7" want_f="$8" want_v="$9" out="$W/case.json" rc=0
  "$RT" result "$exec" 66 claude-sonnet-5-5 high "" "$br" "$oc" "$mx" "$tr" >"$out"
  if validate "$out" && [[ "$(field "$out" status)" == "$want_st" && "$(field "$out" failure)" == "$want_f" ]]; then
    ok "result $name : $want_st ${want_f:-sans motif}"
  else ko "result $name : obtenu $(field "$out" status)/$(field "$out" failure), attendu $want_st/$want_f"; fi
  "$RT" verdict "$out" >"$W/verdict.out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want_v" ]]; then ok "verdict $name : code $want_v"; else ko "verdict $name : code $rc, attendu $want_v"; cat "$W/verdict.out"; fi
  # Invariant : un job en echec (verdict 1) ne porte jamais PASS, ni dans l'artefact ni dans le commentaire.
  if [[ "$rc" -ne 0 ]] && { [[ "$(field "$out" status)" == "PASS" ]] || "$RT" comment "$out" | grep -q "statut PASS"; }; then
    ko "invariant $name : PASS affiche pour un job en echec"
  fi
}
case_result "plafond depasse avec livraison" "$W/over.json" claude/issue-66-x failure 60 success NOT_TESTED turn_cap_exceeded 0
case_result "plafond 100 tenu" "$W/over.json" claude/issue-66-x success 100 success PASS "" 0
case_result "plafond depasse sans branche" "$W/over.json" "" failure 60 "" NOT_TESTED no_branch 1
case_result "trailers refuses" "$W/over.json" claude/issue-66-x success 100 failure FAIL trailers_refused 1
case_result "etape claude en echec inexpliquee" "$W/over.json" claude/issue-66-x failure 100 success FAIL action_error 1
case_result "fichier d'execution absent" "$W/absent.json" claude/issue-66-x failure 100 success FAIL agent_error 1
case_result "chemin d'execution vide" "" claude/issue-66-x failure 100 "" FAIL agent_error 1
cat >"$W/cut.json" <<'JSON'
[{"type":"system","subtype":"init","model":"claude-sonnet-5-5"},
 {"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":101,"duration_ms":1000,"total_cost_usd":0.1}]
JSON
case_result "session coupee au plafond" "$W/cut.json" claude/issue-66-x failure 100 success FAIL turn_cap_exceeded 1
cat >"$W/err.json" <<'JSON'
[{"type":"system","subtype":"init","model":"claude-sonnet-5-5"},
 {"type":"result","subtype":"success","is_error":true,"num_turns":3,"duration_ms":1000,"total_cost_usd":0.1}]
JSON
case_result "is_error" "$W/err.json" claude/issue-66-x failure 100 success FAIL agent_error 1
expect "verdict sans mission-result : echec" 1 "$RT" verdict "$W/absent.json"
"$RT" result "$W/over.json" 66 claude-sonnet-5-5 high "" claude/issue-66-x failure 60 success >"$W/cap.json"
line="$("$RT" comment "$W/cap.json")"
if [[ "$line" == *"statut NOT_TESTED (turn_cap_exceeded)"* && "$line" == *"claude/issue-66-x"* ]]; then ok "commentaire : statut corrige et motif"; else ko "commentaire sans motif : $line"; fi
"$RT" report 66 "$W/cap.json" https://example.invalid/run/1 >"$W/report.md"
if grep -q "NOT_TESTED (turn_cap_exceeded)" "$W/report.md" && grep -q "https://example.invalid/run/1" "$W/report.md"; then ok "report : statut corrige et lien du run"; else ko "report incorrect"; fi
"$RT" report 66 - https://example.invalid/run/1 >"$W/report0.md"
if grep -q "statut \*\*FAIL\*\*" "$W/report0.md"; then ok "report sans mission-result : FAIL"; else ko "report sans mission-result incorrect"; fi
expect "report : issue invalide refusee" 2 "$RT" report '1;x' - https://example.invalid/run/1

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

# 8. Variables des hooks (T-331) : ticket-env pose AGENT_TICKET_ID et AGENT_TICKET_SCOPE, jamais LAB_COORDINATOR_SESSION.
"$RT" ticket-env T-331 >"$W/tenv"
eq "ticket-env T-331 : identifiant" "$(sed -n 's/^AGENT_TICKET_ID=//p' "$W/tenv")" "T-331"
eq "ticket-env T-331 : perimetre du ticket" "$(sed -n 's/^AGENT_TICKET_SCOPE=//p' "$W/tenv")" ".claude/hooks/,.claude/settings.json,tests/hooks/"
if grep -q 'LAB_COORDINATOR_SESSION' "$W/tenv"; then ko "ticket-env pose LAB_COORDINATOR_SESSION"; else ok "ticket-env ne pose pas LAB_COORDINATOR_SESSION"; fi
expect "ticket-env : ticket inconnu refuse (code 3)" 3 "$RT" ticket-env T-9999
expect "ticket-env : issue sans ticket refusee (code 3)" 3 "$RT" ticket-env 987654321
expect "ticket-env : reference invalide refusee (code 2)" 2 "$RT" ticket-env 'T-1;id'
expect "ticket-env : reference absente refusee" 1 "$RT" ticket-env
# Les variables produites pilotent vraiment le garde (chaine complete, hors tests/hooks/run.sh).
guard="$ROOT/.claude/hooks/pretool-scope-guard.sh"
run_guard() { # $1 = fichier, reste = environnement
  local f="$1"
  shift
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s"}' "$f" "$ROOT" | env -u LAB_COORDINATOR_SESSION "$@" CLAUDE_PROJECT_DIR="$ROOT" "$guard"
}
scope_env=("$(grep '^AGENT_TICKET_ID=' "$W/tenv")" "$(grep '^AGENT_TICKET_SCOPE=' "$W/tenv")")
expect "garde + ticket-env : fichier du perimetre autorise" 0 run_guard "$ROOT/tests/hooks/run.sh" "${scope_env[@]}"
expect "garde + ticket-env : fichier du ticket autorise" 0 run_guard "$ROOT/backlog/T-331-hooks-deterministes-garde-de-perimetre-garde.md" "${scope_env[@]}"
expect "garde + ticket-env : hors perimetre refuse" 2 run_guard "$ROOT/tools/appgen/appgen.py" "${scope_env[@]}"
expect "garde + ticket-env : STATE.md refuse" 2 run_guard "$ROOT/STATE.md" "${scope_env[@]}"
# Branchement du workflow : la variable est posee avant l'action, jamais LAB_COORDINATOR_SESSION.
if python3 -I - "$wf" <<'PY'; then ok "workflow : ticket-env ecrit dans GITHUB_ENV avant l'action claude"; else ko "workflow : ticket-env mal branche"; fi
import sys, yaml
steps = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))["jobs"]["dev"]["steps"]
t = next(i for i, s in enumerate(steps) if "ticket-env" in s.get("run", ""))
c = next(i for i, s in enumerate(steps) if s.get("id") == "claude")
assert t < c, "ticket-env doit preceder l'action"
assert "GITHUB_ENV" in steps[t]["run"]
assert steps[t]["if"] == "steps.pause.outputs.paused == 'false' && steps.limit.outputs.limited == 'false'"  # T-467
PY
if grep -rn 'LAB_COORDINATOR_SESSION' "$ROOT/.github" "$RT" | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' | grep -vq 'Jamais LAB_COORDINATOR_SESSION\|jamais LAB_COORDINATOR_SESSION\|reservee a la session'; then
  ko "LAB_COORDINATOR_SESSION posee ou citee hors commentaire par l'executant"
else ok "LAB_COORDINATOR_SESSION jamais posee par l'executant"; fi

# 9. Branchement dans ci.yaml : job hooks appelle tests/hooks/run.sh, dans needs de ci-ok, jamais `skipped` au niveau du job.
if python3 -I - "$ci" <<'PY'; then ok "ci.yaml : job hooks (tests/hooks/run.sh) branche dans ci-ok sans condition de job"; else ko "ci.yaml : job hooks mal branche"; fi
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
job = wf["jobs"]["hooks"]
assert "if" not in job, "un if de job le rendrait skipped, donc ferait echouer ci-ok"
assert "hooks" in wf["jobs"]["ci-ok"]["needs"]
assert "tests/hooks/run.sh" in "\n".join(s.get("run", "") for s in job["steps"])
PY

# 10. Durcissement T-466 : continue-on-error + Verdict, always() sur les trailers, branche par l'API REST, prompt,
# allowedTools etroits sans gh api, job report.
if python3 -I - "$wf" <<'PY'; then ok "workflow T-466 : verdict, trailers, branche REST, prompt, outils, report"; else ko "workflow T-466 : durcissement incomplet"; fi
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
steps = wf["jobs"]["dev"]["steps"]
by_id = {s.get("id"): s for s in steps if s.get("id")}
claude = by_id["claude"]
assert claude.get("continue-on-error") is True, "etape claude : continue-on-error"
tr = by_id["trailers"]
assert tr["if"].startswith("always() &&"), "controle des trailers : always()"
assert tr.get("continue-on-error") is True
last = steps[-1]
assert "Verdict" in last["name"] and last["if"].startswith("always()"), "derniere etape : Verdict always()"
assert "steps.claude.outcome" in str(last.get("env")) and "run-ticket.sh verdict" in last["run"]
assert "continue-on-error" not in last, "Verdict decide du job"
res = next(s for s in steps if "run-ticket.sh result" in s.get("run", ""))
env = res["env"]
assert env["CLAUDE_OUTCOME"] == "${{ steps.claude.outcome }}" and env["TRAILERS_OUTCOME"] == "${{ steps.trailers.outcome }}"
assert env["MAX_TURNS"] == "${{ needs.plan.outputs.max_turns }}"
assert "execution_file != ''" not in res["if"], "mission-result produit meme sans fichier d'execution"
br = by_id["branch"]["run"]
assert "/pulls?state=all" in br and "--search" not in br and "claude/issue-${ISSUE}-" in br
assert "head.repo.full_name" in br, "branche du depot seulement (pas d'une fourche)"
w = claude["with"]
prompt = w["prompt"]
sysp = w["claude_args"]
assert "claude/issue-${{ matrix.issue }}-" in prompt and "Closes #${{ matrix.issue }}" in prompt
assert "Claude-Session: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}" in sysp
assert "Ne lis jamais l'environnement" in sysp and "n'attends pas la CI" in sysp
tools = sysp.split('--allowedTools "', 1)[1].split('"', 1)[0].split(",")
assert "Bash(python3:*)" not in tools, "python3 libre interdit"
for t in tools:
    assert not t.startswith("Bash(gh api"), "gh api non autorise a l'agent"
    assert t not in ("Bash(python3 -I -m:*)", "Bash(python3 -m:*)", "Bash(python3 -c:*)", "Bash(python3 -:*)", "Bash(*)", "Bash"), t
    assert not (t.startswith("Bash(python3") and not any(k in t for k in ("tools/", "tests/", "-m unittest"))), t
for need in ("Bash(tools/dev/check:*)", "Bash(tests/*)", "Bash(bash tests/*)", "Bash(gh pr list:*)", "Bash(gh search:*)",
             "Bash(python3 tools/*)", "Bash(python3 -m unittest:*)"):
    assert need in tools, need
rep = wf["jobs"]["report"]
assert rep["if"].startswith("always()") and "dev" in rep["needs"]
rsteps = "\n".join(s.get("run", "") for s in rep["steps"])
assert "run-ticket.sh report" in rsteps and "gh issue comment" in rsteps
assert any("create-github-app-token" in s.get("uses", "") for s in rep["steps"]), "jeton d'App neuf dans report"
PY

if [[ "$fails" -gt 0 ]]; then printf '%s test(s) en echec\n' "$fails"; exit 1; fi
echo "tous les tests de l'executant passent"
