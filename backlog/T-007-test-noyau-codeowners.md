---
id: T-007
title: "Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: REVUE
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
