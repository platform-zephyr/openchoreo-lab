---
id: T-044
title: "Banc d'essai de 5 intentions A (MVP)"
status: todo
phase: P1
adr: [0013]
depends_on: [T-015, T-040, T-041, T-043, T-061, T-061b, T-212]
class: AUTONOME
velocity: false
lane: intention
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-044 — Banc d'essai de 5 intentions A (MVP)

## Intention
Mesurer questions posées, PASS runtime et interventions humaines sur 10 intentions types.

## Périmètre de fichiers
tests/intents/

## Critères de fin
- [ ] 5 intentions A écrites
- [ ] 5/5 PASS runtime sur le homelab, délai médian ≤ 30 min (C1)
- [ ] rapport daté
- [ ] banc exécuté pour les deux moteurs (OpenChoreo et plain), mêmes intentions, ordre croisé (G3)
