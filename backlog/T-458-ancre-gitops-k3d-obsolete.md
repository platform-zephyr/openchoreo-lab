---
id: T-458
title: "Réparer l'ancre obsolète de gitops-k3d (correction G1 déjà dans main)"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: false
lane: agents
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-458 — Réparer l'ancre obsolète de gitops-k3d (correction G1 déjà dans main)

## Intention
La suite gitops-k3d s'arrête après 77 s sur une ancre périmée alors que la correction G1 est dans main. Réparer l'ancre ; les FAIL déjà connus qui réapparaissent sont classés un par un (état réel NOT_TESTED aujourd'hui).

## Périmètre de fichiers
tests/gitops-k3d/, tools/k3d/

## Critères de fin
- [ ] ancre réparée, la suite va au-delà de T-DEPLOY
- [ ] chaque FAIL réapparu est classé (corrigé ou KNOWN_FAIL motivé)
- [ ] dispatch manuel de gitops-k3d : résultat daté

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.
