---
id: T-413
title: "`pyproject.toml` (ruff, mypy, pytest, coverage), 13 bogues ruff à 0 et shellcheck sur les 59 scripts"
status: todo
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
- [ ] `ruff check --select F,B,E9 tools tests` : 0 erreur ; le reste du jeu en avertissement, compté dans la ligne de base de QA-4
- [ ] job CI shellcheck sur tous les scripts versionnés, `-S warning` : 0
- [ ] aucune modification de comportement : `appgen render` ne change pas `generated/` et pytest reste vert (131 passés)
- [ ] les corrections automatiques sont dans un commit séparé des corrections manuelles

## Notes
Proposition QA-3 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Mesures du rapport §B1. E501 ignoré : 1 332 lignes trop longues, sans valeur.

Touche `tools/` et `tests/` en large : à fusionner avant T-214 et les autres tickets de code (un seul agent, ROADMAP règle 3). T-214 en dépend.
