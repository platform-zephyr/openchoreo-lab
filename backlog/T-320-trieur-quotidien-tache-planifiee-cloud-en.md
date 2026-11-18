---
id: T-320
title: "Trieur quotidien : tâche planifiée cloud en lecture seule + issue de résumé"
status: todo
phase: P1
adr: [0012, 0021]
depends_on: [T-061, T-316]
class: AUTONOME + MANDAT
velocity: false
lane: agents
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-320 — Trieur quotidien : tâche planifiée cloud en lecture seule + issue de résumé

## Intention
Une routine cloud par jour : relire backlog, PR, runs ; régénérer ROADMAP ; signaler tickets bloqués, dépendances rompues, étapes prêtes à ouvrir ; poster le résumé. Ne lance aucun agent.

## Périmètre de fichiers
docs/FACTORY-RUNBOOK.md, tools/backlog/roadmap.py (appel)

## Critères de fin
- [ ] routine documentée (prompt, dépôt, environnement, connecteurs retirés) et exécutée 3 jours de suite
- [ ] aucune écriture hors commentaire du résumé (journal de la routine)

## Notes
MANDAT : création de la routine sur le web (la tâche s'exécute sous l'identité de Paul : lecture et commentaire seulement). Aperçu de recherche : plafonds susceptibles de changer.

Proposé par la recherche `factory` (clé FAC-11) ; intégration 2 du 2026-11-18.
