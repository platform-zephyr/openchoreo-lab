#!/usr/bin/env bash
# Enveloppe conservée pour ses citations (T-400, ADR-0002, docs) : la charge utile vit désormais dans
# .github/rulesets/main-dev.json et le script dans tools/github/apply.sh (T-430).
# Mode dev (arbitrage 7) : revue des code owners DÉSACTIVÉE (require_code_owner_review=false) ; bypass Admin en mode
# pull_request. La revue des code owners revient avec main-final.json (T-400, FINAL0), jamais avant.
# Par défaut : affiche la charge utile (aucune écriture). --apply : crée/met à jour le ruleset (jeton admin, geste de Paul).
# Usage : tools/apply-branch-protection.sh [--apply|--check] [owner/repo]
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/github/apply.sh" dev "$@"
