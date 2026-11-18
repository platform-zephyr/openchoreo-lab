---
id: T-403
title: "Rotation des secrets et identités créés en mode dev (FINAL0)"
status: todo
phase: P4
adr: [0002, 0022]
depends_on: [T-215, T-306]
class: MANDAT
velocity: false
lane: gouvernance
stage: FINAL0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-403 — Rotation des secrets et identités créés en mode dev (FINAL0)

## Intention
Tout credential lisible par un agent aux droits étendus pendant le dev est tenu pour compromis : il est tourné ou révoqué avant la première donnée réelle.

## Périmètre de fichiers
docs/state/identities.yaml

## Critères de fin
- [ ] chaque entrée `dev: true` du registre est tournée ou révoquée ; date de rotation consignée, aucune valeur affichée
- [ ] l'identité de l'exécutant avec permission `workflows` (T-304) est remplacée par l'App de T-215
- [ ] garde T-303 verte ; aucune valeur dans la PR

## Notes
Constat F1/F3 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).
