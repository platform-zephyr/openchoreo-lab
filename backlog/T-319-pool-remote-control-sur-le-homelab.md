---
id: T-319
title: "Pool Remote Control sur le homelab pour les tâches à ressources locales"
status: deferred
phase: P5
adr: [0021]
depends_on: [T-061, T-318]
class: AUTONOME + MANDAT
velocity: false
lane: hybride
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-319 — Pool Remote Control sur le homelab pour les tâches à ressources locales

## Intention
claude remote-control --spawn worktree --capacity N dans la VM, supervisé ; sert aux travaux qui ont besoin du homelab et au pilotage depuis le téléphone ; renouvellement du login avant expiration.

## Périmètre de fichiers
ops/runners/remote-control.md, tools/factory/rc-pool.sh

## Critères de fin
- [ ] 3 sessions simultanées en worktrees isolés (preuve datée)
- [ ] alerte avant expiration du login ; reconnexion documentée

## Notes
MANDAT : un /login interactif de Paul. Le jeton setup-token ne peut pas ouvrir de session RC.

Proposé par la recherche `factory` (clé FAC-10) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : dépend de T-318, différé par la règle d'usine (décision 10).
