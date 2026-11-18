---
id: T-302
title: "Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets"
status: todo
phase: P0
adr: [0002]
depends_on: [T-303]
class: REVUE
velocity: false
lane: gouvernance
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-302 — Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets

## Intention
Retirer de l'arbre le scénario d'exploitation résiduel (Paul juge s'il relève du signalement privé), les chemins `/Users/<prénom>`, et la structure révélatrice des clés Doppler.

## Périmètre de fichiers
docs/REVIEW-PHASE-B.md, docs/REVIEW-PR8.md, platform/cluster-agent/, platform/policies/, fichiers contenant des chemins locaux

## Critères de fin
- [ ] 0 constat CRITIQUE/ÉLEVÉ dans l'arbre selon la garde T-303
- [ ] commentaires des manifestes réécrits en durcissement générique

## Notes
Proposé par la recherche `sensitive` (clé SEC-3) ; intégration 2 du 2026-11-18.

En S0 (consensus n°2 et arbitrages de Paul, 2026-11-18).
