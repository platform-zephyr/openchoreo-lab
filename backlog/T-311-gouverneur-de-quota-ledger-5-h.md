---
id: T-311
title: "Gouverneur de quota : ledger 5 h et hebdomadaire, seuils, disjoncteur, kill-switch PAUSE"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-061, T-215]
class: REVUE + MANDAT
velocity: true
lane: agents
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-311 — Gouverneur de quota : ledger 5 h et hebdomadaire, seuils, disjoncteur, kill-switch PAUSE

## Intention
Sommer par tentative total_cost_usd, tours et durée (JSON de claude -p) par fenêtre de 5 h et par semaine ; ralentir à 70 %, arrêter l'AUTONOME à 85 %, pause à 100 %, réserve de 15 % pour Paul ; disjoncteur sur le message de limite et reprise au reset.

## Périmètre de fichiers
factory/config.yaml, factory/PAUSE, tools/factory/ledger.py, tools/cost/agent_usage.py, docs/AGENT-PR-MODEL.md

## Critères de fin
- [ ] test hors ligne : un ledger simulé à 70/85/100 % change l'admission comme prévu
- [ ] disjoncteur : une réponse « session limit » simulée stoppe les lancements et programme la reprise au reset annoncé
- [ ] factory/PAUSE présent = aucun lancement, aucun merge automatique (test)
- [ ] règle écrite : une clé API facturée au token exige un plafond mensuel Console (MANDAT) ; aucun euro par agent promis
- [ ] (repris de T-145) concurrence maximale documentée et testée (workflow lint)
- [ ] (repris de T-145) agrégat hebdomadaire par identité d'agent

## Notes
Les valeurs sont des estimations côté client (docs headless), pas la facture. Pas d'API de solde d'abonnement lue : NOT_PROVEN, ne pas gratter claude.ai. Fichiers du noyau (factory/) : REVUE.

La proposition visait : T-145 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `factory` (clé FAC-2) ; intégration 2 du 2026-11-18.
