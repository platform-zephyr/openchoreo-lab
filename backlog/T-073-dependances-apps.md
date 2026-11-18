---
id: T-073
title: "Dépendances entre apps `dependsOn` (G11)"
status: todo
phase: P2
adr: [0005]
depends_on: [T-021]
class: AUTONOME
velocity: false
lane: contrat-appgen
github_issue: null
---
# T-073 — Dépendances entre apps `dependsOn` (G11)

## Intention
Egress ciblé + variable d'URL vers une autre app.

## Périmètre de fichiers
docs/schema/, tools/appgen/

## Critères de fin
- [ ] tests appgen
- [ ] NetworkPolicy d'egress ciblée rendue
- [ ] preuve k3d A → B
