---
id: T-413
title: "`pyproject.toml` (ruff, mypy, pytest, coverage), 13 bogues ruff à 0 et shellcheck sur les 59 scripts"
status: done
phase: P0
adr: [0024]
depends_on: [T-008]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-413 — `pyproject.toml` (ruff, mypy, pytest, coverage), 13 bogues ruff à 0 et shellcheck sur les 59 scripts

## Intention
Une seule configuration. Jeu ruff E,F,W,I,B,UP,SIM,C90,RUF (hors E501, complexité max 15) ; ruff `--select F,B,E9` à 0 erreur (13 aujourd'hui, 6 corrigibles par --fix) ; `shellcheck -S warning` sur tous les `*.sh` listés par `git ls-files` (0 trouvaille aujourd'hui, la CI n'en couvre qu'au moins 14 sur 59). Versions épinglées par `==`.

## Périmètre de fichiers
pyproject.toml, tools/, tests/, .github/workflows/ci.yaml

## Critères de fin
- [x] `ruff check --select F,B,E9 tools tests` : 0 erreur (13 -> 0, 2026-11-18) ; le reste du jeu en avertissement : 215 trouvailles (233 avant correctifs ; E701 95, E702 48, UP031 24, C901 13), ligne de base de QA-4
- [x] job CI (`lint-code` : shellcheck 0.11.0 en local, 65 scripts, 0 trouvaille ; job `lint-code` vert, étapes ruff F,B,E9 et shellcheck `-S warning` en succès, sur le run CI 44307223494 (PR #55) et sur le push `main` 44308148294, 2026-11-18 ; `ruff check --select F,B,E9 tools tests` rejoué ici à 12:55 UTC : 0 erreur) shellcheck sur tous les scripts versionnés, `-S warning` : 0
- [x] aucune modification de comportement : `appgen check` OK sans dérive (82 fichiers) et pytest vert (170 passés, 8 ignorés, 2026-11-18) ; `roadmap.py` régénère ROADMAP.md à l'identique
- [x] les corrections automatiques sont dans un commit séparé des corrections manuelles

## Notes
Proposition QA-3 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Mesures du rapport §B1. E501 ignoré : 1 332 lignes trop longues, sans valeur.

Touche `tools/` et `tests/` en large : à fusionner avant T-214 et les autres tickets de code (un seul agent, ROADMAP règle 3). T-214 en dépend.
