---
id: T-386
title: "Étalonnage : matrice Haiku / Sonnet / Opus sur le banc d'intentions et sur 30 tickets rejoués"
status: deferred
phase: P5
adr: [0013, 0023]
depends_on: [T-044, T-061, T-323, T-346]
class: AUTONOME
velocity: false
lane: intention
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-386 — Étalonnage : matrice Haiku / Sonnet / Opus sur le banc d'intentions et sur 30 tickets rejoués

## Intention
Rejouer les 5 intentions A (T-044) × 3 modèles × 5 passes et un échantillon de tickets AUTONOME par type ; trancher R09, R10, R11 et la règle de descente (10 % au cran inférieur).

## Périmètre de fichiers
tests/intents/, docs/research/model-calibration.md

## Critères de fin
- [ ] tableau (type, modèle) : PASS runtime, échecs CI, quota par ticket fusionné (Sonnet high contre Opus medium : lequel consomme le moins) ; chaque règle passe de `hypothesis` à `calibrated` ou est corrigée
- [ ] décision datée sur R09 (Haiku pour app.yaml A) : tenue ou relevée à Sonnet

## Notes
Consomme du quota Max : à exécuter hors fenêtre de pointe, 2 sessions au plus (T-311).

Proposé par la recherche `model-routing` (clé MOD-7) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : règle d'usine d'ADR-0021 (décision 10) ; avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
