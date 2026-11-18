---
id: T-453
title: "Combler l'écart check --static ↔ CI (SL-1)"
status: done
phase: P0
adr: [0022]
depends_on: [T-332, T-413, T-414]
class: AUTONOME
velocity: true
lane: dev-factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-453 — Combler l'écart `check --static` ↔ CI (SL-1)

## Intention
Une PR ne doit plus échouer en CI sur un contrôle que `tools/dev/check --static` ne lance pas (décalage mesuré sur la PR #58, `docs/research/SHIFT-LEFT-DEV-ENV.md` §2-§5, ligne SL-1). Ajouter à `check --static` les étapes miroirs des jobs CI `quality`, `quality-coverage`, `lint-code`, `backlog`, `appgen` (registre des identités) et `platform` (yamllint) : `quality`, `ruff-bugs`, `shellcheck-all`, `backlog-unittest`, `identities-lint`, `yamllint-platform`, `coverage`. Un outil absent donne NOT_TESTED, jamais PASS. `leak-guard` sort NOT_TESTED, et non FAIL, quand gitleaks est absent.

## Périmètre de fichiers
tools/dev/check, tests/dev-factory/

## Critères de fin
- [x] les 7 étapes existent dans `tools/dev/check` et rendent PASS sur main avec les outils présents (VM cloud x86_64, ruff 0.16.9 = version épinglée de `ci.yaml`) — `check --static` du 2026-11-18 : quality, ruff-bugs, shellcheck-all, backlog-unittest, identities-lint, yamllint-platform, coverage = PASS
- [x] un outil absent ou un ruff d'une autre version que celui de `ci.yaml` donne NOT_TESTED (jamais PASS, rc 3 avec `--strict`) — `tests/dev-factory/check-test.sh` : PATH restreint et ruff factice 0.0.1
- [x] `leak-guard` sans gitleaks : NOT_TESTED (rc 0, rc 3 avec `--strict`), plus FAIL (rc 1 avant) — cas du test, vérifié par mutation (retour à l'ancien comportement : 5 assertions FAIL)
- [x] cas négatifs dans `tests/dev-factory/check-test.sh` : ruff, shellcheck et yamllint factices qui échouent donnent FAIL (rc 1) ; chaque étape est présente (une étape oubliée ne produit plus de résultat silencieux)
- [x] durée de `check --static` mesurée et datée — voir Notes
- [x] `python3 tools/backlog/check.py` : 0 erreur (132 actifs, 0 erreur, 2026-11-18)

## Notes
Mesure du 2026-11-18 (VM cloud x86_64, sans Docker ; helm, kubeconform, actionlint et gitleaks présents à la dernière mesure) : `check --static` = 153 s, PASS=28 FAIL=1 NOT_TESTED=3 (58 s avant SL-1 avec 4 outils absents). Les 7 étapes ajoutent environ 55 s, dont `coverage` 42 s (rejoue les tests appgen déjà lancés par `appgen-unittest` : à fusionner par SL-3 `--fast`). Le FAIL est `gitleaks` sur l'historique git (208 trouvailles, dette de T-450), antérieur à ce ticket.

`check` exporte `PYTHONDONTWRITEBYTECODE=1` : les `.pyc` produits par les nouvelles étapes Python contenaient les valeurs fictives des tests et faisaient échouer `leak-guard` (gitleaks scanne l'arbre de travail).

Ne touche pas `ci.yaml` : le critère 3 de T-332 (la CI appelle `check`) reste porté par SL-6. La version de ruff est lue dans `ci.yaml` (job `lint-code`), faute d'entrée `RUFF_VERSION` dans `toolchain.lock` (à ajouter avec la concordance Dockerfile/ci.yaml, SL-6).
