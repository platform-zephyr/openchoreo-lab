---
id: T-013
title: "Surcharges par environnement (G12)"
status: deferred
phase: P5
adr: [0005, 0004]
depends_on: [T-003]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: après-porte
github_issue: null
---
# T-013 — Surcharges par environnement (G12)

## Intention
`overrides.<env>` (size, replicas, env).

## Périmètre de fichiers
docs/schema/, tools/appgen/

## Critères de fin
- [ ] tests appgen
- [ ] valeurs effectives vérifiées par la garde de frugalité

## Notes
Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
