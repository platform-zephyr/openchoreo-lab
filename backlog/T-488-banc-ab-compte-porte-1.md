---
id: T-488
title: "Banc A/B compté sur OKE (30 runs + 10 pièges) et décision de Paul sur la porte 1"
status: todo
phase: P1
adr: [0025, 0020]
depends_on: [T-005, T-006, T-212, T-485, T-486, T-487]
class: AUTONOME + MANDAT
velocity: true
lane: banc-ab
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-488 — Banc A/B compté sur OKE et décision de la porte 1

## Intention
Mesurer l'hypothèse H (`docs/research/POC-OPENCHOREO-STRATEGY.md` §2.1) : 5 tâches × 3 runs × 2 bras par l'usine, ordre alterné, plus 5 pièges par bras ; verdict par les seuils préenregistrés ; décision de Paul.

## Périmètre de fichiers
docs/research/POC-AB-RESULTS.md, tests/bench-ab/results/, docs/adr/0025-validation-en-deux-portes.md

## Critères de fin
- [ ] revue de fidélité du bras K par un agent côté kube-ops avant le premier run compté (lecture seule)
- [ ] 30 runs comptés et 10 pièges, artefacts `mission-result.v1` archivés ; aucune intervention humaine pendant les runs (S7)
- [ ] S1-S7 calculés par l'agrégateur de T-485 pour chaque bras, preuves datées (niveau RUNTIME OKE)
- [ ] rapport daté avec verdict « valeur prouvée », « zone grise » ou « arrêt » selon `tests/bench-ab/thresholds.yaml`
- [ ] MANDAT Paul : décision de la porte 1 consignée par amendement d'ADR-0025, au plus tard le 2026-12-11
- [ ] si « arrêt » : T-361 à T-366 passent `dropped` dans la même PR

## Notes
Plafonds de l'usine inchangés (Sonnet 5.5 `high`, 100 tours, 3 $ par run). Au plus 3 runs en parallèle ; un seul bras actif à la fois sur OKE si T-487 mesure un dépassement.
