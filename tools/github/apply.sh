#!/usr/bin/env bash
# Ruleset GitHub de main, as-code : JSON versionné (.github/rulesets/main-<profil>.json) + script idempotent.
# Modes :
#   (défaut)  affiche la charge utile ; aucun appel réseau en écriture, aucun appel réseau si owner/repo est donné.
#   --check   lit le ruleset (gh api, lecture seule) et sort en erreur (1) s'il diffère du JSON ; 3 = non comparable.
#             --state FICHIER : lit l'état dans un JSON local (fixture) au lieu de l'API : hors ligne.
#   --apply   crée (POST) ou met à jour (PUT) le ruleset trouvé par son nom. Idempotent. Geste de Paul (jeton admin).
# Usage : tools/github/apply.sh [--check|--apply] [--state FICHIER] [dev|final] [owner/repo]
# Aucun secret lu ni écrit. Profil final = main-final.json (T-400, FINAL0) ; absent en mode dev.
# Art antérieur : docs.github.com/en/rest/repos/rules (POST/PUT/GET repos/{r}/rulesets) ; scripts publics
#   rocky-data/rocky scripts/setup-rulesets.sh (POST seul, non idempotent : corrigé ici par recherche du nom),
#   ratel-ai/ratel scripts/setup-branch-ruleset.sh, emela-lang/emela scripts/apply-rulesets.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MODE=print
STATE=""
PROFILE=dev
REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) MODE=apply ;;
    --check) MODE=check ;;
    --state) shift; STATE="${1:?--state exige un fichier}" ;;
    dev|final) PROFILE="$1" ;;
    -*) echo "option inconnue : $1" >&2; exit 2 ;;
    *) REPO="$1" ;;
  esac
  shift
done

FILE="$ROOT/.github/rulesets/main-$PROFILE.json"
[ -f "$FILE" ] || { echo "profil $PROFILE absent : $FILE" >&2; exit 2; }
python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$FILE" || { echo "JSON invalide : $FILE" >&2; exit 2; }
NAME="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$FILE")"

if [ "$MODE" = print ]; then
  echo "# Affichage seul ($PROFILE, ${REPO:-dépôt courant}). --check pour comparer, --apply pour écrire." >&2
  cat "$FILE"
  exit 0
fi

if [ -z "$STATE" ] && [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

find_id() { gh api "repos/$REPO/rulesets" --jq ".[] | select(.name==\"$NAME\") | .id"; }

if [ "$MODE" = check ]; then
  if [ -n "$STATE" ]; then
    READ="$STATE"
  else
    ID="$(find_id)"
    [ -n "$ID" ] || { echo "DERIVE ruleset $NAME absent de $REPO"; exit 1; }
    READ="$(mktemp)"
    trap 'rm -f "$READ"' EXIT
    gh api "repos/$REPO/rulesets/$ID" >"$READ"
  fi
  rc=0
  python3 -I "$HERE/ruleset_diff.py" "$FILE" "$READ" || rc=$?
  [ "$rc" -eq 0 ] && echo "PASS ruleset $NAME conforme à $(basename "$FILE")"
  exit "$rc"
fi

# --apply
ID="$(find_id)"
if [ -n "$ID" ]; then
  gh api --method PUT "repos/$REPO/rulesets/$ID" --input "$FILE" >/dev/null
  echo "ruleset $NAME mis à jour (PUT) sur $REPO"
else
  gh api --method POST "repos/$REPO/rulesets" --input "$FILE" >/dev/null
  echo "ruleset $NAME créé (POST) sur $REPO"
fi
