---
id: T-430
title: "Rulesets as-code : tools/github/apply.sh (--check/--apply) et main-dev.json alignés sur l'ADR-0002"
status: done
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: true
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-430 — Rulesets as-code : tools/github/apply.sh (--check/--apply) et main-dev.json alignés sur l'ADR-0002

## Intention
Remplacer la charge utile en ligne du script par des JSON versionnés et un script idempotent à deux modes (--check sort en erreur si l'état lu diffère). Corriger require_code_owner_review (false en dev, amendement n°2 de l'ADR-0002). apply-branch-protection.sh reste comme enveloppe.

## Périmètre de fichiers
tools/github/, .github/rulesets/main-dev.json, tools/apply-branch-protection.sh, .github/CODEOWNERS, tests/github-config/

## Critères de fin
- [x] main-dev.json : non_fast_forward, deletion, PR (0 approbation, code owners false), merge_queue SQUASH, check ci-ok, bypass Admin en mode pull_request
- [x] apply.sh : affichage sans écriture par défaut, PUT/PATCH idempotents, aucune valeur secrète lue ni écrite
- [x] test hors ligne : JSON valide, --check détecte une dérive simulée (cas négatif)
- [x] /tools/github/ et /.github/rulesets/ présents dans CODEOWNERS
- [x] `tools/apply-branch-protection.sh` ne réactive PAS la revue des code owners avant FINAL0 : `require_code_owner_review` y vaut `false` (test hors ligne) ; la valeur `true` n'existe que dans `main-final.json` (T-400)

## Notes
Proposition GH-1 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Paul exécute --apply (jeton admin). L'agent n'a ni jeton admin ni accès à l'API des réglages. Absorbe la charge utile de tools/apply-branch-protection.sh sans changer son nom (cité par T-400, ADR et docs).

Écart constaté dans `tools/apply-branch-protection.sh` : sa charge utile en ligne contient `"require_code_owner_review": true` (ligne 36). En mode dev (arbitrage 7 de Paul, CONSENSUS-2) l'option doit rester `false` jusqu'à FINAL0 : l'appliquer en l'état bloquerait les PR du noyau que les agents fusionnent eux-mêmes. Ce ticket corrige l'écart (JSON `main-dev.json`, script en enveloppe). La revue des code owners est réactivée seulement par T-400 (FINAL0, sur `platform/authz/`, `platform/policies/` et `security/`) puis à FINAL. Geste de Paul : `--apply` avec un jeton admin ; l'agent n'en a pas.

Preuves (STATIC, 2026-11-18) : `tests/github-config/run.sh` (18 PASS hors ligne, cas de dérive négatifs inclus), shellcheck propre, `tools/backlog/check.py` 0 erreur. NOT_TESTED : `--check` réel (jeton `gh` invalide dans la session) et `--apply` (geste de Paul). Reste `in-progress` jusqu'au premier `--apply` puis `--check` PASS de Paul.
