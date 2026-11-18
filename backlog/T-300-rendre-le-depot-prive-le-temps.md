---
id: T-300
title: "Rendre le dépôt privé le temps de la purge (geste de Paul, réversible)"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: human
effort: none
routing: R01-noyau-securite
github_issue: null
---
# T-300 — Rendre le dépôt privé le temps de la purge (geste de Paul, réversible)

## Intention
Arrêter l'exposition d'un détail de faille en coordination privée présent dans l'historique, le temps de la réécriture et de la purge par GitHub ; le dépôt redevient public ensuite.

## Périmètre de fichiers
paramètres du dépôt GitHub

## Critères de fin
- [ ] dépôt privé
- [ ] date de retour en public consignée dans STATE.md

## Notes
Proposé par la recherche `sensitive` (clé SEC-1) ; intégration 2 du 2026-11-18.

Le retour en public rétablit la règle « aucun runner auto-hébergé » (T-343).
