#!/usr/bin/env bash
# make-revert-pr.sh : cree la PR de revert d'un changement GitOps depuis origin/main, dans un worktree dedie.
# N'EXECUTE RIEN SUR UN CLUSTER. Ecrit uniquement dans Git (branche, commit, push) et GitHub (PR).
#
# Parametres (defauts = whoami) :
#   APP=whoami           application dont app.yaml et generated/ sont revertes
#   MARKER=WHOAMI_NAME   chaine qui ne doit plus figurer dans apps/$APP apres le revert (ajoutee par le changement)
#
# Usage :
#   CHANGE_SHA=<sha du merge de la PR de changement> tests/golden-path-whoami/make-revert-pr.sh
#   APP=ntfy MARKER=NTFY_LOG_LEVEL CHANGE_SHA=<sha> tests/golden-path-whoami/make-revert-pr.sh
#   DRY_RUN=1 CHANGE_SHA=<sha> tests/golden-path-whoami/make-revert-pr.sh    # revert + validation, sans push
#
# RELEASES HISTORIQUES (append-only, CI tests/release-history/check.sh) : un `git revert` supprime la release
# ajoutée par le changement. Ce script la RESTAURE depuis CHANGE_SHA dans le MÊME commit de revert : le binding
# revient sur la release d'origine, et le fichier de la release de changement reste dans generated/.
# Code retour : 0 OK ; 1 echec (revert en conflit, validation) ; 2 pre-requis.
set -uo pipefail
COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
CHANGE_SHA="${CHANGE_SHA:-}"
APP="${APP:-whoami}"
MARKER="${MARKER:-WHOAMI_NAME}"
DRY_RUN="${DRY_RUN:-0}"; READY="${READY:-0}"
STAMP="$(date -u +%Y%m%d%H%M%S)"
BR="${BRANCH:-revert/$APP-change-$STAMP}"
WT="${WT:-$(mktemp -d)/wt-revert}"
TITLE="revert: $APP $MARKER (rollback GitOps)"

[ -n "$CHANGE_SHA" ] || { echo "CHANGE_SHA requis" >&2; exit 2; }
git -C "$REPO_ROOT" fetch -q origin main || { echo "fetch origin/main impossible" >&2; exit 2; }
if ! git -C "$REPO_ROOT" cat-file -e "$CHANGE_SHA^{commit}" 2>/dev/null; then
  echo "CHANGE_SHA inconnu" >&2; exit 2
fi
if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$CHANGE_SHA" origin/main; then
  echo "CHANGE_SHA n'est pas sur origin/main : rien a revert" >&2; exit 2
fi
git -C "$REPO_ROOT" worktree add -q -b "$BR" "$WT" origin/main || { echo "worktree impossible" >&2; exit 2; }
cleanup() { if [ "$DRY_RUN" = 1 ]; then git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null; git -C "$REPO_ROOT" branch -D "$BR" >/dev/null 2>&1; fi; true; }
trap cleanup EXIT

cd "$WT" || exit 2
if ! git revert --no-commit "$CHANGE_SHA" >/dev/null 2>&1; then
  git revert --abort >/dev/null 2>&1
  git reset -q --hard HEAD >/dev/null 2>&1
  echo "git revert en conflit sur $CHANGE_SHA : ne pas forcer, traiter a la main" >&2; exit 1
fi
# Restauration des releases supprimees par le revert (ajout seul), depuis le commit du changement.
restored=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  git checkout -q "$CHANGE_SHA" -- "$f" || { echo "restauration impossible : $f" >&2; exit 1; }
  restored=$((restored + 1))
done < <(git diff --cached --name-only --diff-filter=D -- 'generated/namespaces/default/projects/*/components/*/releases/*.yaml')
if ! python3 tools/appgen/appgen.py validate || ! python3 tools/appgen/appgen.py check --base origin/main; then
  echo "validation appgen KO apres revert : PR non creee" >&2; exit 1
fi
if git -C "$WT" grep -q "$MARKER" -- "apps/$APP"; then
  echo "$MARKER encore present apres revert" >&2; exit 1
fi
git commit -q -m "$TITLE" -m "Revert du commit $CHANGE_SHA. Releases historiques restaurees (append-only) : $restored fichier(s)." \
  || { echo "commit du revert impossible" >&2; exit 1; }
git -C "$WT" log --oneline -1

if [ "$DRY_RUN" = 1 ]; then
  echo "DRY_RUN=1 : revert de $CHANGE_SHA valide dans $WT ($restored release(s) restauree(s)) ; rien pousse, pas de PR."
  exit 0
fi

BODY="$(mktemp)"
cat > "$BODY" <<BODY_EOF
## Objet

Rollback GitOps de \`$APP\` (\`$MARKER\`) : revert du commit \`$CHANGE_SHA\`.
Le binding repasse sur la release d'origine ; la release de changement reste dans \`generated/\` (historique append-only, $restored fichier(s) restauré(s)).

## Preuves runtime (après merge, hors de cette PR)

Pour whoami : \`tests/golden-path-whoami/verify-rollback.sh\` (REVERT_SHA = commit de merge de cette PR, CHANGE_SHA = \`$CHANGE_SHA\`, BASE_SHA = parent de \`$CHANGE_SHA\`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY_EOF
git push -q -u origin "$BR" || exit 1
ARGS=(--base main --head "$BR" --title "$TITLE" --body-file "$BODY")
[ "$READY" = 1 ] || ARGS+=(--draft)
gh pr create "${ARGS[@]}" || exit 1
rm -f "$BODY"
echo "PR de revert creee depuis $BR. Ne pas merger sans GO de Paul."
