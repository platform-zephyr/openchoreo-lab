---
id: T-014
title: "Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7)"
status: deferred
phase: P2
adr: [0005, 0006]
depends_on: [T-010]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I1bis
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-014 — Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7)

## Intention
Un logiciel livré seulement en chart passe par le même contrat : namespace PSA, default-deny, quota, LB=0, validation du rendu.

## Périmètre de fichiers
tools/appgen/, golden-paths/E-*/, tests/

## Critères de fin
- [ ] rendu refusé si objet cluster-scoped, RBAC, LB, privileged
- [ ] template + checklist + suite k3d
- [ ] une app réelle du catalogue kube-ops en preuve

## Notes
Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
