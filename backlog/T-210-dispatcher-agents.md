---
id: T-210
title: "Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir"
status: todo
phase: P0
adr: [0002, 0012, 0013]
depends_on: [T-007, T-008, T-061, T-215]
class: REVUE
velocity: true
lane: ci
stage: S0
github_issue: null
---
# T-210 — Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir

## Intention
Calculer les tickets prêts (dépendances `done`, classe sans geste humain en attente), ouvrir l'issue `agent:dev` correspondante et lancer un agent par ticket, au plus N par couloir pour éviter les conflits de fichiers ; marquer `in-progress` dans la PR de l'agent.

## Périmètre de fichiers
tools/backlog/, .github/workflows/claude-agent.yml, backlog/README.md

## Critères de fin
- [ ] `tools/backlog/next.py` liste les tickets prêts (vélocité, débloqués)
- [ ] workflow_dispatch déclenché par Paul avec une liste d'ID ; pas de planification en S0
- [ ] classe recalculée depuis les chemins touchés, pas lue dans l'en-tête
- [ ] plafond 4, contrat de mission d'Atlas (max_attempts 2, ressources exclusives)
- [ ] preuve : 3 PR parallèles sur couloirs distincts (hors contrat-appgen avant T-214) ; une PR du noyau lancée par le dispatcher reste non fusionnable

## Notes
Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.
