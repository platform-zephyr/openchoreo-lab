---
id: T-326
title: "Ledger minimal de quota et disjoncteur « limit » (prérequis du pilote)"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-311, T-313]
class: REVUE
velocity: false
lane: agents
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-326 — Ledger minimal de quota et disjoncteur « limit » (prérequis du pilote)

## Intention
Le minimum qui rend la mesure du pilote exploitable : sommes par fenêtre de 5 h et par semaine à partir des `mission-result.v1`, et un disjoncteur qui arrête le lot sur un résultat « limit ».

## Périmètre de fichiers
tools/factory/ledger.py, tools/cost/agent_usage.py, tests/factory/, factory/config.yaml

## Critères de fin
- [ ] ledger.py additionne tokens, tours, durée et coût estimé par fenêtre de 5 h et par semaine, à partir des `mission-result.v1` (test hors ligne)
- [ ] disjoncteur : une réponse « session limit » simulée stoppe les lancements et programme la reprise au reset annoncé
- [ ] (repris de T-145) agrégat hebdomadaire par identité d'agent
- [ ] un résultat « limit » arrête le lot sans relance ; reprise manuelle par Paul au reset (test)

## Notes
Partie « ledger » de l'ancien T-311 (consensus n°2 et arbitrages de Paul, 2026-11-18). Règle d'usine (ADR-0021) : admis s'il supprime la surveillance manuelle du quota par Paul mesurée au pilote.

Prérequis du pilote (arbitrage Fable, 2026-11-18) (constat P6) ; seuils 70/85/100 % et admission par quota passés à T-314.
