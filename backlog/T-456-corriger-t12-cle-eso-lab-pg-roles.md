---
id: T-456
title: "Corriger T12 : clé ESO lab-pg-roles/<nom> refusée par le provider kubernetes"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: false
lane: agents
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---

# T-456 — Corriger T12 : clé ESO lab-pg-roles/<nom> refusée par le provider kubernetes

## Intention
Le PushSecret r-*-pg-role écrit une clé avec un « / » que lab-store (provider kubernetes d'ESO) refuse : toute app de l'archétype B échoue. Remplacer le séparateur par un caractère admis, aligner la règle R6 du VAP et les cas de test.

## Périmètre de fichiers
platform/resource-types/cnpg-lab-db.yaml, platform/policies/vap-cluster-agent-scope.yaml, tests/vap/, tests/k3d/

## Critères de fin
- [ ] séparateur remplacé dans cnpg-lab-db.yaml (clé sans « / »)
- [ ] règle R6 de vap-cluster-agent-scope.yaml et cas P01/P05 de tests/vap/ alignés
- [ ] dispatch manuel de k3d et vap sur la branche : T12 vert, preuve datée

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.
