---
id: T-382
title: "route.py : règles backlog/routing.yaml et résolution d'un modèle par ticket"
status: deferred
phase: P5
adr: [0023]
depends_on: [T-008, T-061]
class: REVUE
velocity: true
lane: ci
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-382 — route.py : règles backlog/routing.yaml et résolution d'un modèle par ticket

## Intention
Promouvoir la liste `rules:` de cette proposition en backlog/routing.yaml et écrire route.py : (ticket, kind) → {model, effort, review, escalate} ; le plancher est recalculé depuis les chemins, le champ `model` ne fait que monter.

## Périmètre de fichiers
backlog/routing.yaml, tools/backlog/route.py, tests/backlog/

## Critères de fin
- [ ] tests : 20 tickets d'exemple (un par couloir) routés comme la grille ; R01 impose Opus même si l'en-tête dit sonnet
- [ ] `route.py --explain T-xxx` affiche la règle appliquée

## Notes
Même principe que T-210 : classe recalculée, jamais lue dans l'en-tête.

Proposé par la recherche `model-routing` (clé MOD-3) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : routage à 3 règles jusqu'aux données du pilote (décision 8).
