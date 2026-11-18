---
id: T-392
title: "Revue trimestrielle du routage : retraits de modèles, nouveaux modèles, dérive des tarifs"
status: deferred
phase: P5
adr: [0016, 0023]
depends_on: [T-061, T-323, T-388]
class: AUTONOME
velocity: false
lane: veille
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-392 — Revue trimestrielle du routage : retraits de modèles, nouveaux modèles, dérive des tarifs

## Intention
Chaque trimestre : relire les pages modèles et tarifs, proposer par PR les changements de règles (modèle retiré, nouveau palier moins cher), joindre le rapport T-323.

## Périmètre de fichiers
docs/state/model-prices.yaml, backlog/routing.yaml

## Critères de fin
- [ ] PR trimestrielle ouverte avec diff des tarifs et des règles, preuve datée
- [ ] un modèle dont la retraite approche (≥ 2027-09) a une règle de remplacement

## Notes
Retraits annoncés : Opus 5.5 ≥ 2027-09-22, Sonnet 5.5 ≥ 2027-09-28, Haiku 5.5 ≥ 2027-10-07, Fable 5.2 ≥ 2027-11-09 (lus le 2026-11-18).

Proposé par la recherche `model-routing` (clé MOD-13) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : routage à 3 règles jusqu'aux données du pilote (décision 8).
