---
id: T-418
title: "Tests des outils `tools/backlog/` (check.py, roadmap.py) et `crd2schema.py` (couverture 0 % aujourd'hui)"
status: done
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
- [x] couverture ≥ 80 % de `check.py` et `roadmap.py` (mesure `coverage`, datée) : 2026-11-18, `python3 -B -m coverage run -m unittest discover -s tests/backlog` puis `coverage report` : check.py 99 % (2 lignes : `main()` sous `__main__`), roadmap.py 100 %, crd2schema.py 97 % (`tests/appgen/test_crd2schema.py`)
- [x] un test par règle d'erreur de `check.py` : les 20 codes d'erreur (EN-TÊTE, ID-DUPLIQUÉ, CHAMP-ABSENT, NOM-FICHIER, STATUT/CLASSE/PHASE/ÉTAPE-INCONNU(E), ADR-ABSENT, MODEL-ABSENT, MODEL-INCONNU, EFFORT, EFFORT-INCONNU, PÉRIMÈTRE-INEXPLOITABLE, CRITÈRES, MISSING, DEP-ON-DROPPED, ACTIF->GELÉ, ÉTAPE, CYCLE) ont un test négatif dans `tests/backlog/test_check.py`

## Notes
Proposition QA-8 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). seed.py est exclu : retiré par QA-9.

T-008 a livré 24 tests (`tests/backlog/`) : ce ticket mesure la couverture, comble les règles non couvertes et ajoute `crd2schema.py`.
