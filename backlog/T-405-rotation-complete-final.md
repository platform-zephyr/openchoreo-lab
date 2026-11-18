---
id: T-405
title: "Rotation complète des secrets et identités du registre (FINAL)"
status: todo
phase: P4
adr: [0002, 0022]
depends_on: [T-306, T-404]
class: MANDAT
velocity: false
lane: gouvernance
stage: FINAL
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-405 — Rotation complète des secrets et identités du registre (FINAL)

## Intention
Avant « plateforme finie », tourner tout le registre, pas seulement les entrées de dev : jetons, clés, secrets OIDC, secrets machine et CA du lab.

## Périmètre de fichiers
docs/state/identities.yaml

## Critères de fin
- [ ] chaque entrée du registre a une date de rotation postérieure à FINAL0
- [ ] aucune entrée sans propriétaire ni date
- [ ] garde T-303 verte

## Notes
Constat F3 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).
