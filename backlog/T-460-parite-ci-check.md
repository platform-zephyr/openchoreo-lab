---
id: T-460
title: "Parité ci.yaml ↔ tools/dev/check : ci-map.tsv et test de parité (SL-6)"
status: in-progress
phase: P0
adr: [0022]
depends_on: [T-453, T-455, T-332]
class: REVUE
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 66
---

# T-460 — Parité ci.yaml ↔ tools/dev/check : ci-map.tsv et test de parité (SL-6)

## Intention
Règle : la CI ne découvre rien qu'un contrôle local rapide aurait trouvé. Un test bloquant compare les jobs de ci.yaml aux étapes de `check` via une table `ci-map.tsv` ; les jobs CI appellent `check --only <étapes> --strict` (critère 3 de T-332).

## Périmètre de fichiers
tools/dev/ci-map.tsv, tests/dev-factory/ci-parity.sh, .github/workflows/ci.yaml, .github/CODEOWNERS

## Critères de fin
- [x] `tools/dev/ci-map.tsv` et `tests/dev-factory/ci-parity.sh` avec cas négatifs (job sans étape locale, étape orpheline)
- [ ] jobs de `ci.yaml` appelant `check --only <étapes> --strict`, `ci-ok` inchangé
- [x] le critère 3 de T-332 est prouvé (même commande en CI et en local) : 12 jobs convertis, PR #70 (agent T-460, issue 66), run CI 44315526142, 18 checks verts dont `ci-ok`, 2026-11-18

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.

Reste (critère 2) : forme littérale `--only` (le workflow utilise `CHECK_ONLY=<étapes> tools/dev/check --static --strict`), jobs `hooks` et `quality-coverage` non convertis ; issue 66 à fermer après relecture.
