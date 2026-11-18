---
id: T-203
title: "Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets)"
status: todo
phase: P4
adr: [0006, 0019]
depends_on: [T-020, T-061, T-061b, T-201]
class: AUTONOME
velocity: false
lane: données
stage: I8
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-203 — Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets)

## Intention
Calculer S1-S9 ; couverture par primitive avec preuve fraîche < 30 j.

## Périmètre de fichiers
tools/metrics/security/

## Critères de fin
- [ ] Scorecard ingéré par check
- [ ] tableau des 8 primitives PASS/FAIL/NOT_TESTED datés
- [ ] S8 aligné sur T-007
- [ ] SLSA affiché « Build L2 » (attestations GitHub) ; L3 seulement avec un workflow réutilisable vérifié

## Notes
S3 (SLSA) exige l'activation des attestations de build : à vérifier [E].

Proposé par la recherche `data-platform` (clé T-203).
