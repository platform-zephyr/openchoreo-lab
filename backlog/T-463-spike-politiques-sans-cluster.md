---
id: T-463
title: "Spike : tests de politiques Kyverno et VAP sans cluster (SL-9)"
status: done
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
- [x] rapport `docs/research/POLICY-TESTS-NO-CLUSTER.md` avec verdict et durée mesurée (PASS ; 97 cas en 2,6-3,0 s, 19 cas VAP en 0,6 s ; 2026-11-18)
- [x] liste des cas de `tests/kyverno` exécutables sans cluster (97 sur 97, par politique : rapport §3.1)

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
Livré 2026-11-18 : rapport + prototype `docs/research/policy-tests-no-cluster/`. Suites proposées (REVUE) : corriger le SIGPIPE de `tests/kyverno/run.sh`, intégrer les tests de VAP à L2 (rapport §4).
