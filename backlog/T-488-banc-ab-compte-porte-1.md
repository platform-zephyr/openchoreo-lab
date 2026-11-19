---
id: T-488
title: "Campagne A/B comptée sur OKE (16 runs + 6 pièges, arrêt anticipé) et décision de Paul sur la porte 1"
status: deferred
phase: P1
adr: [0025, 0020]
depends_on: [T-486]
class: AUTONOME + MANDAT
velocity: true
lane: banc-ab
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-488 — Campagne A/B comptée sur OKE et décision de la porte 1

## Intention
Mesurer l'hypothèse H (`docs/research/POC-OPENCHOREO-STRATEGY.md` §2.1) : pièges d'abord, puis 4 tâches × 2 runs × 2 bras par l'usine, ordre alterné ; verdict par les seuils préenregistrés ; arrêt anticipé dès qu'un seuil devient inatteignable ; décision de Paul.

## Périmètre de fichiers
docs/research/POC-AB-RESULTS.md, tests/bench-ab/results/, docs/adr/0025-validation-en-deux-portes.md

## Critères de fin
- [ ] 6 pièges joués en premier ; un piège non contenu par le bras O arrête la campagne (verdict « arrêt »)
- [ ] runs comptés (16 au plus) avec artefacts `mission-result.v1` archivés ; aucune intervention humaine pendant les runs (S7)
- [ ] S1, S2, S3, S5, S6, S7 calculés par l'agrégateur de T-485 pour chaque bras, preuves datées (niveau RUNTIME OKE)
- [ ] rapport daté avec verdict « valeur prouvée » ou « arrêt » selon `tests/bench-ab/thresholds.yaml`
- [ ] MANDAT Paul : décision de la porte 1 consignée par amendement d'ADR-0025, au plus tard le 2026-12-02
- [ ] si « arrêt » : T-361 à T-366 passent `dropped` dans la même PR

## Notes
Plafonds de l'usine inchangés (Sonnet 5.5 `high`, 100 tours, 3 $ par run). Au plus 3 runs en parallèle ; un seul bras actif à la fois si T-486 l'a décidé. Aucune correction de plateforme ni de dépôt pendant la campagne.
- Abandonné le 2026-11-19 (décision de Paul, chat de l'orchestrateur) : le banc A/B (passe 0, campagne comptée, bras K, harnais, seuils, graders) est arrêté ; plus long et plus cher qu'un déploiement jetable réel sur OKE, et il ne mesure pas l'IDP. Paul fait lui-même un test d'usage sur un déploiement réel d'OpenChoreo (T-520). Historique conservé ; voir T-521.
