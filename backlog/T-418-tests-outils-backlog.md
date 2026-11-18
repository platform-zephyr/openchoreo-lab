---
id: T-418
title: "Tests des outils `tools/backlog/` (check.py, roadmap.py) et `crd2schema.py` (couverture 0 % aujourd'hui)"
status: todo
phase: P0
adr: [0024]
depends_on: [T-008, T-413]
class: AUTONOME
velocity: true
lane: backlog
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-418 — Tests des outils `tools/backlog/` (check.py, roadmap.py) et `crd2schema.py` (couverture 0 % aujourd'hui)

## Intention
Ces outils décident de l'ordre de travail des agents (graphe, étapes, modèle) et n'ont aucun test. Jeux d'entrée minimaux : cycle de dépendances, étape inconnue, modèle manquant, ticket `done` sans preuve.

## Périmètre de fichiers
tests/backlog/, tests/appgen/ (crd2schema), tools/backlog/

## Critères de fin
- [ ] couverture ≥ 80 % de `check.py` et `roadmap.py` (mesure `coverage`, datée)
- [ ] un test par règle d'erreur de `check.py`

## Notes
Proposition QA-8 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). seed.py est exclu : retiré par QA-9.

T-008 a livré 24 tests (`tests/backlog/`) : ce ticket mesure la couverture, comble les règles non couvertes et ajoute `crd2schema.py`.
