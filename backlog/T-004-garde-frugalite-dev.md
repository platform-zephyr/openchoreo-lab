---
id: T-004
title: "Check CI de frugalité du dev"
status: todo
phase: P1
adr: [0004]
depends_on: [T-003, T-061]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: S3
github_issue: 50
---
# T-004 — Check CI de frugalité du dev

## Intention
Refuser : plus de 2 apps en development, `replicas` > 1 ou `size` ≠ small en dev, stockage ou base en dev sur OKE.

## Périmètre de fichiers
tools/appgen/, tests/appgen/

## Critères de fin
- [ ] un test par refus
- [ ] message d'erreur typé avec la correction attendue
- [ ] contrôle des valeurs effectives après `overrides` (T-013)
