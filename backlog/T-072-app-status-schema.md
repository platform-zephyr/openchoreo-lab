---
id: T-072
title: "Schéma `app-status.v1` et `_checks` en sortie JSON stable"
status: todo
phase: P0
adr: [0011]
depends_on: [T-001, T-061, T-061b]
class: AUTONOME
velocity: true
lane: preuve
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-072 — Schéma `app-status.v1` et `_checks` en sortie JSON stable

## Intention
Préparer la preuve automatique : format de statut versionné (repris de kube-ops) et checks qui l'émettent.

## Périmètre de fichiers
docs/schema/, golden-paths/_checks/, tests/

## Critères de fin
- [ ] schéma JSON versionné + exemples
- [ ] `_checks` émet ce format, tests
