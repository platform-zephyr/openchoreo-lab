---
id: T-145
title: "Plafond LLM : concurrence des agents, tours, durée et consommation par PR"
status: dropped
phase: P1
adr: [0002, 0017]
depends_on: [T-061, T-215]
class: REVUE + MANDAT
velocity: true
lane: agents
stage: S2
github_issue: null
---
# T-145 — Plafond LLM : concurrence des agents, tours, durée et consommation par PR

## Intention
Borner les agents parallèles : concurrence par groupe, --max-turns et timeout existants, journal par PR (durée de job, tours, tokens si exposés) ; aucune clé API au token sans MANDAT et plafond de dépense fournisseur.

## Périmètre de fichiers
.github/workflows/claude-agent.yml, docs/AGENT-PR-MODEL.md, tools/cost/agent_usage.py

## Critères de fin
- [ ] concurrence maximale documentée et testée (workflow lint)
- [ ] chaque compte-rendu de PR porte durée, tours et tokens quand disponibles
- [ ] agrégat hebdomadaire par identité d'agent (T-068)
- [ ] règle écrite : une clé API facturée au token exige un plafond mensuel côté console (MANDAT)

## Notes
L'abonnement n'expose pas de facture par token : ne pas promettre d'euros par agent. Risque n°1 du domaine.

Proposé par la recherche `cost` (clé T-145).

Le gouverneur de quota (FAC-2) couvre concurrence, tours, durée et règle de clé API. Fusionné dans T-311 (intégration 2 du 2026-11-18).
