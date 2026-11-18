---
id: T-326
title: "Ledger de quota 5 h et hebdomadaire, seuils 70/85/100 % et disjoncteur (construit pendant le pilote)"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-311, T-313]
class: REVUE
velocity: false
lane: agents
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-326 — Ledger de quota 5 h et hebdomadaire, seuils 70/85/100 % et disjoncteur (construit pendant le pilote)

## Intention
Compléter le gouverneur minimal avec les mesures du pilote : sommes par fenêtre de 5 h et par semaine, seuils, disjoncteur et reprise au reset.

## Périmètre de fichiers
factory/config.yaml, tools/factory/ledger.py, tools/cost/agent_usage.py, tests/factory/

## Critères de fin
- [ ] test hors ligne : un ledger simulé à 70/85/100 % change l'admission comme prévu
- [ ] disjoncteur : une réponse « session limit » simulée stoppe les lancements et programme la reprise au reset annoncé
- [ ] (repris de T-145) concurrence maximale documentée et testée (workflow lint)
- [ ] (repris de T-145) agrégat hebdomadaire par identité d'agent

## Notes
Partie « ledger » de l'ancien T-311 (consensus n°2 et arbitrages de Paul, 2026-11-18). Règle d'usine (ADR-0021) : admis s'il supprime la surveillance manuelle du quota par Paul mesurée au pilote.
