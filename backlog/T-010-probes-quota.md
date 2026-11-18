---
id: T-010
title: "Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4)"
status: todo
phase: P1
adr: [0005]
depends_on: [T-001, T-002, T-061]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S3
github_issue: null
---
# T-010 — Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4)

## Intention
Ready signifie « app saine » ; le quota suit `size × replicas` et le stockage.

## Périmètre de fichiers
tools/appgen/, platform/component-types/, platform/project-types/, tests/

## Critères de fin
- [ ] readiness/liveness rendues
- [ ] quota calculé, test medium×3 et archétype C
- [ ] CI k3d verte
