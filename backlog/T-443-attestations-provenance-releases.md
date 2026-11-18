---
id: T-443
title: "Attestations de provenance et releases immuables (quand une image ou une archive est construite)"
status: todo
phase: P4
adr: [0016]
depends_on: [T-402, T-400]
class: REVUE
velocity: false
lane: supply-chain
stage: FINAL
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-443 — Attestations de provenance et releases immuables (quand une image ou une archive est construite)

## Intention
Conditionnel : si le dépôt publie une image ou une archive (garde multi-arch T-402, tag core-baseline), générer une attestation de provenance (gratuite en dépôt public) et activer les releases immuables. Sinon NOT_APPLICABLE : aucun artefact n'est construit aujourd'hui.

## Périmètre de fichiers
.github/workflows/, docs/SECURITY-BUNDLE.md

## Critères de fin
- [ ] attest-build-provenance sur chaque artefact publié, permissions id-token, attestations, contents limitées au job
- [ ] gh attestation verify PASS (preuve datée)
- [ ] ou NOT_APPLICABLE consigné par T-401

## Notes
Proposition GH-14 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Complète T-136 (Scorecard). Les workflows de verrouillage (actions.lock, GA le 2026-10-28) restent à évaluer avec Renovate : NOT_TESTED.

Dépend de T-400 (GH-12 y est fusionné : `main-final.json`). T-401 consigne le résultat ou NOT_APPLICABLE.
