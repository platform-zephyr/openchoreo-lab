---
id: T-074
title: "Retirer ThunderID du contrat et des capacités ; Authentik seul"
status: todo
phase: P2
adr: [0007]
depends_on: [T-001, T-061]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I2
github_issue: null
---
# T-074 — Retirer ThunderID du contrat et des capacités ; Authentik seul

## Intention
Une seule vérité sur l'IdP ; un refus CI empêche le retour de `thunderid`.

## Périmètre de fichiers
docs/schema/, docs/APP-CONTRACT.md, docs/BASE-CHOICE.md, docs/AGENT-ACCESS.md, clusters/*/capabilities.yaml

## Critères de fin
- [ ] schéma : `authentik` seul
- [ ] docs corrigées
- [ ] test CI de refus
