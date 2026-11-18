---
id: T-305
title: "Tag `core-baseline` du noyau avant le pilote"
status: todo
phase: P0
adr: [0002]
depends_on: [T-302, T-303, T-304, T-326, T-330]
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-305 — Tag `core-baseline` du noyau avant le pilote

## Intention
Fixer une référence de confiance du noyau (chemins CODEOWNERS) avant que les agents fusionnent eux-mêmes leurs PR du noyau ; le diff depuis ce tag est relu à FINAL (T-401).

## Périmètre de fichiers
tag git `core-baseline`, docs/state/core-baseline.md

## Critères de fin
- [ ] tag annoté (signé si possible) `core-baseline` posé par Paul sur `main` après le S0, avant l'heure 0 du pilote
- [ ] `docs/state/core-baseline.md` : SHA du tag, date, liste des chemins du noyau couverts
- [ ] règle écrite : pendant le dev, les PR du noyau sont ouvertes par l'exécutant (auteur bot), jamais sous l'identité de Paul ; liste des merges par contournement tenue pour T-401

## Notes
Constat F5 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).
