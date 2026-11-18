---
id: T-463
title: "Spike : tests de politiques Kyverno et VAP sans cluster (SL-9)"
status: todo
phase: P0
adr: [0022]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-463 — Spike : tests de politiques Kyverno et VAP sans cluster (SL-9)

## Intention
Spike d'un jour : `kyverno test` ou `conftest` pour exécuter les tests de politiques au niveau local/CI rapide, aujourd'hui seulement via k3d. Verdict PASS / FAIL / BLOCKED et durée.

## Périmètre de fichiers
docs/research/, tests/kyverno/ (lecture)

## Critères de fin
- [ ] rapport `docs/research/POLICY-TESTS-NO-CLUSTER.md` avec verdict et durée mesurée
- [ ] liste des cas de `tests/kyverno` exécutables sans cluster

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
