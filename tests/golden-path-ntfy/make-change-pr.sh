#!/usr/bin/env bash
# make-change-pr.sh : cree la PR de changement GitOps de ntfy (preuve : NTFY_LOG_LEVEL=DEBUG) depuis origin/main,
# dans un worktree dedie. N'EXECUTE RIEN SUR UN CLUSTER. Ecrit uniquement dans Git (branche, commit, push) et GitHub.
#
# Le changement est applique par script (pas de patch fige) : ajout d'UNE ligne NTFY_LOG_LEVEL dans
# apps/ntfy/app.yaml, puis `appgen render` (nouvelle release, ancienne conservee), validation et check.
# Usage :
#   tests/golden-path-ntfy/make-change-pr.sh                 # PR draft
#   DRY_RUN=1 tests/golden-path-ntfy/make-change-pr.sh       # applique, valide, ne pousse rien
#   READY=1 tests/golden-path-ntfy/make-change-pr.sh         # PR non draft (decision de Paul)
# Revert : APP=ntfy MARKER=NTFY_LOG_LEVEL CHANGE_SHA=<merge> tests/golden-path-whoami/make-revert-pr.sh
# Code retour : 0 OK ; 1 echec de validation ; 2 pre-requis.
set -uo pipefail
COMMON_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
STAMP="$(date -u +%Y%m%d%H%M%S)"
BR="${BRANCH:-app/ntfy-change-$STAMP}"
WT="${WT:-$(mktemp -d)/wt-ntfy-change}"
DRY_RUN="${DRY_RUN:-0}"; READY="${READY:-0}"
TITLE="ntfy: NTFY_LOG_LEVEL=DEBUG (preuve GitOps)"

git -C "$REPO_ROOT" fetch -q origin main || { echo "fetch origin/main impossible" >&2; exit 2; }
git -C "$REPO_ROOT" worktree add -q -b "$BR" "$WT" origin/main || { echo "worktree impossible" >&2; exit 2; }
cleanup() { if [ "$DRY_RUN" = 1 ]; then git -C "$REPO_ROOT" worktree remove --force "$WT" 2>/dev/null; git -C "$REPO_ROOT" branch -D "$BR" >/dev/null 2>&1; fi; true; }
trap cleanup EXIT

cd "$WT" || exit 2
python3 -I - apps/ntfy/app.yaml <<'PY' || { echo "ligne NTFY_LISTEN_HTTP introuvable : base ntfy inattendue" >&2; exit 2; }
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
anchor = '      NTFY_LISTEN_HTTP: ":8080"\n'
if s.count(anchor) != 1 or "NTFY_LOG_LEVEL" in s:
    sys.exit(1)
p.write_text(s.replace(anchor, anchor + "      NTFY_LOG_LEVEL: DEBUG\n", 1), encoding="utf-8")
PY
python3 tools/appgen/appgen.py validate || { echo "validation appgen KO : PR non creee" >&2; exit 1; }
python3 tools/appgen/appgen.py render >/dev/null || { echo "render KO" >&2; exit 1; }
if ! python3 tools/appgen/appgen.py check --base origin/main; then
  echo "appgen check --base KO : PR non creee" >&2; exit 1
fi
if ! git status --porcelain -- apps generated | grep -q .; then
  echo "aucun changement applique : rien a proposer" >&2; exit 1
fi

BODY="$(mktemp)"
cat > "$BODY" <<BODY_EOF
## Objet

Changement GitOps de preuve sur ntfy : \`NTFY_LOG_LEVEL=DEBUG\` dans \`apps/ntfy/app.yaml\`, rendu par \`appgen\`.
La release précédente reste dans \`generated/\` (historique append-only) ; le binding pointe la nouvelle release.

## Validé

- \`appgen validate\`, \`appgen render\`, \`appgen check --base origin/main\` : OK.
- Avertissement attendu : 2e PR \`pin-project\` après le premier déploiement OKE de ntfy (paramètres du Project).

## Preuves runtime (après merge, hors de cette PR)

\`tests/golden-path-ntfy/verify-http.sh\` avec \`EXPECT_REVISION=<merge>\` \`EXPECT_LOG_LEVEL=DEBUG\`.
Le revert est la PR produite par \`APP=ntfy MARKER=NTFY_LOG_LEVEL make-revert-pr.sh\`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY_EOF

if [ "$DRY_RUN" = 1 ]; then
  echo "DRY_RUN=1 : branche $BR validee dans $WT ; rien pousse, pas de PR."
  git status --short apps generated
  rm -f "$BODY"; exit 0
fi

git add -A apps/ntfy generated || exit 1
git commit -q -m "$TITLE

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>" || exit 1
git push -q -u origin "$BR" || exit 1
ARGS=(--base main --head "$BR" --title "$TITLE" --body-file "$BODY")
[ "$READY" = 1 ] || ARGS+=(--draft)
gh pr create "${ARGS[@]}" || exit 1
rm -f "$BODY"
echo "PR creee depuis $BR. Ne pas merger sans GO de Paul."
