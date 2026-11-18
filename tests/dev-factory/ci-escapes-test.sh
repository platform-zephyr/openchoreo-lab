#!/usr/bin/env bash
# Tests de tools/dev/ci-escapes.py (SL-7, T-461) : HORS LIGNE (fixture JSON), sans réseau, gh ni cluster.
#  1. Calcul : évasions par PR (niveau <= L2), taux, premier push vert, minutes jusqu'au vert, jobs non listés,
#     candidats « décaler à gauche », ci-ok ignoré, runs annulés ignorés, matrice « job (x) » -> « job ».
#  2. Rapport : fichiers datés ci-escapes-AAAA-Www.{json,md} écrits dans --out.
#  3. Lecture seule : gh n'est appelé qu'avec `api -X GET` (ou `repo view`) ; test négatif sur un faux gh qui refuse le reste.
#  4. Cas négatifs : --days 0, fixture illisible, --now invalide -> rc 2, rien sur stdout.
# Usage : tests/dev-factory/ci-escapes-test.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/ci-escapes-test.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
TOOL="$PWD/tools/dev/ci-escapes.py"
NOW="2026-11-18T12:00:00Z"

# Table de niveaux minimale (indépendante de ci.yaml) et fixture : 4 PR dans la période, 1 hors période.
printf 'yamllint\tyamllint\tL2\tcheck\nplatform-render\tx\tL3\tcheck\nquality\tquality\tL1\tcheck\nLOCAL-ONLY\tfoo\t-\traison\n' >"$W/map.tsv"
cat >"$W/fx.json" <<'JSON'
{"runs": [
 {"id": 1, "conclusion": "failure", "created_at": "2026-11-17T10:00:00Z", "updated_at": "2026-11-17T10:05:00Z", "pull_requests": [{"number": 10}]},
 {"id": 2, "conclusion": "success", "created_at": "2026-11-17T10:30:00Z", "updated_at": "2026-11-17T10:40:00Z", "pull_requests": [{"number": 10}]},
 {"id": 3, "conclusion": "success", "created_at": "2026-11-17T11:00:00Z", "updated_at": "2026-11-17T11:06:00Z", "pull_requests": [{"number": 11}]},
 {"id": 4, "conclusion": "failure", "created_at": "2026-11-17T12:00:00Z", "updated_at": "2026-11-17T12:05:00Z", "pull_requests": [{"number": 12}]},
 {"id": 5, "conclusion": "cancelled", "created_at": "2026-11-17T12:10:00Z", "updated_at": "2026-11-17T12:11:00Z", "pull_requests": [{"number": 12}]},
 {"id": 6, "conclusion": "failure", "created_at": "2026-11-17T13:00:00Z", "updated_at": "2026-11-17T13:05:00Z", "pull_requests": [{"number": 13}]},
 {"id": 7, "conclusion": "failure", "created_at": "2026-10-01T13:00:00Z", "updated_at": "2026-10-01T13:05:00Z", "pull_requests": [{"number": 99}]}
], "jobs": {
 "1": [{"name": "yamllint", "conclusion": "failure"}, {"name": "quality", "conclusion": "failure"}, {"name": "ci-ok", "conclusion": "failure"}, {"name": "appgen", "conclusion": "success"}],
 "4": [{"name": "platform-render", "conclusion": "failure"}, {"name": "inconnu (x)", "conclusion": "failure"}, {"name": "ci-ok", "conclusion": "failure"}],
 "6": [{"name": "platform-render (a)", "conclusion": "failure"}],
 "7": [{"name": "yamllint", "conclusion": "failure"}]
}}
JSON

run() { python3 -I "$TOOL" --map "$W/map.tsv" --fixture "$W/fx.json" --now "$NOW" "$@"; }
if run --json >"$W/out.json" 2>"$W/err"; then ok "rapport JSON produit (rc 0)"; else ko "rapport JSON (rc != 0) : $(cat "$W/err")"; fi
chk() { # NOM EXPRESSION_PYTHON (r = rapport)
  if python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if eval(sys.argv[2]) else 1)' "$W/out.json" "$2"; then ok "$1"; else ko "$1"; fi
}
chk "schéma ci-escapes.v1" 'r["schema"]=="ci-escapes.v1"'
chk "4 PR dans la période (le run de 2026-10-01 est exclu)" '[p["pr"] for p in r["prs"]]==["#10","#11","#12","#13"]'
chk "évasions : PR #10 = yamllint (L2) + quality (L1), ci-ok ignoré" '{(e["pr"],e["job"],e["niveau"]) for e in r["prs"][0]["escapes"]}=={("#10","yamllint","L2"),("#10","quality","L1")}'
chk "PR #10 : 2 runs, rouge au 1er push, 40 min jusqu'au vert" 'r["prs"][0]["ci_runs_per_pr"]==2 and r["prs"][0]["first_push_green"] is False and r["prs"][0]["minutes_to_green"]==40.0'
chk "PR #11 : verte au 1er push, 6 min" 'r["prs"][1]["first_push_green"] is True and r["prs"][1]["minutes_to_green"]==6.0'
chk "PR #12 : run annulé ignoré (1 run), jamais vert -> minutes None, job L3 hors évasion" 'r["prs"][2]["ci_runs_per_pr"]==1 and r["prs"][2]["minutes_to_green"] is None and r["prs"][2]["escapes"]==[]'
chk "jobs rouges = 5, évasions = 2, taux 0.4" 'r["red_jobs"]==5 and r["escapes_count"]==2 and r["escape_rate"]==0.4'
chk "job absent de la table listé, non compté" 'r["unmapped_jobs"]==["inconnu"]'
chk "candidat décaler à gauche : platform-render (L3) sur #12 et #13" 'r["shift_left_candidates"]==[{"job":"platform-render","niveau":"L3","prs":["#12","#13"]}]'
chk "taux de PR vertes au premier push = 0.25" 'r["first_push_green_rate"]==0.25'

# Rapport daté.
if run --out "$W/rapports" >"$W/md" 2>/dev/null && [[ -f "$W/rapports/ci-escapes-2026-W47.json" && -f "$W/rapports/ci-escapes-2026-W47.md" ]] \
  && grep -q '^# Évasions de la CI : semaine 2026-W47' "$W/rapports/ci-escapes-2026-W47.md" && grep -q '^| #10 ' "$W/md"; then
  ok "rapport hebdomadaire daté (ci-escapes-2026-W47.{json,md})"
else
  ko "rapport hebdomadaire daté"
fi

# Période sans run : taux None, pas de division par zéro.
printf '{"runs": [], "jobs": {}}' >"$W/empty.json"
if python3 -I "$TOOL" --map "$W/map.tsv" --fixture "$W/empty.json" --now "$NOW" --json | python3 -I -c 'import json,sys; r=json.load(sys.stdin); sys.exit(0 if r["escape_rate"] is None and r["prs_count"]==0 else 1)'; then
  ok "période vide : taux None"
else
  ko "période vide"
fi

# Lecture seule : faux gh qui journalise ses arguments et refuse tout sauf `api -X GET` et `repo view`.
mkdir -p "$W/bin"
cat >"$W/bin/gh" <<'SH'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
case "$*" in
  "api -X GET repos/o/r/actions/workflows/ci.yaml/runs?"*) echo '{"workflow_runs": [{"id": 5, "conclusion": "failure", "created_at": "2026-11-17T10:00:00Z", "updated_at": "2026-11-17T10:05:00Z", "pull_requests": [{"number": 7}]}]}' ;;
  "api -X GET repos/o/r/actions/runs/5/jobs?"*) echo '{"jobs": [{"name": "yamllint", "conclusion": "failure"}]}' ;;
  *) echo "refusé : $*" >&2; exit 9 ;;
esac
SH
chmod +x "$W/bin/gh"
if GH_LOG="$W/gh.log" PATH="$W/bin:$PATH" python3 -I "$TOOL" --map "$W/map.tsv" --repo o/r --now "$NOW" --json >"$W/live.json" 2>"$W/err" \
  && [[ -s "$W/gh.log" ]] && ! grep -vq '^api -X GET ' "$W/gh.log" \
  && python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["escapes_count"]==1 else 1)' "$W/live.json"; then
  ok "lecture seule : $(wc -l <"$W/gh.log") appel(s) gh, tous « api -X GET »"
else
  ko "lecture seule / lecture en ligne simulée : $(cat "$W/err") $(cat "$W/gh.log" 2>/dev/null)"
fi
if ! grep -nE '"(POST|PUT|PATCH|DELETE)"|-X", "(POST|PUT|PATCH|DELETE)|--method|-f ' "$TOOL" >/dev/null; then
  ok "source : aucune méthode d'écriture HTTP"
else
  ko "source : méthode d'écriture HTTP trouvée"
fi

# Cas négatifs : rc 2 et stdout vide.
neg() { # NOM ARGS...
  local name="$1" rc=0
  shift
  python3 -I "$TOOL" "$@" >"$W/nout" 2>"$W/nerr" || rc=$?
  if [[ "$rc" -eq 2 && ! -s "$W/nout" ]]; then ok "refus : $name"; else ko "refus : $name (rc=$rc)"; fi
}
neg "--days 0" --map "$W/map.tsv" --fixture "$W/fx.json" --days 0
neg "fixture absente" --map "$W/map.tsv" --fixture "$W/absent.json"
neg "--now invalide" --map "$W/map.tsv" --fixture "$W/fx.json" --now hier
printf 'pas du json' >"$W/bad.json"
neg "fixture non JSON" --map "$W/map.tsv" --fixture "$W/bad.json"
GH_LOG="$W/gh2.log" PATH="$W/bin:$PATH" python3 -I "$TOOL" --map "$W/map.tsv" --repo pas-un-depot --now "$NOW" >/dev/null 2>&1; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "refus : lecture gh en échec (rc 2)"; else ko "lecture gh en échec (rc=$rc)"; fi

# Sur la vraie table : tous les niveaux se lisent (L1..L3) et ci-map.tsv couvre les jobs de ci.yaml.
if python3 -I -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("e",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); l=m.load_levels(); sys.exit(0 if l.get("yamllint")==2 and l.get("platform-render")==3 and len(l)>=10 else 1)' "$TOOL"; then
  ok "ci-map.tsv réelle : niveaux lus"
else
  ko "ci-map.tsv réelle : niveaux illisibles"
fi

if [[ "$fails" -gt 0 ]]; then printf 'CI-ESCAPES-TEST: FAIL (%s)\n' "$fails"; exit 1; fi
printf 'CI-ESCAPES-TEST: PASS\n'
