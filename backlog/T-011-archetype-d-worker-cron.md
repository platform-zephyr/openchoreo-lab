---
id: T-011
title: "Archétype D : `spec.kind: worker | cronjob` (G1)"
status: todo
phase: P2
adr: [0005]
depends_on: [T-010, T-061]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I1bis
github_issue: null
---
# T-011 — Archétype D : `spec.kind: worker | cronjob` (G1)

## Intention
Déclarer un worker ou une tâche planifiée sans endpoint HTTP.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/component-types/, golden-paths/D-*/

## Critères de fin
- [ ] CCT `worker-restricted` et `cronjob-restricted` durcies
- [ ] template + checklist + suite k3d
- [ ] preuve OKE ou homelab datée
