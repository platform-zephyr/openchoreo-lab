---
id: T-459
title: "Pre-commit et pre-push : .pre-commit-config.yaml et tools/dev/setup (SL-4)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-455, T-454]
class: AUTONOME
velocity: false
lane: dev-factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-459 — Pre-commit et pre-push : .pre-commit-config.yaml et tools/dev/setup (SL-4)

## Intention
Donner aux agents et à Paul un point d'entrée local qui attrape les erreurs au commit et au push : hooks pre-commit (ruff, shellcheck, yamllint, gitleaks, actionlint) avec les binaires épinglés du lock, hook pre-push appelant `tools/dev/check --static --changed`.

## Périmètre de fichiers
.pre-commit-config.yaml, tools/dev/setup, tests/dev-factory/, docs/DEV-FACTORY.md

## Critères de fin
- [ ] `.pre-commit-config.yaml` et `tools/dev/setup` (installation idempotente)
- [ ] un commit fautif (ruff, yaml invalide, secret factice) est refusé en local, cas négatifs testés
- [ ] durée du pre-commit < 10 s sur un changement typique (mesure datée)

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
