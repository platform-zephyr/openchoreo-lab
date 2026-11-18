---
id: T-423
title: "Réduire la complexité de `tools/oke/argo_guard.py` et `psa_check.py` (frontière GitOps)"
status: todo
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
tools/oke/argo_guard.py, tools/oke/psa_check.py, tests/argo-guard/

## Critères de fin
- [ ] tous les cas négatifs de `tests/argo-guard/` et de la CI `platform` passent inchangés
- [ ] plus aucune fonction de complexité > 15 dans ces deux fichiers ; ligne de base abaissée
- [ ] un test unitaire Python par règle nommée

## Notes
Proposition QA-13 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Fichier du noyau CODEOWNERS (R1-sensible, ADR-0023 amendé) : Opus. Pas avant FINAL0 si le noyau est gelé par T-305.

Dépend de T-001 : la PR #8 touche `tools/oke/`. Mode dev (arbitrage 7) : la revue des code owners est suspendue jusqu'à FINAL0 ; la protection de CODEOWNERS ne joue qu'à partir de là, la CI (`ci-ok`) reste la seule garde d'ici là.
