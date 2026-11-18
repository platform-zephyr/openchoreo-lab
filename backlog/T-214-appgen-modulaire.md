---
id: T-214
title: "Découper appgen en paquet de modules à comportement constant (avant le couloir contrat)"
status: todo
phase: P0
adr: [0001, 0005]
depends_on: [T-413, T-414]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-214 — Découper appgen en paquet de modules à comportement constant (avant le couloir contrat)

## Intention
Avant que les agents n'y ajoutent des branches : paquet `schema`, `semantic`, `egress`, `gateway`, `render_component`, `render_helm`, `cli`, modules ≤ 400 lignes ; casser `render_component` (137 l, CC 46), `semantic_check` (102 l, CC 45), `_native_errors` (CC 41), `render_native` (106 l). Commande `python3 tools/appgen/appgen.py` conservée.

## Périmètre de fichiers
tools/appgen/, tests/appgen/, .github/workflows/ci.yaml (chemin du script seulement)

## Critères de fin
- [ ] `appgen render` ne change aucun octet de `generated/` (CI `appgen`) ; 131 tests passés ; couverture ≥ 88 %
- [ ] plus aucune fonction > 80 lignes ni complexité > 20 dans `tools/appgen/` ; la ligne de base de QA-4 est abaissée dans la même PR
- [ ] chaque module a une docstring (rôle, entrées, sorties)
- [ ] avant le refactor : un test de caractérisation par fonction gelée si l'oracle `generated/` ne la couvre pas (liste dans la PR)

## Notes
QA-6 fusionné (intégration 5, 2026-11-18) : mêmes objectifs (couloir contrat parallélisable) et critères mesurables ; pas de ticket T-416. Après T-413 (ruff) pour ne pas se marcher dessus, et T-414 pour abaisser la ligne de base dans la même PR. Un seul agent sur ce couloir (ROADMAP règle 3) ; aucune fonctionnalité dans la même PR. Doit passer avant T-214 ou en coordination avec lui.
