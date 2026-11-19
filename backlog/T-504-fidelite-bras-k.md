---
id: T-504
title: "Revue de fidélité du bras K avant la passe 0 (lecture seule, kube-ops ef50472)"
status: in-progress
phase: P1
adr: [0025]
depends_on: [T-212]
class: AUTONOME
velocity: false
lane: banc-ab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-504 — Revue de fidélité du bras K

## Intention
`docs/research/POC-OPENCHOREO-STRATEGY.md` §2.5 point 5 exige, avant la passe 0, une revue indépendante : le bras K (`bench-ab-arm-k` @ `742bbd6`) reproduit-il le chemin kube-ops (figé à `ef50472`) sans avantager ni handicaper une mesure ? Comparer chart, `AGENTS.md`, skills, admission, gates, pièges. Un écart dû à « aucun développement sur kube-ops » est une mesure à consigner, pas à corriger.

## Périmètre de fichiers
tests/bench-ab/arm-k/FIDELITY-REVIEW.md, backlog/T-504-fidelite-bras-k.md

## Critères de fin
- [x] `tests/bench-ab/arm-k/FIDELITY-REVIEW.md` (≤ 2 pages) : verdict par point, écarts classés, liens fichier:ligne — STATIC, 2026-11-19
- [ ] Paul arbitre E1 (namespace `svc-*` du chart contre `lab-k-*`), E5 (kinds de l'AppProject `lab-k`), E6 (M3 sans non-prod), E2 (portes de kube-ops copiées ou non)
- [ ] Corrections décidées appliquées dans le bac à sable (hors de ce dépôt), puis revue relancée : verdict PASS avant la passe 0 (T-486)

## Notes
Lecture seule des deux dépôts ; aucun accès cluster. Verdict initial : FAIL conditionnel (3 écarts bloquants : E1, E5, E6).
