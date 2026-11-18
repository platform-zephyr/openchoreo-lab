---
id: T-051
title: "Première app familiale complète (OIDC + base + sauvegarde) sur le homelab"
status: todo
phase: P2
adr: [0007, 0008, 0014, 0003]
depends_on: [T-020, T-021, T-027, T-031, T-040, T-043, T-061, T-061b, T-189]
class: AUTONOME
velocity: false
lane: apps
stage: I3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-051 — Première app familiale complète (OIDC + base + sauvegarde) sur le homelab

## Intention
Preuve de bout en bout sur une app réelle (ex. Vikunja ou Mealie) déclarée depuis une intention en langage naturel.

## Périmètre de fichiers
apps/<app>/

## Critères de fin
- [ ] PASS runtime daté
- [ ] drill de restauration PASS
- [ ] login famille OK, hors groupe refusé
