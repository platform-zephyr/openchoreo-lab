---
id: T-042
title: "Atlas : entrée de catalogue et skill de routage d'intention"
status: deferred
phase: P5
adr: [0012, 0013]
depends_on: [T-041]
class: REVUE + MANDAT
velocity: false
lane: connaissance
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-042 — Atlas : entrée de catalogue et skill de routage d'intention

## Intention
Une intention en langage naturel est routée vers le bon dépôt et le bon skill.

## Périmètre de fichiers
dépôt Atlas (PR séparée)

## Critères de fin
- [ ] entrée openchoreo-lab dans `repos/catalog.md`
- [ ] skill `route-intent` + index machine-lisible
- [ ] PR Atlas ouverte (accès en écriture à donner)

## Notes
Accès en écriture au dépôt Atlas à donner par Paul.

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
