---
id: T-486
title: "Passe 0 non comptée du banc A/B sur OKE (graders et harnais débogués, gel des SHA)"
status: todo
phase: P1
adr: [0025]
depends_on: [T-003, T-005, T-212, T-485, T-491]
class: AUTONOME
velocity: true
lane: banc-ab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-486 — Passe 0 non comptée du banc A/B sur OKE

## Intention
Déboguer le harnais, les graders et le bootstrap des deux bras sur le cluster même de la mesure (OKE recréé vierge), puis geler les SHA et commiter les seuils. Remplace la répétition sur le MacBook (arbitrages de Paul n°3). Aucun résultat de cette passe ne compte pour la porte 1.

## Périmètre de fichiers
tests/bench-ab/pass-0/, docs/research/POC-AB-PASS-0.md

## Critères de fin
- [ ] chaque tâche M1-M4 jouée une fois par bras par l'usine, et les 3 pièges par le bras O ; chaque grader rend le verdict attendu au moins une fois (rapport daté, niveau RUNTIME OKE)
- [ ] une app A du bras K et une app A du bras O avec check run `success` publié depuis OKE (preuve datée)
- [ ] empreinte relevée avec un bras actif puis les deux (requests, pods) ; règle « un bras actif à la fois » décidée dans le rapport
- [ ] revue de fidélité du bras K par une session côté kube-ops (lecture seule), datée, avant le premier run de la passe
- [ ] SHA des deux dépôts gelés et `tests/bench-ab/thresholds.yaml` commité avant le premier run compté (horodatage Git)

## Notes
Exécutée par l'usine (agents cloud) ; la session locale du Mac n'intervient que pour une synchro manuelle de `lab-platform` (brief `docs/research/POC-BRIEF-SESSION-LOCALE.md`). Colima : repli seulement si OKE est injoignable ou hors budget (preuve k3d, dite comme telle).

Recadré (arbitrages de Paul n°3, 2026-11-18) : l'ancienne « répétition sur le MacBook » est supprimée ; même identifiant, même couloir.
