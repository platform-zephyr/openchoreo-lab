---
id: T-472
title: "Build périodique du devcontainer hors ci-ok"
status: todo
phase: P0
adr: [0022]
depends_on: [T-470]
class: REVUE
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-472 — Build périodique du devcontainer hors ci-ok

## Intention
Construire le devcontainer en amd64 et arm64 sur un calendrier (workflow `schedule` + `workflow_dispatch`), hors du chemin requis `ci-ok`. Un build rouge produit un signal visible sans bloquer les PR.

## Périmètre de fichiers
.github/workflows/devcontainer-build.yaml, tests/dev-factory/run.sh

## Critères de fin
- [x] Nouveau workflow `devcontainer-build.yaml` : `schedule` + `workflow_dispatch`, matrice amd64/arm64, actions épinglées par SHA, permissions minimales, absent de `ci-ok` (preuve statique 2026-11-18 : `tests/dev-factory/run.sh` PASS)
- [x] `actionlint` et `yamllint` : PASS (`tools/dev/check --static --changed`, 2026-11-18, actionlint 0.2s, yamllint 0.4s)
- [ ] Un dispatch daté construit les deux architectures (lien du run) ; sans dispatch : `NOT_TESTED`

## Notes
Ne pas modifier `ci.yaml` ni `.github/workflows/claude-agent.yml`. Prior-art (ADR-0024) avant d'écrire le workflow.
