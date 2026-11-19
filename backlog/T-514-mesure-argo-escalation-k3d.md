---
id: T-514
title: "Mesure d'`argo-escalation` et de la suite k3d complète sur main après le correctif de T-505"
status: in-progress
phase: P1
adr: [0004, 0011]
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
# T-514 — Mesure d'`argo-escalation` et de la suite k3d complète sur main après le correctif de T-505

## Intention
T-505 (couloir `argo-escalation`) corrige la suite. Après sa fusion, mesurer le résultat réel : suite `argo-escalation` et suite k3d complète sur main (durée, taux de succès, flaky), pour savoir ce que la CI prouve vraiment avant de s'y fier (T-513).

## Périmètre de fichiers
backlog/evidence/T-514-*.md, docs/CI-K3D.md

## Critères de fin
- [x] T-505 fusionné (vérifié par `git log origin/main` : c413af7, #173)
- [ ] suite complète lancée par dispatch sur main : verdict par suite (PASS/FAIL/NOT_TESTED), durée, run cité, daté, dans `backlog/evidence/`
- [ ] 3 exécutions consécutives de `argo-escalation` : taux de succès et causes d'échec classées (environnement ou défaut) ; chiffres reportés dans `docs/CI-K3D.md`

## Avancement (2026-11-19)
Mesure en lecture seule sur 17 runs existants et triage du run 44507884152 : `backlog/evidence/T-514-mesure-k3d-2026-11-19.md`, résumé dans `docs/CI-K3D.md` §4. `argo-escalation` échoue sur main depuis T-502 (#174) : `run.sh` ne copie pas `clusters/` dans le dépôt de test (niveau statique). Les 2 critères restants attendent le correctif de la suite puis des dispatchs sur main, un run à la fois.

## Notes
Dépend de T-505 (propriétaire du couloir) : ne pas le modifier ici. Un job rouge de niveau L2 ou moins est un défaut de l'environnement local à corriger (AGENTS.md).
