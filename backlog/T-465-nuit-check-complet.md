---
id: T-465
title: "Contrôle nocturne : check --full --k3d, dérive amont, évasions, alerte (SL-11)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-461, T-451, T-452]
class: REVUE
velocity: false
lane: ci
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-465 — Contrôle nocturne : check --full --k3d, dérive amont, évasions, alerte (SL-11)

## Intention
Workflow cron nocturne qui lance `check --full --k3d`, relève la dérive amont et les évasions, et alerte selon la décision D-4 (lecture par le dispatcher, ticket de backlog, pas d'issue GitHub automatique).

## Périmètre de fichiers
.github/workflows/

## Critères de fin
- [ ] workflow nocturne non bloquant, `ci-ok` inchangé
- [ ] alerte conforme à D-4 (ticket `fix-k3d-<suite>`)
- [ ] premier run nocturne daté

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
