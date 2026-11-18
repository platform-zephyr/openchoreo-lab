---
id: T-347
title: "Skills du harness : `fix-ci`, `new-fixture`, `run-bench`"
status: todo
phase: P1
adr: [0022]
depends_on: [T-061, T-338, T-341, T-346]
class: AUTONOME
velocity: true
lane: agents-harness
stage: S3
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-347 — Skills du harness : `fix-ci`, `new-fixture`, `run-bench`

## Intention
`fix-ci` : lire le journal par morceaux via ci-triager, corriger sur la même branche, jamais de contournement de garde ; `new-fixture` : gabarit up/health/README ; `run-bench` : lancer un sous-ensemble et lire le rapport. Descriptions courtes (budget de contexte T-041).

## Périmètre de fichiers
.agents/skills/fix-ci/, .agents/skills/new-fixture/, .agents/skills/run-bench/

## Critères de fin
- [ ] chaque skill ≤ 80 lignes, description ≤ 300 caractères (check T-041)
- [ ] essai daté de chaque skill par un agent sans contexte préalable

## Notes
.agents/ est libre (consensus décision 1 : seul `.agents/` consignes d'identité est noyau — vérifier le classement au moment de la PR).

Proposé par la recherche `harness` (clé HAR-17) ; intégration 2 du 2026-11-18.
