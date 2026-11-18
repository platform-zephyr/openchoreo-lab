---
id: T-314
title: "Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission"
status: todo
phase: P0
adr: [0021]
depends_on: [T-061, T-210, T-301, T-311, T-313]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-314 — Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission

## Intention
À chaque tick : relire backlog, PR, runs ; admettre les prêts selon T-210 et le gouverneur ; lancer T-313 ; ne jamais dupliquer un lancement (vérifier branche, PR et run avant).

## Périmètre de fichiers
.github/workflows/factory-dispatch.yml, tools/factory/dispatch.py

## Critères de fin
- [ ] idempotence : deux ticks consécutifs ne lancent pas deux fois le même ticket (test)
- [ ] preuve : 24 h de ticks, 0 doublon, 0 lancement pendant PAUSE ou disjoncteur ouvert
- [ ] étape fermée = aucun lancement ; seules une ou deux étapes ouvertes à la fois

## Notes
S0 reste manuel (CONSENSUS #11) ; le cron s'active après la preuve de T-313.

Proposé par la recherche `factory` (clé FAC-5) ; intégration 2 du 2026-11-18.
