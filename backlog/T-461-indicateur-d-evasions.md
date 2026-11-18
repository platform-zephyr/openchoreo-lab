---
id: T-461
title: "Indicateur d'évasions de la CI : tools/dev/ci-escapes.py et ligne « Preuve locale » (SL-7)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-460]
class: REVUE
velocity: false
lane: ci
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 75
---

# T-461 — Indicateur d'évasions de la CI : tools/dev/ci-escapes.py et ligne « Preuve locale » (SL-7)

## Intention
Mesurer ce que la CI trouve et qu'un contrôle local aurait trouvé : script en lecture seule, rapport hebdomadaire, ligne « Preuve locale » du gabarit de PR.

## Périmètre de fichiers
tools/dev/ci-escapes.py, tests/dev-factory/, .github/pull_request_template.md

## Critères de fin
- [ ] `ci-escapes.py` compte les évasions par PR (lecture seule), testé
- [ ] rapport hebdomadaire daté
- [ ] ligne « Preuve locale » dans le gabarit de PR

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
