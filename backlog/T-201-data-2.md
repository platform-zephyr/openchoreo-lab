---
id: T-201
title: "Ingestion GitHub vers Parquet et métriques DORA par agent"
status: in-progress
phase: P4
adr: [0019]
depends_on: [T-061, T-061b]
class: REVUE
velocity: true
lane: données
stage: I8
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-201 — Ingestion GitHub vers Parquet et métriques DORA par agent

## Intention
Ingérer PR, merges, runs CI, reverts, reviews en Parquet partitionné par source et jour, idempotent, jeton lecture seule.

## Périmètre de fichiers
tools/metrics/ingest/, .github/workflows/metrics.yml (noyau : revue Paul)

## Critères de fin
- [x] rejeu sur 14 jours sans doublon (preuve : `tests/metrics/test_ingest.py` IdempotenceTests et ParquetTests, 2026-11-18, fichiers Parquet identiques après 3 rejeux)
- [x] aucun corps de PR ni secret dans les Parquet
- [x] test sur jeu synthétique
- [x] (repris de T-202) chaque formule testée sur valeurs attendues (`FormulaTests`)
- [x] (repris de T-202) effectif n publié, 'insuffisant' sous n<5
- [x] (repris de T-202) dimension agent, classe, app, cluster
- [x] ingestion budgétée sous 1 000 req/h (limite du jeton Actions) ou par l'App (budget 900 compté par `github_api.Client`, test `test_budget_is_counted_and_truncation_degrades`)
- [ ] `.github/workflows/metrics.yml` écrit (planifié, jeton lecture seule) ; fichier chaud `.github/` : REVUE
- [ ] `tests/metrics` branché dans la CI : `python3 -B -m unittest discover -s tests/metrics` dans `tools/dev/check`, `check-paths.tsv`, `ci-map.tsv` et `ci.yaml`, avec `pyarrow` à version épinglée (sinon les tests Parquet sont SKIP) ; fichiers chauds
- [ ] preuve runtime datée : une ingestion réelle sur l'API GitHub (budget compté sous 1 000 req/h) ; aujourd'hui NOT_TESTED

## Notes
Le workflow est sous .github/ donc REVUE. Phase 0 sans cluster.

Proposé par la recherche `data-platform` (clé T-201).

Limites de la livraison : D1 sans source Argo (`proof: github-only`) ; `cluster` = `unknown` faute de source ; lead time = création → fusion (1er commit non ingéré) ; source Argo, app-status.v1 et coûts LLM hors T-201. Preuve de la livraison : STATIC, 20 tests (19 PASS sans `pyarrow`, 20 PASS avec, 2026-11-18).
