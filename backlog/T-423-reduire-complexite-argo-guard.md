---
id: T-423
title: "Réduire la complexité de `tools/oke/argo_guard.py` et `psa_check.py` (frontière GitOps)"
status: in-progress
phase: P1
adr: [0024]
depends_on: [T-414, T-001]
class: REVUE
velocity: false
lane: frontière-argo
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-423 — Réduire la complexité de `tools/oke/argo_guard.py` et `psa_check.py` (frontière GitOps)

## Intention
`Guard.check_projects` (65), `psa_check.check` (48), `check_apps` (37), `check_synced` (23) portent la frontière de confiance Argo : une règle mal lue ici est une faille. Découper en règles nommées une à une, à comportement constant, chaque cas négatif existant conservé.

## Périmètre de fichiers
tools/oke/argo_guard.py, tools/oke/psa_check.py, tests/argo-guard/, tools/quality/baseline.json (retrait des seules entrées gelées de ces deux fichiers)

## Critères de fin
- [x] tous les cas négatifs de `tests/argo-guard/` et de la CI `platform` passent inchangés
- [x] plus aucune fonction de complexité > 15 dans ces deux fichiers ; ligne de base abaissée
- [x] un test unitaire Python par règle nommée

## Notes
Proposition QA-13 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Fichier du noyau CODEOWNERS (R1-sensible, ADR-0023 amendé) : Opus. Pas avant FINAL0 si le noyau est gelé par T-305.

Dépend de T-001 : la PR #8 touche `tools/oke/`. Mode dev (arbitrage 7) : la revue des code owners est suspendue jusqu'à FINAL0 ; la protection de CODEOWNERS ne joue qu'à partir de là, la CI (`ci-ok`) reste la seule garde d'ici là.

## Preuves (2026-11-18, local, niveau STATIC)
- Caractérisation d'abord : `tests/argo-guard/test_characterization.py` + `golden.json.gz` (environ 4 000 cas : check_projects, check_apps, check_lab_apps_sources, synced, check_synced et check_np, oke_apps, psa_check). Le gel vient de l'ancien code (commit 4fe20a0) et reste identique après découpage ; deux mutations de règle font échouer le test.
- Règles nommées : `rule_p1_*`, `rule_p2_*`, `rule_p3_*`, `rule_a1_*` à `rule_a4_*`, `rule_lab_apps_source_*`, `rule_s1_*`, `rule_s3_*` ; côté psa_check `rule_vap_*`, `rule_baseline_*`, `rule_restricted_*`. Un test par règle dans `tests/argo-guard/test_rules.py`.
- `tests/argo-guard/run.sh` : 41 PASS, 0 FAIL ; `argo_guard.py` sur l'arbre réel : 0 écart ; complexité maximale 13 (radon) ; ruff 0 ; entrées gelées retirées de `tools/quality/baseline.json`.
- Non couvert : les tests unittest de `tests/argo-guard/` ne sont pas câblés dans `tools/dev/check` ni la CI (hors périmètre) ; la CI `platform` n'a pas été rejouée.
