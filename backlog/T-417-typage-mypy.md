---
id: T-417
title: "Typage : `mypy` sans erreur sur `tools/appgen`, puis `--strict` module par module"
status: todo
phase: P1
adr: [0024]
depends_on: [T-214, T-413]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-417 — Typage : `mypy` sans erreur sur `tools/appgen`, puis `--strict` module par module

## Intention
37 erreurs mypy aujourd'hui (4 fichiers), 562 en `--strict` ; fonctions publiques annotées (26 % aujourd'hui). `mypy` en CI sur appgen, puis un module strict à la fois.

## Périmètre de fichiers
tools/appgen/, tools/backlog/, pyproject.toml

## Critères de fin
- [x] `mypy tools/appgen` : 0 erreur (cliquet `quality`, requis par `ci-ok`, sans toucher ci.yaml) ; modules déjà stricts listés dans `pyproject.toml`
- [x] 100 % des fonctions publiques de `tools/appgen` annotées

## Notes
Proposition QA-7 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Pas de `# type: ignore` sans motif ; chaque ignore compté par QA-4.
