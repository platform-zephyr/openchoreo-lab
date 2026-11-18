---
id: T-469
title: "Triage des cas FAIL préexistants de la suite k3d"
status: todo
phase: P0
adr: [0002]
depends_on: [T-456]
class: REVUE
velocity: false
lane: ci
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-469 — Triage des cas FAIL préexistants de la suite k3d

## Intention
La suite `k3d` (`tests/k3d/run.sh`) a des cas FAIL préexistants : T01g, T02, T03a, T04a, T05, T06a, T06b, T06c, T06e, T03f (source : run 44313941923 ; contexte : `docs/CI-K3D.md`). Pour chaque cas : trouver la cause, puis corriger le cas ou le déclarer `KNOWN_FAIL` avec un motif écrit. Un cas ne reste jamais FAIL sans décision.

## Périmètre de fichiers
tests/k3d/run.sh, docs/CI-K3D.md, backlog/T-469-triage-echecs-suite-k3d.md

## Critères de fin
- [ ] Tableau cas par cas dans `## Notes` : cause prouvée (log du run 44313941923 ou d'un run plus récent), décision (corrigé ou KNOWN_FAIL)
- [ ] Chaque cas est corrigé ou marqué `KNOWN_FAIL` avec un motif écrit dans `tests/k3d/run.sh` et `docs/CI-K3D.md`
- [ ] Un dispatch daté de la suite `k3d` ne montre aucun FAIL non motivé (lien du run et date ; k3d ≠ OKE)
- [ ] `tools/dev/check --static --changed` : verdict reporté dans la PR

## Notes
Dépend de T-456 (correctif T12, `done`). Un correctif qui touche `platform/` sort du périmètre : ouvrir un ticket séparé. Ne pas désactiver ni contourner une politique d'admission, la PSA ou une NetworkPolicy pour faire passer un cas.
