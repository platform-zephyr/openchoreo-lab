#!/usr/bin/env bash
# Cree/met a jour le ruleset GitHub sur main : PR obligatoire, check "ci-ok" requis, revue des code owners (CODEOWNERS :
# zones sensibles = approbation de Paul ; apps/** et generated/** libres), pas de force push, pas de suppression.
# L'admin du depot (Paul) peut contourner en mode "pull_request" (merge explicite) ; un compte agent (role Write) ne le peut pas.
# Par defaut : affiche la charge utile (aucun appel reseau en ecriture). Ecriture seulement avec --apply.
# Usage : tools/apply-branch-protection.sh [--apply] [owner/repo]
# Prerequis pour --apply : gh authentifie avec des droits d'administration du depot.
set -euo pipefail

APPLY=0
REPO=""
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    -*) echo "option inconnue : $arg" >&2; exit 2 ;;
    *) REPO="$arg" ;;
  esac
done
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

PAYLOAD="$(cat <<JSON
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}],
  "rules": [
    {"type": "non_fast_forward"},
    {"type": "deletion"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": true,
      "require_code_owner_review": true,
      "require_last_push_approval": false,
      "required_review_thread_resolution": false
    }},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": true,
      "required_status_checks": [{"context": "ci-ok"}]
    }}
  ]
}
JSON
)"

if [ "$APPLY" -eq 0 ]; then
  echo "# Dry-run pour $REPO. Relancer avec --apply pour creer le ruleset."
  echo "$PAYLOAD"
  exit 0
fi

ID="$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name=="main-protection") | .id')"
if [ -n "$ID" ]; then
  echo "$PAYLOAD" | gh api --method PUT "repos/$REPO/rulesets/$ID" --input -
else
  echo "$PAYLOAD" | gh api --method POST "repos/$REPO/rulesets" --input -
fi
