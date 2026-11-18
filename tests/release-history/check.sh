#!/usr/bin/env bash
# Garde CI : une PR (ou un push) ne doit supprimer AUCUNE ComponentRelease historique
# (generated/**/releases/*.yaml), sauf si l'application est retirée (apps/<nom>/ supprimé dans le même diff).
# Un `git revert` d'un changement supprime le fichier de release ajouté : le restaurer (voir make-revert-pr.sh).
# Usage : tests/release-history/check.sh [BASE_REV]   (défaut : origin/$GITHUB_BASE_REF, sinon HEAD^)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
BASE="${1:-}"
if [ -z "$BASE" ]; then
  if [ -n "${MERGE_GROUP_BASE_SHA:-}" ]; then BASE="$MERGE_GROUP_BASE_SHA"   # file de fusion : base = tête de main
  elif [ -n "${GITHUB_BASE_REF:-}" ]; then BASE="origin/$GITHUB_BASE_REF"; else BASE="HEAD^"; fi
fi
git rev-parse --verify -q "$BASE" >/dev/null || { echo "base introuvable : $BASE (fetch-depth: 0 requis)" >&2; exit 2; }
fail=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  app="$(sed -n 's#^generated/namespaces/default/projects/\([^/]*\)/.*#\1#p' <<<"$f")"
  if git diff --name-only --diff-filter=D "$BASE" HEAD -- "apps/$app" | grep -q . && [ ! -d "apps/$app" ]; then
    echo "OK    $f supprimée avec l'application $app (retrait)"; continue
  fi
  echo "FAIL  release historique supprimée : $f (restaurer le fichier ; append-only)" >&2; fail=1
done < <(git diff --name-only --diff-filter=D "$BASE" HEAD -- 'generated/namespaces/default/projects/*/components/*/releases/*.yaml')
[ "$fail" = 0 ] && echo "PASS aucune release historique supprimée (base $BASE)"
exit "$fail"
