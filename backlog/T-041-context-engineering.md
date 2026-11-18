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
stage: S0
model: claude-sonnet-5-5
effort: medium
routing: R10-code-simple
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
