#!/usr/bin/env bash
# Tests hors ligne du cablage T-467 dans .github/workflows/claude-agent.yml : structure (plan, dev, report, breaker) et
# rejeu des scripts `run:` des etapes de garde avec un `gh` factice. Aucun reseau, aucun cluster, aucun secret.
# Usage : tests/factory/workflow-guard-test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="${WORKFLOW:-$ROOT/.github/workflows/claude-agent.yml}"  # WORKFLOW : copie mutee (test du test)
W="$(mktemp -d "${TMPDIR:-/tmp}/workflow-guard-tests.XXXXXX")"
trap 'rm -rf "$W"' EXIT
export PYTHONDONTWRITEBYTECODE=1
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# 1. Structure du workflow.
if python3 -I - "$WF" <<'PY'; then ok "structure T-467 : plan, dev, report, breaker"; else ko "structure T-467 incomplete"; fi
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
jobs = wf["jobs"]

plan = jobs["plan"]
assert plan["outputs"]["limited"] == "${{ steps.limit.outputs.limited }}"
assert plan["outputs"]["overlap"] == "${{ steps.overlap.outputs.overlap }}"
assert plan["permissions"].get("issues") == "write", "plan : commentaire de l'issue refusee"
ps = plan["steps"]
ids = [s.get("id") for s in ps]
assert ids.index("pause") < ids.index("limit") < ids.index("overlap") < ids.index("matrix"), ids
lim = ps[ids.index("limit")]
assert "ledger.py gate --state factory/LIMIT.json" in lim["run"] and '[ "$?" -eq 11 ]' in lim["run"]
ov = ps[ids.index("overlap")]
assert ov["if"] == "steps.pause.outputs.paused == 'false' && steps.limit.outputs.limited == 'false'"
assert "tools/factory/overlap.py" in ov["run"] and ov["env"]["TICKETS"] == "${{ inputs.tickets }}"
refuse = ps[ids.index("overlap") + 1]
assert refuse["if"] == "steps.overlap.outputs.overlap == 'true'"
assert "gh issue comment" in refuse["run"] and "exit 4" in refuse["run"], "refus : commentaire puis plan rouge"
assert "inputs." not in refuse["run"], "aucune entree interpolee dans le script"
mx = ps[ids.index("matrix")]
for cond in ("steps.pause.outputs.paused == 'false'", "steps.limit.outputs.limited == 'false'",
             "steps.overlap.outputs.overlap == 'false'"):
    assert cond in mx["if"], cond

dev = jobs["dev"]
for cond in ("needs.plan.outputs.paused == 'false'", "needs.plan.outputs.limited == 'false'",
             "needs.plan.outputs.overlap == 'false'"):
    assert cond in dev["if"], cond
assert dev["permissions"].get("actions") == "read"
ds = dev["steps"]
by_id = {s.get("id"): i for i, s in enumerate(ds) if s.get("id")}
assert by_id["pause"] < by_id["limit"] < by_id["claude"] < by_id["quota"] < by_id["branch"]
dl = ds[by_id["limit"] - 1]
assert "download-artifact" in dl.get("uses", "") and dl["with"]["pattern"] == "factory-limit-*"
assert dl.get("continue-on-error") is True
assert "ledger.py check" in ds[by_id["limit"]]["run"] and "origin/main:factory/LIMIT.json" in ds[by_id["limit"]]["run"]
stop = ds[by_id["limit"] + 1]
assert stop["if"] == "steps.limit.outputs.limited == 'true'" and "exit 1" in stop["run"]
# Toute etape apres le re-controle (sauf l'arret et la publication de l'artefact) exige limited == 'false'.
for s in ds[by_id["limit"] + 2:]:
    if s.get("id") == "quota" or "factory-limit-" in str(s.get("with", {}).get("name", "")):
        continue
    assert "steps.limit.outputs.limited == 'false'" in s.get("if", ""), s.get("name") or s.get("id")
q = ds[by_id["quota"]]
assert q["if"] == "always() && steps.claude.outputs.execution_file != ''"
assert "ledger.py detect" in q["run"] and "tripped=true" in q["run"]
up = ds[by_id["quota"] + 1]
assert "upload-artifact" in up["uses"] and up["with"]["name"] == "factory-limit-${{ matrix.issue }}"
assert up["if"] == "always() && steps.quota.outputs.tripped == 'true'"
assert "Verdict" in ds[-1]["name"], "Verdict reste la derniere etape (T-466)"

rep = jobs["report"]
assert rep["if"].startswith("always()") and "needs.plan.outputs.limited == 'false'" in rep["if"]

br = jobs["breaker"]
assert br["needs"] == ["plan", "dev"] and br["if"].startswith("always()")
assert br["permissions"] == {"contents": "read", "actions": "read"}
run = "\n".join(s.get("run", "") for s in br["steps"])
for need in ("factory/LIMIT.json", "Ticket: T-467", "Model: ${MODEL}", "Effort: ${EFFORT}", "Claude-Session: ${RUN_URL}",
             "noreply@anthropic.com", "gh pr merge \"$BRANCH\" --auto --squash", "n'est pas bloque"):
    assert need in run, need
assert any("create-github-app-token" in s.get("uses", "") for s in br["steps"])
assert "inputs." not in run and "secrets." not in run, "valeurs passees par env seulement"
PY

# Extrait le script `run:` d'une etape (job, id ou position relative a un id).
step_run() {
  python3 -I - "$WF" "$1" "$2" "${3:-0}" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
steps = wf["jobs"][sys.argv[2]]["steps"]
i = next(i for i, s in enumerate(steps) if s.get("id") == sys.argv[3]) + int(sys.argv[4])
print(steps[i]["run"])
PY
}

# Faux `gh` : journalise ses arguments, aucun reseau.
mkdir -p "$W/bin"
printf '#!/usr/bin/env bash\necho "gh $*" >>"%s/gh.log"\n' "$W" >"$W/bin/gh"
chmod +x "$W/bin/gh"

# 2. Garde de recouvrement du plan, rejouee sur le backlog reel.
step_run plan overlap >"$W/overlap.sh"
step_run plan overlap 1 >"$W/refuse.sh"
run_plan() {  # $1 = TICKETS ; sortie : rc du script overlap, sortie GITHUB_OUTPUT dans $W/out-plan
  local rt="$W/rt-plan" rc=0
  rm -rf "$rt"; mkdir -p "$rt"; : >"$W/out-plan"
  (cd "$ROOT" && RUNNER_TEMP="$rt" GITHUB_OUTPUT="$W/out-plan" TICKETS="$1" bash -eo pipefail "$W/overlap.sh" 2>/dev/null) || rc=$?
  return "$rc"
}
if run_plan "T-467" && grep -qx "overlap=false" "$W/out-plan"; then ok "plan : ticket seul admis (overlap=false)"; else ko "plan : ticket seul"; fi
if run_plan "T-467,T-466" && grep -qx "overlap=true" "$W/out-plan"; then ok "plan : T-467 et T-466 se recoupent (overlap=true, plan continue jusqu'au refus)"; else ko "plan : recouvrement non detecte"; fi
rc=0; run_plan "x;y" || rc=$?
if [[ "$rc" -eq 2 ]]; then ok "plan : reference invalide = echec d'usage (code 2)"; else ko "plan : reference invalide rc=$rc"; fi

# Refus : commentaire des seules issues numeriques, puis code 4. L'issue 49 est rattachee a un ticket du backlog.
run_plan "49,T-467,T-466" || true
: >"$W/gh.log"; : >"$W/summary"; rc=0
(cd "$ROOT" && PATH="$W/bin:$PATH" RUNNER_TEMP="$W/rt-plan" GITHUB_STEP_SUMMARY="$W/summary" RUN_URL="https://example.invalid/run/1" \
  bash -eo pipefail "$W/refuse.sh" >/dev/null 2>&1) || rc=$?
if [[ "$rc" -eq 4 ]] && [[ "$(cat "$W/gh.log")" == "gh issue comment 49 --body-file $W/rt-plan/overlap-comment.md" ]]; then
  ok "refus : commentaire de l'issue 49 seulement, puis code 4"
else ko "refus : rc=$rc, gh=$(cat "$W/gh.log")"; fi
if grep -q "REFUS recouvrement" "$W/rt-plan/overlap-comment.md" && grep -q "aucun agent n'a été lancé" "$W/rt-plan/overlap-comment.md" \
  && grep -q "example.invalid/run/1" "$W/summary"; then ok "refus : motif, consequence et lien du run dans le commentaire"; else ko "refus : commentaire incomplet"; fi

# 3. Re-controle du disjoncteur dans dev (origin/main sans LIMIT.json ; artefacts de jobs freres simules).
step_run dev limit >"$W/limit.sh"
run_limit() {  # $1 = modele ; $2.. = "chemin:kind" des artefacts
  local model="$1" rt="$W/rt-dev"; shift
  rm -rf "$rt"; mkdir -p "$rt"; : >"$W/out-dev"
  for spec in "$@"; do
    mkdir -p "$rt/limit-run/$(dirname "${spec%%:*}")"
    printf '{"schema":"quota-breaker.v1","state":"open","kind":"%s","resume_at":null}\n' "${spec##*:}" >"$rt/limit-run/${spec%%:*}"
  done
  (cd "$ROOT" && RUNNER_TEMP="$rt" GITHUB_OUTPUT="$W/out-dev" MODEL="$model" bash -eo pipefail "$W/limit.sh" >/dev/null 2>&1)
  sed -n 's/^limited=//p' "$W/out-dev"
}
if git -C "$ROOT" cat-file -e origin/main:factory/LIMIT.json 2>/dev/null; then
  ko "origin/main porte factory/LIMIT.json : cas du re-controle non rejouable"
else
  limit_case() {  # $1 = libelle ; $2 = attendu ; $3.. = arguments de run_limit
    local name="$1" want="$2" got; shift 2
    got="$(run_limit "$@")"
    if [[ "$got" == "$want" ]]; then ok "$name"; else ko "$name : limited=$got, attendu $want"; fi
  }
  limit_case "dev : aucun disjoncteur, agent lance" false claude-sonnet-5-5
  limit_case "dev : limite de session d'un job frere (plusieurs artefacts : path/<nom>/)" true claude-sonnet-5-5 factory-limit-66/LIMIT.json:session
  limit_case "dev : artefact unique extrait dans path/ (v5+)" true claude-sonnet-5-5 LIMIT.json:weekly
  limit_case "dev : limite Sonnet ne bloque pas Opus" false claude-opus-5-5 factory-limit-66/LIMIT.json:sonnet
fi

# 4. Job breaker : choix du disjoncteur le plus recent.
python3 -I - "$WF" >"$W/pick.sh" <<'PY'
import sys, yaml
steps = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))["jobs"]["breaker"]["steps"]
print(next(s for s in steps if s.get("id") == "pick")["run"])
PY
mkdir -p "$W/rt-br/limit-run/factory-limit-1" "$W/rt-br/limit-run/factory-limit-2"
echo '{"tripped_at":"2026-11-18T10:00:00+00:00"}' >"$W/rt-br/limit-run/factory-limit-1/LIMIT.json"
echo '{"tripped_at":"2026-11-18T11:00:00+00:00"}' >"$W/rt-br/limit-run/factory-limit-2/LIMIT.json"
: >"$W/out-br"
RUNNER_TEMP="$W/rt-br" GITHUB_OUTPUT="$W/out-br" bash -eo pipefail "$W/pick.sh" >/dev/null
if grep -qx "file=$W/rt-br/limit-run/factory-limit-2/LIMIT.json" "$W/out-br"; then ok "breaker : disjoncteur le plus recent retenu"; else ko "breaker : mauvais choix ($(cat "$W/out-br"))"; fi
rm -rf "$W/rt-br/limit-run"; : >"$W/out-br"
RUNNER_TEMP="$W/rt-br" GITHUB_OUTPUT="$W/out-br" bash -eo pipefail "$W/pick.sh" >/dev/null
if grep -qx "file=" "$W/out-br"; then ok "breaker : aucun artefact, aucune PR"; else ko "breaker : sortie sans artefact ($(cat "$W/out-br"))"; fi

if [[ "$fails" -gt 0 ]]; then printf '%s test(s) en echec\n' "$fails"; exit 1; fi
echo "tous les tests du cablage T-467 passent"
