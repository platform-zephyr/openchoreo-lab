---
id: T-027
title: "Drill de restauration automatique et `restore-evidence`"
status: todo
phase: P2
adr: [0008, 0011]
depends_on: [T-026, T-005, T-012, T-075]
class: AUTONOME
github_issue: null
---
# T-027 — Drill de restauration automatique et `restore-evidence`

## Intention
Pour `useful`/`irreplaceable` : restauration planifiée dans un namespace jetable, `verify`, preuve datée avec péremption.

## Périmètre de fichiers
platform/, golden-paths/_checks/, tests/

## Critères de fin
- [ ] drill PASS daté sur une app B
- [ ] app non conforme signalée si preuve périmée
- [ ] `irreplaceable` autorisé par la CI après preuve
