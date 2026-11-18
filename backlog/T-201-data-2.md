---
id: T-201
title: "Ingestion GitHub vers Parquet (bronze/silver), exécution planifiée Actions"
status: todo
phase: P1
adr: [0019]
depends_on: [T-061]
class: REVUE
velocity: true
lane: données
github_issue: null
---
# T-201 — Ingestion GitHub vers Parquet (bronze/silver), exécution planifiée Actions

## Intention
Ingérer PR, merges, runs CI, reverts, reviews en Parquet partitionné par source et jour, idempotent, jeton lecture seule.

## Périmètre de fichiers
tools/metrics/ingest/, .github/workflows/metrics.yml (noyau : revue Paul)

## Critères de fin
- [ ] rejeu sur 14 jours sans doublon
- [ ] aucun corps de PR ni secret dans les Parquet
- [ ] test sur jeu synthétique

## Notes
Le workflow est sous .github/ donc REVUE. Phase 0 sans cluster.

Proposé par la recherche `data-platform` (clé T-201).
