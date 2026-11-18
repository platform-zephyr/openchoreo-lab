---
id: T-316
title: "ntfy seulement si nécessaire et résumé quotidien unique"
status: todo
phase: P0
adr: [0015, 0021]
depends_on: [T-061, T-314]
class: AUTONOME + MANDAT
velocity: false
lane: observabilité
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-316 — ntfy seulement si nécessaire et résumé quotidien unique

## Intention
Notifier par ntfy quatre cas : needs-paul, usine en pause, ticket blocked > 6 h, incident runtime. Un commentaire quotidien dans l'issue « Usine : résumé » (fusionnées, en cours, bloquées, % de quota, gestes attendus).

## Périmètre de fichiers
tools/factory/notify.py, .github/workflows/factory-digest.yml, docs/FACTORY-RUNBOOK.md

## Critères de fin
- [ ] test : 4 cas déclenchent une notification, une PR fusionnée normale n'en déclenche aucune
- [ ] dédoublonnage : au plus 1 notification par cause et par 6 h
- [ ] résumé daté publié pendant 3 jours consécutifs sans intervention

## Notes
MANDAT : sujet ntfy privé, jeton en secret du dépôt (nom seulement), abonnement du téléphone. Le contenu public d'un sujet ntfy n'est pas secret : ne jamais y mettre de détail sensible.

Proposé par la recherche `factory` (clé FAC-7) ; intégration 2 du 2026-11-18.
