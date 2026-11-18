---
id: T-311
title: "Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-061]
class: REVUE
velocity: true
lane: agents
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-311 — Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3

## Intention
Le minimum pour lancer le pilote sans risque de dérive : un interrupteur `factory/PAUSE` qui arrête tout lancement et tout merge automatique, et une concurrence plafonnée à 3. Le ledger de quota se construit pendant le pilote (T-326).

## Périmètre de fichiers
factory/config.yaml, factory/PAUSE, .github/workflows/claude-agent.yml (groupe de concurrence), docs/AGENT-PR-MODEL.md

## Critères de fin
- [ ] factory/PAUSE présent = aucun lancement, aucun merge automatique (test)
- [ ] concurrence 3 fixée dans factory/config.yaml et appliquée par le groupe de concurrence du workflow (test)
- [ ] règle écrite : une clé API facturée au token exige un plafond mensuel Console (MANDAT) ; aucun euro par agent promis

## Notes
Les valeurs sont des estimations côté client (docs headless), pas la facture. Pas d'API de solde d'abonnement lue : NOT_PROVEN, ne pas gratter claude.ai. Fichiers du noyau (factory/) : REVUE.

La proposition visait : T-145 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `factory` (clé FAC-2) ; intégration 2 du 2026-11-18.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.
