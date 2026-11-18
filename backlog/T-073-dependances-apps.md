---
id: T-073
title: "Dépendances entre apps `dependsOn` (G11)"
status: deferred
phase: P5
adr: [0005]
depends_on: [T-021]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-073 — Dépendances entre apps `dependsOn` (G11)

## Intention
Egress ciblé + variable d'URL vers une autre app.

## Périmètre de fichiers
docs/schema/, tools/appgen/

## Critères de fin
- [ ] tests appgen
- [ ] NetworkPolicy d'egress ciblée rendue
- [ ] preuve k3d A → B

## Notes
Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
