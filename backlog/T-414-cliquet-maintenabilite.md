---
id: T-414
title: "Cliquet de maintenabilité `tools/quality/check.py` + `baseline.json` (seuils durs sur le code neuf)"
status: done
phase: P0
adr: [0024]
depends_on: [T-413]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-414 — Cliquet de maintenabilité `tools/quality/check.py` + `baseline.json` (seuils durs sur le code neuf)

## Intention
Interdire toute dégradation : par fichier et par fonction, complexité, longueur, erreurs ruff et mypy ne montent pas ; code neuf : complexité > 15, fonction > 80 lignes, fichier > 600 échouent ; plancher de couverture 85 % sur appgen.py et diff-cover 80 % ; publier `quality.v1.json` en artefact. Les 9 fonctions de complexité > 20 sont gelées à leur niveau.

## Périmètre de fichiers
tools/quality/, tests/quality/, .github/workflows/ci.yaml, .github/CODEOWNERS

## Critères de fin
- [x] test de dégradation : rendre une fonction plus complexe fait échouer le job (preuve datée) — 2026-11-18, local : `render_component` +1 branche donne `FAIL … complexité 47 > 46 (fonction gelée)` ; `tests/quality` (EndToEnd)
- [x] test de non-régression : un refactor qui baisse une valeur passe sans toucher la ligne de base — `tests/quality` `test_refactor_passes_without_touching_baseline`, 2026-11-18 (11 tests OK)
- [x] `baseline.json` et `tools/quality/` ajoutés à CODEOWNERS (un agent ne relâche pas un seuil seul) — `/tools/quality/` et `/tests/quality/`
- [x] temps du job < 3 min ; sortie `quality.v1.json` datée (cc_max, cc_p95, fichiers > 400 l, erreurs ruff et mypy, couverture) — RUNTIME 2026-11-18 : run `ci` 44291535887 (PR #58), `quality` 16 s, `quality-coverage` 1 min 20 s, artefact `quality-v1` publié (cc_max 65, cc_p95 12, ruff 225, mypy 12, couverture appgen 88,3 %)

## Notes
Proposition QA-4 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Dépendances : ruff, radon, coverage épinglés. Pas de seuil absolu immédiat : 9 fonctions et 3 fichiers le violeraient (rapport §B3).

Le cliquet gèle les 9 fonctions de complexité > 20 ; T-214 les abaisse puis abaisse la ligne de base dans sa PR. Mode dev (arbitrage 7) : la revue des code owners est suspendue jusqu'à FINAL0 ; la protection de CODEOWNERS ne joue qu'à partir de là, la CI (`ci-ok`) reste la seule garde d'ici là.

Livré (2026-11-18, local, STATIC) : `tools/quality/check.py`, `baseline.json` (23 fonctions gelées, ruff/mypy par fichier), `tests/quality/`, jobs `quality` et `quality-coverage` dans `ci-ok`. Choix : la ligne de base ne gèle que ce qui dépasse déjà un seuil ; les autres fonctions sont bornées par les seuils durs (15 / 80 / 600), pas par leur valeur actuelle. Reste : temps du job < 3 min mesuré en CI (local : cliquet < 1 s, tests sous couverture ≈ 40 s) et artefact `quality.v1.json` publié par la CI : NOT_TESTED.
