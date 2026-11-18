---
id: T-002
title: "CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue"
status: todo
phase: P0
adr: [0002, 0004]
depends_on: []
class: REVUE
velocity: true
lane: ci
github_issue: null
---
# T-002 — CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue

## Intention
Rendre la CI k3d fiable : c'est le contrôle compensatoire de l'autonomie sur `platform/` (ADR-0002 §4).

## Périmètre de fichiers
.github/workflows/k3d-integration.yml, tools/k3d/

## Critères de fin
- [ ] gitops-k3d gardé en échec connu, pas retiré
- [ ] tests AUD : audit activé ou NOT_TESTED, jamais PASS
- [ ] limite « chart sans bundle » écrite dans la PR
- [ ] suites vap, k3d, argo-escalation vertes

## Notes
Revue de la PR #36 faite le 2026-11-18 (4 points).
