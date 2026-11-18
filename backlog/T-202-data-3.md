---
id: T-202
title: "Métriques DORA par agent et par classe (D1-D8) avec tests de formules"
status: dropped
phase: P1
adr: [0002, 0011, 0019]
depends_on: [T-072, T-201]
class: REVUE
velocity: false
lane: données
stage: —
github_issue: null
---
# T-202 — Métriques DORA par agent et par classe (D1-D8) avec tests de formules

## Intention
Calculer fréquence, lead time, taux d'échec, MTTR, rework, intention→PASS, autonomie, boucle CI en DuckDB.

## Périmètre de fichiers
tools/metrics/gold/, tests/metrics/

## Critères de fin
- [ ] chaque formule testée sur valeurs attendues
- [ ] effectif n publié, 'insuffisant' sous n<5
- [ ] dimension agent, classe, app, cluster

## Notes
Attribution d'agent dépend de T-068. Merge sans preuve runtime non compté comme réussi.

Proposé par la recherche `data-platform` (clé T-202).

Ingestion et DORA ensemble (consensus du 2026-11-18). Fusionné dans T-201.
