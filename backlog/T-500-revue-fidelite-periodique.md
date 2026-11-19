---
id: T-500
title: "Revue de fidélité périodique à OpenChoreo (natif, extension prévue, adaptation, hacky) et mesure de complexité"
status: in-progress
phase: P1
adr: [0020, 0024]
depends_on: []
class: AUTONOME
velocity: false
lane: recherche
stage: S1
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-500 — Revue de fidélité périodique

## Intention
Mandat de Paul : une plateforme la plus facilement opérable ; la complexité doit être justifiée ; adopter les
primitives de base d'OpenChoreo quitte à perdre un peu de fonctionnalité ; aucun développement sur kube-ops.
Toutes les ~3 h, un relecteur compare ce que `main` contient à l'amont (sources primaires) et note chaque composant
NATIF, EXTENSION PRÉVUE, ADAPTATION ou HACKY, avec son coût d'exploitation et une simplification. Les mesures de
complexité sont rejouables : mêmes commandes à chaque revue, pour comparer. Une revue ajoute une section datée au
journal ; elle ne réécrit jamais les précédentes.

## Périmètre de fichiers
docs/research/FIDELITE-JOURNAL.md, backlog/T-500-revue-fidelite-periodique.md

## Critères de fin
- [x] Revue n°1 (base de départ) dans `docs/research/FIDELITE-JOURNAL.md` : tableau des verdicts, mesures, ≤ 3
  propositions, questions à Paul — STATIC, 2026-11-19
- [ ] Paul répond aux questions de la revue n°1 ; réponses reportées dans `## Notes`
- [ ] Revue n°2 avec la section « ce qui a changé » et les mêmes mesures rejouées

## Notes
- Ticket récurrent : il reste `in-progress` tant que Paul veut la revue périodique.
- Ne modifie aucun autre fichier que le journal et ce ticket.
