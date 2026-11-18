---
id: T-041
title: "Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur"
status: todo
phase: P0
adr: [0012]
depends_on: []
class: REVUE
velocity: true
lane: connaissance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-041 — Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur

## Intention
Appliquer la proposition `docs/research/context-engineering/` dans ce dépôt.

## Périmètre de fichiers
AGENTS.md, STATE.md, docs/, tools/, tests/

## Critères de fin
- [ ] fichiers toujours chargés ≤ 130 lignes au total
- [ ] check CI taille/liens/fraîcheur
- [ ] aucune règle impérative perdue (diff relu)

## Notes
Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).
