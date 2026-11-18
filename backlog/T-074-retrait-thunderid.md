---
id: T-074
title: "Retirer ThunderID du contrat et des capacités ; Authentik seul"
status: todo
phase: P2
adr: [0007]
depends_on: [T-025, T-072, T-365]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
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

## Notes
Dépendance T-001 retirée (arbitrage Fable, 2026-11-18) : aucun fichier commun avec la PR #8 (tools/oke/, security/), aucun cluster ; entre dans la liste figée du pilote.

Dans la liste figée du pilote (arbitrage Fable, 2026-11-18) : sérialisé après T-072 et T-025 (docs/schema/) et T-365 (capabilities.yaml).
