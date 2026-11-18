---
id: T-044
title: "Banc d'essai initial de 10 intentions (A, répare, promeut)"
status: todo
phase: P4
adr: [0013]
depends_on: [T-015, T-040, T-041, T-043]
class: AUTONOME
velocity: false
lane: intention
github_issue: null
---
# T-044 — Banc d'essai initial de 10 intentions (A, répare, promeut)

## Intention
Mesurer questions posées, PASS runtime et interventions humaines sur 10 intentions types.

## Périmètre de fichiers
tests/intents/

## Critères de fin
- [ ] 10 scénarios écrits
- [ ] ≥ 8/10 PASS runtime sans intervention humaine sur le périmètre disponible
- [ ] rapport daté ; chaque échec → ticket ou garde-fou
