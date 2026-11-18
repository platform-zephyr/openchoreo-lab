---
id: T-144
title: "Compteur de minutes CI et garde « dépôt public »"
status: todo
phase: P1
adr: [0002, 0017]
depends_on: [T-002, T-140]
class: REVUE
velocity: false
lane: ci
github_issue: null
---
# T-144 — Compteur de minutes CI et garde « dépôt public »

## Intention
Agréger durée x multiplicateur des runs par semaine via l'API Actions, vérifier visibility=public (minutes et runners arm64 gratuits) et alerter à 70 % de 2000 min si le dépôt devient privé.

## Périmètre de fichiers
.github/workflows/cost-watch.yml, tools/cost/ci_minutes.py

## Critères de fin
- [ ] rapport hebdomadaire JSON daté
- [ ] FAIL si le dépôt est privé sans décision de Paul
- [ ] mesure du coût de la CI k3d (T-002) en minutes

## Notes
.github/ est du noyau protégé (ADR-0002) : REVUE de Paul.

Proposé par la recherche `cost` (clé T-144).
