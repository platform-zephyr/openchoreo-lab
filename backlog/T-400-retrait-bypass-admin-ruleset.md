---
id: T-400
title: "Retirer le contournement admin du ruleset (bypass_actors) et écrire la procédure de réactivation ponctuelle"
status: todo
phase: P4
adr: [0002]
depends_on: [T-007, T-215]
class: REVUE + MANDAT
velocity: false
lane: gouvernance
stage: FINAL0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-400 — Retirer le contournement admin du ruleset (bypass_actors) et écrire la procédure de réactivation ponctuelle

## Intention
Plus aucun compte, même admin, ne contourne `ci-ok` et la revue des code owners. Paul réactive le contournement à la main, ponctuellement, et le retire aussitôt.

## Périmètre de fichiers
tools/apply-branch-protection.sh, docs/AGENT-PR-MODEL.md

## Critères de fin
- [ ] `bypass_actors` vide dans le ruleset appliqué (lecture de l'API datée, sans jeton affiché)
- [ ] procédure écrite : réactivation ponctuelle par Paul, motif consigné, retrait immédiat
- [ ] essai : une PR sans `ci-ok` verte n'est fusionnable par aucun compte (preuve datée)
- [ ] revue des code owners réactivée sur `platform/authz/`, `platform/policies/` et `security/` (lecture datée du ruleset, sans jeton affiché)

## Notes
Décision 1 du consensus n°2, déplacée dans l'étape FINAL par l'arbitrage 4. MANDAT : réglage du ruleset par Paul.
