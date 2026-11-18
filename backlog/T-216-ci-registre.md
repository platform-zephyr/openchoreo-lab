---
id: T-216
title: "CI extensible par registre de suites"
status: todo
phase: P0
adr: [0002]
depends_on: [T-002, T-061]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-216 — CI extensible par registre de suites

## Intention
Ajouter une suite de tests sans toucher `.github/` : un registre (noyau pour les suites de garde, libre pour les autres) lu par un job générique.

## Périmètre de fichiers
.github/workflows/, tests/registry.yaml

## Critères de fin
- [ ] registre + job générique
- [ ] ajout d'une suite non-garde sans revue prouvé

## Notes
Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-007 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.
