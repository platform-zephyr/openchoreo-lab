---
id: T-404
title: "Jalon FINAL0 : identité d'usine, contournement retiré, secrets de dev tournés, revue des code owners réactivée"
status: todo
phase: P4
adr: [0002]
depends_on: [T-007, T-215, T-400, T-403]
class: MANDAT
velocity: false
lane: gouvernance
stage: FINAL0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-404 — Jalon FINAL0 : identité d'usine, contournement retiré, secrets de dev tournés, revue des code owners réactivée

## Intention
Barrière avant la première donnée réelle, identité réelle ou exposition publique : tout ticket qui en crée dépend de ce jalon.

## Périmètre de fichiers
STATE.md (coordinateur), docs/review/

## Critères de fin
- [ ] T-215, T-400, T-403 et T-007 `done` avec preuves datées
- [ ] revue des code owners active sur `platform/authz/`, `platform/policies/`, `security/` ; `bypass_actors` vide
- [ ] Paul consigne FINAL0 atteint (date) dans STATE.md

## Notes
Étape FINAL-0 du constat F1, acceptée (arbitrage Fable, 2026-11-18).
