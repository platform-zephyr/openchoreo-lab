---
id: T-461
title: "Indicateur d'évasions de la CI : tools/dev/ci-escapes.py et ligne « Preuve locale » (SL-7)"
status: in-progress
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
- [x] `ci-escapes.py` compte les évasions par PR (lecture seule), testé (`tests/dev-factory/ci-escapes-test.sh` PASS, hors ligne, 2026-11-18 ; `analyse` découpée, complexité <= 15)
- [ ] rapport hebdomadaire daté
- [x] ligne « Preuve locale » dans le gabarit de PR (`.github/pull_request_template.md`, section « Preuve locale »)

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.

Reste : rapport hebdomadaire daté. Le générateur (`--out`, fichiers `ci-escapes-AAAA-Www.{json,md}`) est testé sur fixture, mais aucun rapport réel n'a été produit (NOT_TESTED : lecture `gh` en ligne sur le dépôt, aucune planification hebdomadaire). Le ticket reste `in-progress`.
