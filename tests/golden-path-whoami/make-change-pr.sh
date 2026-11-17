#!/usr/bin/env bash
# make-change-pr.sh : cree la PR de changement WHOAMI_NAME depuis origin/main, dans un worktree dedie.
# N'EXECUTE RIEN SUR UN CLUSTER. Ecrit uniquement dans Git (branche, commit, push) et GitHub (PR).
#
# Usage :
#   tests/golden-path-whoami/make-change-pr.sh                 # PR draft
#   DRY_RUN=1 tests/golden-path-whoami/make-change-pr.sh       # applique, valide, ne pousse rien
#   READY=1 tests/golden-path-whoami/make-change-pr.sh         # PR non draft (decision de Paul)
#
# Pre-requis : tests/golden-path-whoami/change.patch s'applique sur origin/main (sinon regenerer, voir docs).
# Code retour : 0 OK ; 1 echec de validation ; 2 pre-requis.
set -uo pipefail
COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
PATCH="$COMMON_DIR/change.patch"
STAMP="$(date -u +%Y%m%d%H%M%S)"
BR="${BRANCH:-app/whoami-change-$STAMP}"
WT="${WT:-$(mktemp -d)/wt-change}"
DRY_RUN="${DRY_RUN:-0}"; READY="${READY:-0}"
TITLE="whoami: WHOAMI_NAME (preuve GitOps)"

[ -f "$PATCH" ] || { echo "change.patch introuvable : $PATCH" >&2; exit 2; }
git -C "$REPO_ROOT" fetch -q origin main || { echo "fetch origin/main impossible" >&2; exit 2; }
git -C "$REPO_ROOT" worktree add -q -b "$BR" "$WT" origin/main || { echo "worktree impossible" >&2; exit 2; }
cleanup() { if [ "$DRY_RUN" = 1 ]; then git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null; git -C "$REPO_ROOT" branch -D "$BR" >/dev/null 2>&1; fi; true; }
trap cleanup EXIT

cd "$WT" || exit 2
if ! git apply --check "$PATCH"; then
  echo "change.patch ne s'applique plus sur origin/main : regenerer (apps/whoami/app.yaml, puis appgen render) et re-produire le patch" >&2
  exit 2
fi
git apply "$PATCH" || exit 2
if ! python3 tools/appgen/appgen.py validate || ! python3 tools/appgen/appgen.py check; then
  echo "validation appgen KO : PR non creee" >&2; exit 1
fi
if ! git status --porcelain -- apps generated | grep -q .; then
  echo "aucun changement applique : rien a proposer" >&2; exit 1
fi

BODY="$(mktemp)"
cat > "$BODY" <<BODY_EOF
## Objet

Changement GitOps de preuve : \`WHOAMI_NAME=whoami-gitops-oke-v2\` dans \`apps/whoami/app.yaml\`, rendu par \`appgen\`.
Release de changement : \`whoami-69a1749676\` (la release de base \`whoami-647fc6bfc1\` reste dans \`generated/\`).

## Validé

- \`appgen validate\` et \`appgen check\` : OK sur la base courante.

## Preuves runtime (après merge, hors de cette PR)

\`tests/golden-path-whoami/verify-change.sh\` (CHANGE_SHA = commit de merge, BASE_SHA = son parent).
Le rollback est la PR de revert correspondante (\`make-revert-pr.sh\`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY_EOF

if [ "$DRY_RUN" = 1 ]; then
  echo "DRY_RUN=1 : branche $BR validee dans $WT ; rien pousse, pas de PR."
  git status --short apps generated
  rm -f "$BODY"; exit 0
fi

git add -A apps/whoami generated
git commit -q -m "$TITLE

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>" || exit 1
git push -q -u origin "$BR" || exit 1
ARGS=(--base main --head "$BR" --title "$TITLE" --body-file "$BODY")
[ "$READY" = 1 ] || ARGS+=(--draft)
gh pr create "${ARGS[@]}" || exit 1
rm -f "$BODY"
echo "PR creee depuis $BR. Ne pas merger sans GO de Paul. Puis : CHANGE_SHA=<merge> BASE_SHA=<parent> verify-change.sh"
