---
id: T-007
title: "Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002"
status: todo
phase: P4
adr: [0002]
depends_on: [T-215]
class: REVUE
velocity: true
lane: ci
stage: FINAL
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-007 — Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002

## Intention
Empêcher une dérive silencieuse de la frontière agents/humain.

## Périmètre de fichiers
tests/, .github/workflows/ci.yaml

## Critères de fin
- [ ] le test échoue si un chemin du noyau ADR-0002 manque dans CODEOWNERS
- [ ] job requis par `ci-ok`
- [ ] couvre aussi tools/k3d, tests/k3d, tests/gitops-k3d, tests/argo-escalation, platform-guardrails, platform/identity
- [ ] compare CODEOWNERS aux scripts appelés par ci.yaml et aux ADR 0002/0014/0016/0017/0019
- [ ] essai réel avec l'identité agent (T-215)
- [ ] couvre aussi .claude/, factory/, missions/mandates/, backlog/routing.yaml (ADR-0021/0022/0023/0022/0023)
- [ ] aucun commit d'usine sous l'identité de Paul sur les 7 derniers jours (lecture des auteurs et des trailers)

## Notes
Étape FINAL (consensus n°2 et arbitrages de Paul, 2026-11-18) : le noyau CODEOWNERS testé et l'essai réel avec l'identité agent font partie du durcissement final.
