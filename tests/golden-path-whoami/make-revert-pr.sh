#!/usr/bin/env bash
# make-revert-pr.sh : cree la PR de revert du changement WHOAMI_NAME depuis origin/main, dans un worktree dedie.
# N'EXECUTE RIEN SUR UN CLUSTER. Ecrit uniquement dans Git (branche, commit, push) et GitHub (PR).
#
# Usage :
#   CHANGE_SHA=<sha du merge de la PR de changement> tests/golden-path-whoami/make-revert-pr.sh
#   DRY_RUN=1 CHANGE_SHA=<sha> tests/golden-path-whoami/make-revert-pr.sh    # revert + validation, sans push
# Code retour : 0 OK ; 1 echec (revert en conflit, validation) ; 2 pre-requis.
set -uo pipefail
COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
CHANGE_SHA="${CHANGE_SHA:-}"
DRY_RUN="${DRY_RUN:-0}"; READY="${READY:-0}"
STAMP="$(date -u +%Y%m%d%H%M%S)"
BR="${BRANCH:-revert/whoami-change-$STAMP}"
WT="${WT:-$(mktemp -d)/wt-revert}"
TITLE="revert: whoami WHOAMI_NAME (rollback GitOps)"

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
if ! git revert --no-edit "$CHANGE_SHA" >/dev/null 2>&1; then
  git revert --abort >/dev/null 2>&1
  echo "git revert en conflit sur $CHANGE_SHA : ne pas forcer, traiter a la main" >&2; exit 1
fi
if ! python3 tools/appgen/appgen.py validate || ! python3 tools/appgen/appgen.py check; then
  echo "validation appgen KO apres revert : PR non creee" >&2; exit 1
fi
if git -C "$WT" grep -q "WHOAMI_NAME" -- apps/whoami; then
  echo "WHOAMI_NAME encore present apres revert" >&2; exit 1
fi

if [ "$DRY_RUN" = 1 ]; then
  echo "DRY_RUN=1 : revert de $CHANGE_SHA valide dans $WT ; rien pousse, pas de PR."
  git -C "$WT" log --oneline -1
  exit 0
fi

BODY="$(mktemp)"
cat > "$BODY" <<BODY_EOF
## Objet

Rollback GitOps de \`WHOAMI_NAME\` : revert du commit \`$CHANGE_SHA\`.
Le binding repasse sur la release d'origine \`whoami-31985273d8\` (fichier restauré par le revert).

## Preuves runtime (après merge, hors de cette PR)

\`tests/golden-path-whoami/verify-rollback.sh\` : REVERT_SHA = commit de merge de cette PR, CHANGE_SHA = \`$CHANGE_SHA\`, BASE_SHA = parent de \`$CHANGE_SHA\`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY_EOF
git push -q -u origin "$BR" || exit 1
ARGS=(--base main --head "$BR" --title "$TITLE" --body-file "$BODY")
[ "$READY" = 1 ] || ARGS+=(--draft)
gh pr create "${ARGS[@]}" || exit 1
rm -f "$BODY"
echo "PR de revert creee depuis $BR. Ne pas merger sans GO de Paul."
