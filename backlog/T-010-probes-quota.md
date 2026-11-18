---
id: T-010
title: "Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4)"
status: todo
phase: P1
adr: [0005]
depends_on: [T-001, T-002, T-061, T-061b]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-010 — Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4)

## Intention
Ready signifie « app saine » ; le quota suit `size × replicas` et le stockage.

## Périmètre de fichiers
tools/appgen/, platform/component-types/, platform/project-types/, tests/

## Critères de fin
- [x] readiness/liveness rendues (STATIC : trait health-probes dans Component, release figée et binding ; CEL non évaluée)
- [x] quota calculé (déjà en place : size × replicas + surge ; tests medium×3 et archétype C ajoutés)
- [ ] CI k3d verte
