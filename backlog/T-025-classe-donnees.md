---
id: T-025
title: "Classe de donnée dans le contrat et labels `data-class` (G8)"
status: todo
phase: P2
adr: [0008]
depends_on: [T-002, T-061]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I1
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-025 — Classe de donnée dans le contrat et labels `data-class` (G8)

## Intention
`data.class: ephemeral | rebuildable | useful | irreplaceable`, propagée en label ; `Retain` et pas de prune sur les données.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/

## Critères de fin
- [ ] schéma + migration des apps existantes
- [ ] CI : base/volume sans classe → refus
- [ ] labels présents sur namespace, PVC, base
