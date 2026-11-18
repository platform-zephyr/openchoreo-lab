#!/usr/bin/env bash
# Parité ci.yaml <-> tools/dev/check (SL-6, T-460) : STATIQUE, sans cluster, réseau ni outil tiers (python3 + PyYAML).
#  1. Dépôt : chaque job de ci.yaml (hors ci-ok) a une ligne dans tools/dev/ci-map.tsv ; chaque étape nommée existe dans
#     `tools/dev/check --list` ; chaque étape de check est dans un job ou déclarée LOCAL-ONLY (pas d'étape orpheline) ;
#     un CI-ONLY, un LOCAL-ONLY ou un `miroir` a une raison ; un job de mode `check` appelle exactement ces étapes par
#     `tools/dev/check --static --only <étapes> --strict` (CHECK_ONLY=, hérité par les processus enfants, est refusé) ;
#     `needs` de ci-ok couvre les jobs ; aucun job (hors ci-ok) n'a de `if` (un job `skipped` ferait échouer ci-ok) ;
#     une étape réservée au push sur main (post-merge, T-421) a `continue-on-error: true` (jamais de verdict changé).
#  2. Cas négatifs : chaque règle ci-dessus est violée sur une copie ; le test doit échouer en nommant la cause.
# Usage : tests/dev-factory/ci-parity.sh
# Surcharges (cas négatifs et tests) : CI_PARITY_MAP, CI_PARITY_WORKFLOW, CI_PARITY_STEPS (fichier, une étape par ligne).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
MAP="${CI_PARITY_MAP:-tools/dev/ci-map.tsv}"
WORKFLOW="${CI_PARITY_WORKFLOW:-.github/workflows/ci.yaml}"
W="$(mktemp -d "${TMPDIR:-/tmp}/ci-parity.XXXXXX")"
trap 'rm -rf "$W"' EXIT
STEPS="${CI_PARITY_STEPS:-$W/steps.repo}"
[[ -n "${CI_PARITY_STEPS:-}" ]] || tools/dev/check --list >"$W/steps.repo"

read -r -d '' PY <<'PYEOF' || true
import re, sys
import yaml

map_path, wf_path, steps_path = sys.argv[1:4]
errors = []
steps = {l.strip() for l in open(steps_path) if l.strip()}
wf = yaml.safe_load(open(wf_path))
jobs = wf["jobs"]
ci_ok = jobs.get("ci-ok", {})
needs = set(ci_ok.get("needs") or [])

rows, local_only = {}, {}
for n, line in enumerate(open(map_path), 1):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    c = line.split("\t")
    if len(c) < 4 or not all(x.strip() for x in c[:3]):
        errors.append(f"{map_path}:{n}: ligne mal formée (4 colonnes JOB/ÉTAPES/NIVEAU/MODE attendues)")
        continue
    if c[0] == "LOCAL-ONLY":
        if not c[3].strip():
            errors.append(f"étape {c[1]} : LOCAL-ONLY sans raison")
        if c[1] in local_only:
            errors.append(f"étape {c[1]} : LOCAL-ONLY en double")
        local_only[c[1]] = c[3]
    else:
        if c[0] in rows:
            errors.append(f"job {c[0]} : ligne en double")
        rows[c[0]] = c

def calls(job):
    """Appels de tools/dev/check d'un job : liste de (ensemble d'étapes ou None, strict, static)."""
    out = []
    for st in jobs[job].get("steps", []):
        run = st.get("run")
        if not run:
            continue
        for line in run.replace("\\\n", " ").splitlines():
            m = re.search(r"tools/dev/check(?=\s|$)(.*)", line)
            if not m or line.lstrip().startswith("#"):
                continue
            args = m.group(1)
            sel = re.search(r"--only[ =]([A-Za-z0-9_,-]+)", args)
            if "CHECK_ONLY=" in line[: m.start()] or "CHECK_ONLY" in (st.get("env") or {}):
                errors.append(f"job {job} : CHECK_ONLY dans ci.yaml (forme exigée : --only <étapes>, non héritée)")
            out.append((set(sel.group(1).split(",")) if sel else None,
                        "--strict" in args.split(), "--static" in args.split()))
    return out

for job, spec in jobs.items():
    if job == "ci-ok":
        continue
    if "if" in spec:
        errors.append(f"job {job} : condition `if` au niveau du job (un job skipped ferait échouer ci-ok)")
    for st in spec.get("steps", []):
        cond = str(st.get("if", ""))
        if "github.event_name == 'push'" in cond and st.get("continue-on-error") is not True:
            errors.append(f"job {job} : étape post-merge « {st.get('name', '?')} » sans continue-on-error: true")

for job in jobs:
    if job != "ci-ok" and job not in rows:
        errors.append(f"job {job} : job CI sans équivalent local ni exception motivée (ligne absente de {map_path})")
    if job != "ci-ok" and job not in needs:
        errors.append(f"job {job} : absent de needs de ci-ok (job non requis)")
used = set()
for job, (_, names, level, mode, *rest) in ((j, r) for j, r in rows.items()):
    if job not in jobs:
        errors.append(f"job {job} : ligne de {map_path} sans job dans {wf_path}")
        continue
    if names == "CI-ONLY":
        if not mode.strip():
            errors.append(f"job {job} : CI-ONLY sans raison")
        continue
    want = set(names.split(","))
    for s in sorted(want):
        if s not in steps:
            errors.append(f"job {job} : étape {s} inexistante dans tools/dev/check --list")
    used |= want
    if mode == "check":
        got = set()
        cs = calls(job)
        if not cs:
            errors.append(f"job {job} : n'appelle pas tools/dev/check (mode check)")
        for sel, strict, static in cs:
            if sel is None:
                errors.append(f"job {job} : appel de check sans --only")
                continue
            got |= sel
            if not strict:
                errors.append(f"job {job} : appel de check sans --strict (un NOT_TESTED passerait)")
            if not static:
                errors.append(f"job {job} : appel de check sans --static")
        if cs and got != want:
            errors.append(f"job {job} : étapes appelées {sorted(got)} != étapes de la table {sorted(want)}")
    elif mode.startswith("miroir"):
        if not mode.partition(":")[2].strip():
            errors.append(f"job {job} : miroir sans raison")
    else:
        errors.append(f"job {job} : mode inconnu « {mode} » (check ou miroir : <raison>)")
for s in sorted(local_only):
    if s not in steps:
        errors.append(f"étape {s} : LOCAL-ONLY inexistante dans tools/dev/check --list")
    if s in used:
        errors.append(f"étape {s} : à la fois LOCAL-ONLY et dans un job")
for s in sorted(steps - used - set(local_only)):
    errors.append(f"étape {s} : étape orpheline (aucun job de ci.yaml ne l'appelle, pas déclarée LOCAL-ONLY)")
for e in errors:
    print("FAIL " + e)
sys.exit(1 if errors else 0)
PYEOF

# verify MAP WORKFLOW STEPS : code 0 si la parité tient ; messages FAIL sur stdout.
verify() { python3 -I -c "$PY" "$1" "$2" "$3"; }

fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# expect_fail NOM MOTIF MAP WORKFLOW STEPS : la parité doit échouer et la sortie nommer la cause (motif).
expect_fail() {
  local name="$1" pat="$2" rc=0
  verify "$3" "$4" "$5" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && grep -Eq "$pat" "$W/out"; then
    ok "refuse : $name"
  else
    ko "$name (rc=$rc, motif attendu : $pat)"
    sed 's/^/      | /' "$W/out"
  fi
}

# ---- 1. dépôt ----
if verify "$MAP" "$WORKFLOW" "$STEPS" >"$W/out" 2>&1; then
  ok "parité : $(grep -vc '^#' "$MAP" | tr -d ' ') ligne(s) de table, $(wc -l <"$STEPS" | tr -d ' ') étape(s) de check"
else
  ko "parité ci.yaml <-> check (table $MAP)"
  sed 's/^/      | /' "$W/out"
fi

# ---- 2. cas négatifs (copies modifiées) ----
cp "$MAP" "$W/map"
cp "$WORKFLOW" "$W/wf.yaml"
cp "$STEPS" "$W/steps"

# job sans ligne de table
grep -v '^lint-code	' "$W/map" >"$W/map.nojob"
expect_fail "job CI sans équivalent local" 'job lint-code : job CI sans équivalent' "$W/map.nojob" "$W/wf.yaml" "$W/steps"

# job ajouté à ci.yaml (et à needs) sans ligne
python3 -I - "$W/wf.yaml" "$W/wf.newjob.yaml" <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d["jobs"]["nouveau-controle"] = {"runs-on": "ubuntu-24.04-arm", "steps": [{"run": "echo controle"}]}
d["jobs"]["ci-ok"]["needs"].append("nouveau-controle")
yaml.safe_dump(d, open(sys.argv[2], "w"))
PYEOF
expect_fail "job ajouté sans ligne de table" 'job nouveau-controle : job CI sans équivalent' "$W/map" "$W/wf.newjob.yaml" "$W/steps"

# job hors de needs de ci-ok
python3 -I - "$W/wf.yaml" "$W/wf.noneeds.yaml" <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d["jobs"]["ci-ok"]["needs"].remove("yamllint")
yaml.safe_dump(d, open(sys.argv[2], "w"))
PYEOF
expect_fail "job non requis par ci-ok" 'job yamllint : absent de needs' "$W/map" "$W/wf.noneeds.yaml" "$W/steps"

# étape orpheline (étape ajoutée à check, absente de la table)
{ cat "$W/steps"; echo "nouvelle-etape"; } >"$W/steps.orphan"
expect_fail "étape orpheline" 'étape nouvelle-etape : étape orpheline' "$W/map" "$W/wf.yaml" "$W/steps.orphan"

# étape inexistante dans une ligne de job
sed 's/^yamllint	yamllint	/yamllint	yamllint-fantome	/' "$W/map" >"$W/map.badstep"
expect_fail "étape inexistante" 'étape yamllint-fantome inexistante' "$W/map.badstep" "$W/wf.yaml" "$W/steps"

# étape retirée d'une ligne : elle devient orpheline
sed 's/^actionlint	actionlint	/actionlint	CI-ONLY	/' "$W/map" >"$W/map.dropped"
expect_fail "étape retirée de la table (orpheline)" 'étape actionlint : étape orpheline' "$W/map.dropped" "$W/wf.yaml" "$W/steps"

# CI-ONLY sans raison
sed 's/^charts	CI-ONLY	L3	.*/charts	CI-ONLY	L3	 /' "$W/map" >"$W/map.noreason"
expect_fail "CI-ONLY sans raison" 'job charts : CI-ONLY sans raison|ligne mal formée' "$W/map.noreason" "$W/wf.yaml" "$W/steps"

# LOCAL-ONLY sans raison
sed 's/^\(LOCAL-ONLY	guard-check	-\)	.*/\1	 /' "$W/map" >"$W/map.lo"
expect_fail "LOCAL-ONLY sans raison" 'guard-check : LOCAL-ONLY sans raison|ligne mal formée' "$W/map.lo" "$W/wf.yaml" "$W/steps"

# miroir sans raison
sed 's/^quality-coverage	coverage	L2	.*/quality-coverage	coverage	L2	miroir/' "$W/map" >"$W/map.mirror"
expect_fail "miroir sans raison" 'job quality-coverage : miroir sans raison|mode inconnu' "$W/map.mirror" "$W/wf.yaml" "$W/steps"

# ligne de table sans job
printf 'job-fantome\tyamllint\tL2\tcheck\n' | cat "$W/map" - >"$W/map.ghost"
expect_fail "ligne sans job" 'job job-fantome : ligne de .* sans job' "$W/map.ghost" "$W/wf.yaml" "$W/steps"

# job de mode check dont l'appel diffère de la table, sans --strict, ou absent
sed 's/--only yamllint --strict/--only yamllint,actionlint --strict/' "$W/wf.yaml" >"$W/wf.diff.yaml"
expect_fail "appel de check avec d'autres étapes" 'job yamllint : étapes appelées' "$W/map" "$W/wf.diff.yaml" "$W/steps"
sed '/--only yamllint --strict/s/ --strict//' "$W/wf.yaml" >"$W/wf.nostrict.yaml"
expect_fail "appel de check sans --strict" 'job yamllint : appel de check sans --strict' "$W/map" "$W/wf.nostrict.yaml" "$W/steps"
sed 's/--only yamllint --strict/--strict/' "$W/wf.yaml" >"$W/wf.noonly.yaml"
expect_fail "appel de check sans --only" 'job yamllint : appel de check sans --only' "$W/map" "$W/wf.noonly.yaml" "$W/steps"
sed 's#tools/dev/check#tools/dev/autre#' "$W/wf.yaml" >"$W/wf.nocall.yaml"
expect_fail "job sans appel de check" "job yamllint : n'appelle pas tools/dev/check" "$W/map" "$W/wf.nocall.yaml" "$W/steps"

# CHECK_ONLY (variable héritée par les check imbriqués) refusé, même avec les bonnes étapes
sed 's#tools/dev/check --static --only yamllint --strict#CHECK_ONLY="yamllint" tools/dev/check --static --strict#' "$W/wf.yaml" >"$W/wf.env.yaml"
expect_fail "CHECK_ONLY au lieu de --only" 'job yamllint : CHECK_ONLY dans ci.yaml' "$W/map" "$W/wf.env.yaml" "$W/steps"

# job conditionné (skipped sur une PR) : refusé
python3 -I - "$W/wf.yaml" "$W/wf.jobif.yaml" <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d["jobs"]["hooks"]["if"] = "github.event_name == 'push'"
yaml.safe_dump(d, open(sys.argv[2], "w"))
PYEOF
expect_fail "job avec if (skipped)" "job hooks : condition .if. au niveau du job" "$W/map" "$W/wf.jobif.yaml" "$W/steps"

# étape post-merge (T-421) présente dans quality-coverage ; sans continue-on-error : refusée
if python3 -I - "$W/wf.yaml" "$W/wf.post.yaml" <<'PYEOF'; then ok "étape post-merge T-421 : push sur main, artefact quality-history, continue-on-error"; else ko "étape post-merge T-421 mal branchée"; fi
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
steps = d["jobs"]["quality-coverage"]["steps"]
hist = [s for s in steps if "tools/quality/history.py" in s.get("run", "")]
assert len(hist) == 1 and "github.event_name == 'push'" in hist[0]["if"] and "refs/heads/main" in hist[0]["if"], "étape T-421 absente"
up = [s for s in steps if "quality-history" in str(s.get("with", {}).get("name", ""))]
assert len(up) == 1 and up[0]["if"] == "steps.history.outcome == 'success'" and up[0]["continue-on-error"] is True
del hist[0]["continue-on-error"]
yaml.safe_dump(d, open(sys.argv[2], "w"))
PYEOF
expect_fail "étape post-merge sans continue-on-error" 'job quality-coverage : étape post-merge .* sans continue-on-error' "$W/map" "$W/wf.post.yaml" "$W/steps"

if [[ "$fails" -gt 0 ]]; then
  printf 'CI-PARITY: FAIL (%s)\n' "$fails"
  exit 1
fi
printf 'CI-PARITY: PASS\n'
