---
id: T-349
title: "Canari du harness : banc réduit nocturne sur main et montées épinglées de Claude Code et de l'action"
status: deferred
phase: P5
adr: [0016, 0022]
depends_on: [T-061, T-120, T-343, T-346]
class: REVUE
velocity: false
lane: renovate
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-349 — Canari du harness : banc réduit nocturne sur main et montées épinglées de Claude Code et de l'action

## Intention
Banc de 8 à 10 tâches chaque nuit sur main (runner homelab ou hébergé) ; alerte si pass^3 baisse de plus de 15 points. Versions de l'action claude-code-action (SHA), de la CLI Claude Code et du harness épinglées ; Renovate ouvre la montée, la PR n'est fusionnable que si le banc réduit est vert.

## Périmètre de fichiers
.github/workflows/harness-canary.yml, .github/renovate.json, tests/bench/canary.yaml

## Critères de fin
- [ ] baisse simulée (hook cassé volontairement) déclenche l'alerte (essai daté)
- [ ] une PR de montée de l'action est bloquée tant que le banc réduit n'a pas tourné
- [ ] coût nocturne mesuré et sous le plafond fixé par T-311

## Notes
Les agents de l'abonnement partagent des quotas : planifier la nuit, hors fenêtre de travail.

Proposé par la recherche `harness` (clé HAR-19) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : dépend de T-346, différé par la règle d'usine (décision 10).
