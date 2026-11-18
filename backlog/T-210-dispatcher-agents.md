---
id: T-210
title: "Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir"
status: todo
phase: P0
adr: [0002, 0012, 0013]
depends_on: [T-008]
class: REVUE
velocity: true
lane: ci
github_issue: null
---
# T-210 — Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir

## Intention
Calculer les tickets prêts (dépendances `done`, classe sans geste humain en attente), ouvrir l'issue `agent:dev` correspondante et lancer un agent par ticket, au plus N par couloir pour éviter les conflits de fichiers ; marquer `in-progress` dans la PR de l'agent.

## Périmètre de fichiers
tools/backlog/, .github/workflows/claude-agent.yml, backlog/README.md

## Critères de fin
- [ ] `tools/backlog/next.py` liste les tickets prêts triés (vélocité, nombre de tickets débloqués)
- [ ] workflow : déclenchement par Paul ou planifié, plafond global et par couloir (COST-6)
- [ ] condition `SmadjaPaul` du workflow d'agent remplacée par une identité de dispatch bornée
- [ ] preuve : 3 tickets indépendants traités en parallèle, 3 PR vertes

## Notes
Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.
