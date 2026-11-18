---
id: T-070
title: "Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/`"
status: todo
phase: P1
adr: [0001, 0005]
depends_on: [T-002]
class: REVUE
velocity: true
lane: ci
github_issue: null
---
# T-070 — Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/`

## Intention
Mettre en œuvre la vérification d'ADR-0001 et le versionnage d'ADR-0005 §3.

## Périmètre de fichiers
tools/, tests/, .github/workflows/

## Critères de fin
- [ ] CI : rupture de schéma sans changement de version → refus
- [ ] CI : manifeste applicatif hors apps/generated → refus
- [ ] indicateur : part des apps déclarées par app.yaml seul
