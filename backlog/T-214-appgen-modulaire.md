---
id: T-214
title: "Découper appgen en modules (avant le couloir contrat)"
status: todo
phase: P0
adr: [0001, 0005]
depends_on: []
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-214 — Découper appgen en modules (avant le couloir contrat)

## Intention
Le fichier unique de ~1 500 lignes limite le couloir contrat à 1 agent ; des modules permettent plusieurs agents en parallèle.

## Périmètre de fichiers
tools/appgen/, tests/appgen/

## Critères de fin
- [ ] modules par domaine (schéma, rendu OpenChoreo, Argo, réseau, données…)
- [ ] 137 tests et plus toujours verts, `appgen check` sans dérive
