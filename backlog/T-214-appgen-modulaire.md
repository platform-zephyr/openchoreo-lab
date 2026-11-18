---
id: T-214
title: "Découper appgen en paquet de modules à comportement constant (avant le couloir contrat)"
status: in-progress
phase: P0
adr: [0001, 0005]
depends_on: [T-413, T-414]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-214 — Découper appgen en paquet de modules à comportement constant (avant le couloir contrat)

## Intention
Avant que les agents n'y ajoutent des branches : paquet `schema`, `semantic`, `egress`, `gateway`, `render_component`, `render_helm`, `cli`, modules ≤ 400 lignes ; casser `render_component` (137 l, CC 46), `semantic_check` (102 l, CC 45), `_native_errors` (CC 41), `render_native` (106 l). Commande `python3 tools/appgen/appgen.py` conservée.

## Périmètre de fichiers
tools/appgen/, tests/appgen/, .github/workflows/ci.yaml (chemin du script seulement)

## Critères de fin
- [x] `appgen render` ne change aucun octet de `generated/` (CI `appgen`) ; 131 tests passés ; couverture ≥ 88 % — STATIC 2026-11-18 16:17Z (branche `claude/t-214-appgen-modulaire`) : `appgen.py render --out <tmp>` puis `diff -r <tmp> generated` vide, `appgen.py render` en place sans diff git, `appgen check` et `check --base origin/main` OK (82 fichiers) ; `--help`, sous-commandes et erreurs de la CLI identiques à l'ancien `appgen.py` (8 invocations comparées) ; `unittest discover -s tests/appgen` : 164 tests, OK (8 sautés, kubeconform sans CRD) ; couverture du paquet `tools/appgen/appgenlib` 96,5 % (`appgen.py` 100 %). Job CI `appgen` : à confirmer à la PR (miroir local L2 `tools/dev/check` PASS)
- [x] plus aucune fonction > 80 lignes ni complexité > 20 dans `tools/appgen/` ; la ligne de base de QA-4 est abaissée dans la même PR — radon : complexité max 15, fonction la plus longue 48 lignes ; ruff 8 → 0, mypy 12 → 0 sur `tools/appgen` ; `tools/quality/baseline.json` : 7 fonctions gelées et l'entrée fichier de `appgen.py` retirées (identique à `check.py --write-baseline`) ; `python3 tools/quality/check.py` PASS
- [x] chaque module a une docstring (rôle, entrées, sorties) — 16 modules de `tools/appgen/appgenlib/` et la façade `appgen.py`
- [x] avant le refactor : un test de caractérisation par fonction gelée si l'oracle `generated/` ne la couvre pas (liste dans la PR) — commit `6d92e3f` (avant le découpage), `tests/appgen/test_characterization.py` : `semantic_check`, `_native_errors`, `egress_errors`, `gateway_errors`, `validate_all_full` (listes d'erreurs complètes, dans l'ordre) ; `render_component` et `render_native` couverts par l'oracle `generated/` ; en plus `render_helm`, `load_capabilities` et la CLI en processus

## Notes
QA-6 fusionné (intégration 5, 2026-11-18) : mêmes objectifs (couloir contrat parallélisable) et critères mesurables ; pas de ticket T-416. Après T-413 (ruff) pour ne pas se marcher dessus, et T-414 pour abaisser la ligne de base dans la même PR. Un seul agent sur ce couloir (ROADMAP règle 3) ; aucune fonctionnalité dans la même PR. Doit passer avant T-214 ou en coordination avec lui.

Livré (2026-11-18, STATIC, branche `claude/t-214-appgen-modulaire`, sans PR) : paquet `tools/appgen/appgenlib/` (config, model, schema, egress, semantic, validate, platform_index, gateway, catalog, render_component, render_native, render_helm, render, gitops, cli ; 17 à 251 lignes) ; `appgen.py` = point d'entrée et façade d'import (`import appgen` inchangé pour les tests). `test_gitops_fixes` remplace désormais `PROJECT_PINS_PATH` dans `appgenlib.config`. `.github/workflows/ci.yaml` inchangé (commande conservée). Vérifications : `tools/dev/check --static --changed` INCOMPLET (9 PASS, 0 FAIL, 2 NOT_TESTED : `guard-check` hors conteneur de dev, `identities` absent du dépôt) ; `python3 tools/quality/check.py` PASS.
Implémentations publiques consultées (prior-art, 2026-11-18, `gh api search`) : aucune adoptée ; requêtes `ComponentRelease ReleaseBinding language:python` (5 dépôts tiers, générateurs ou agents sans rapport avec un découpage d'appgen) ; `openchoreo gitops generator` (0 dépôt). Découpage par responsabilité, code existant déplacé, aucun code externe.
Reste : (1) ouvrir la PR, CI `appgen`, `quality`, `quality-coverage` vertes (NOT_TESTED en CI) ; (2) écart de garde : le plancher de couverture de `tools/quality/check.py` (`APPGEN = tools/appgen/appgen.py`, 85 %) ne mesure plus que la façade (100 %, bloc `__main__` exclu par `pragma: no cover`) ; à pointer sur `tools/appgen/appgenlib/` (ou agréger `tools/appgen/`) dans un ticket du noyau `tools/quality/` (CODEOWNERS) ; (3) `tools/README.md` décrit encore `appgen.py` comme le générateur entier (hors périmètre) ; (4) garde de fuite : un `.pyc` de `appgenlib/config.py` laissé par un `unittest` lancé sans `-B` déclenche un faux positif `lab-ipv4` (gitleaks lit le binaire) ; `tools/dev/check` exporte `PYTHONDONTWRITEBYTECODE=1` et la CI part d'un arbre propre : sans effet sur eux.
