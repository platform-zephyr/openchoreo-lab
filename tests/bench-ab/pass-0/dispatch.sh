#!/usr/bin/env bash
# Passe 0 du banc A/B (T-486) : pour une tâche et un bras, affiche la commande de dispatch de l'usine
# (.github/workflows/claude-agent.yml) et enregistre le résultat attendu dans un fichier de run `bench-run.v1`, rang 0.
# Ne lance rien : aucun réseau, aucun cluster, aucun secret. Le fichier de run ne porte que des noms publics du dépôt.
#
# Usage : tests/bench-ab/pass-0/dispatch.sh <M1..M4|P1..P3> <K|O> --issue <numéro> [--out-dir D] [--force]
#   --issue    numéro de l'issue du dépôt du bras, créée avec la consigne de tests/bench-ab/{tasks,traps}/<id>.<bras>.yaml
#              (le workflow prend des numéros d'issue : entrée `tickets`)
#   --out-dir  répertoire du fichier de run (défaut : tests/bench-ab/pass-0/runs)
#   --force    remplace un fichier de run existant (corrections libres de la passe 0)
# Sortie standard : la commande `gh workflow run`. Codes : 0 ok ; 2 usage, tâche ou bras inconnu ; 3 fichier existant.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="$(cd "$HERE/.." && pwd)"
WORKFLOW="claude-agent.yml"
MODEL="claude-sonnet-5-5"
EFFORT="high"
REPO_O="platform-zephyr/openchoreo-lab"
REPO_K="platform-zephyr/bench-ab-arm-k"

die() {
  printf 'dispatch.sh : %s\n' "$1" >&2
  exit "${2:-2}"
}

issue="" out_dir="$HERE/runs" force=0
pos=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue | --out-dir)
      [[ $# -ge 2 ]] || die "$1 sans valeur"
      if [[ "$1" == "--issue" ]]; then issue="$2"; else out_dir="$2"; fi
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h | --help)
      sed -n '2,12p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    -*) die "option inconnue : $1" ;;
    *)
      pos+=("$1")
      shift
      ;;
  esac
done
[[ ${#pos[@]} -eq 2 ]] || die "attendu : <tâche> <bras> --issue <numéro>"
task="${pos[0]}"
arm="${pos[1]}"

case "$task" in
  M1 | M2 | M3 | M4) kind="tasks" ;;
  P1 | P2 | P3) kind="traps" ;;
  *) die "tâche inconnue : '$task' (M1-M4, P1-P3)" ;;
esac
case "$arm" in
  K) repo="$REPO_K" ;;
  O) repo="$REPO_O" ;;
  *) die "bras inconnu : '$arm' (K ou O)" ;;
esac
[[ "$kind" == "tasks" || "$arm" == "O" ]] || die "passe 0 : les pièges ne se jouent qu'avec le bras O"
[[ "$issue" =~ ^[0-9]+$ ]] || die "--issue doit être un numéro d'issue"

spec="$BENCH/$kind/$task.$arm.yaml"
[[ -f "$spec" ]] || die "consigne absente : $spec"
field() { sed -n "s/^$1: *//p" "$spec" | head -n 1; }
app="$(field app)"
grader="$(field grader)"
[[ -n "$app" && -n "$grader" ]] || die "consigne incomplète : $spec"
spec_sha="$(sha256sum "$spec" | cut -d' ' -f1)"

fault=""
if [[ "$task" == "M4" ]]; then
  fault="$(sed -n 's/^  0: *//p' "$BENCH/draw.yaml" | head -n 1)"
  [[ -n "$fault" ]] || die "tirage du rang 0 absent de draw.yaml"
fi

cmd="gh workflow run $WORKFLOW --repo $repo -f tickets=$issue -f model=$MODEL -f effort=$EFFORT"

mkdir -p "$out_dir"
file="$out_dir/$task.$arm.r0.json"
if [[ -e "$file" && "$force" -ne 1 ]]; then
  die "fichier de run déjà présent : $file (--force pour le remplacer)" 3
fi

# Résultat attendu : PASS (tâche réussie, ou piège contenu). Statut réel et observations restent à remplir après le run.
{
  printf '{\n'
  printf '  "schema": "bench-run.v1",\n'
  printf '  "arm": "%s",\n' "$arm"
  printf '  "task": "%s",\n' "$task"
  printf '  "rank": 0,\n'
  printf '  "counted": false,\n'
  printf '  "state": "planned",\n'
  printf '  "app": "%s",\n' "$app"
  printf '  "grader": "%s",\n' "$grader"
  printf '  "repo": "%s",\n' "$repo"
  printf '  "workflow": "%s",\n' "$WORKFLOW"
  printf '  "issue": %s,\n' "$issue"
  printf '  "model": "%s",\n' "$MODEL"
  printf '  "effort": "%s",\n' "$EFFORT"
  printf '  "dispatch": "%s",\n' "$cmd"
  printf '  "task_file_sha256": "%s",\n' "$spec_sha"
  if [[ -n "$fault" ]]; then printf '  "injected_fault": "%s",\n' "$fault"; fi
  printf '  "expected_status": "PASS",\n'
  printf '  "actual_status": null,\n'
  printf '  "evidence_level": null,\n'
  printf '  "check_run": null,\n'
  printf '  "observations": null\n'
  printf '}\n'
} >"$file"

printf '%s\n' "$cmd"
printf 'run enregistré : %s\n' "$file" >&2
