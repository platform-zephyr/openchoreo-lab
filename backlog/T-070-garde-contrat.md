---
id: T-070
title: "Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/`"
status: todo
phase: P1
adr: [0001, 0005]
depends_on: [T-002, T-061]
class: REVUE
velocity: true
lane: ci
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-070 — Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/`

## Intention
Mettre en œuvre la vérification d'ADR-0001 et le versionnage d'ADR-0005 §3.

## Périmètre de fichiers
tools/contract-guard/, docs/schema/app.schema.json, tests/contract-guard/, .github/workflows/ci.yaml (job du garde ; couplé à tools/dev/check et ci-map.tsv), tools/dev/check, tools/dev/ci-map.tsv

## Critères de fin
- [ ] CI : rupture de schéma sans changement de version → refus
- [ ] CI : manifeste applicatif hors apps/generated → refus
- [ ] indicateur : part des apps déclarées par app.yaml seul

## Notes
Sorti de la liste figée du pilote (arbitrage Fable, 2026-11-18) : périmètre trop large (chevauchement, constat P7).
