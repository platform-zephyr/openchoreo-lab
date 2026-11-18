---
id: T-321
title: "Revue indépendante automatique avant merge (modèle différent, lecture seule)"
status: todo
phase: P0
adr: [0002, 0021]
depends_on: [T-002, T-061, T-313]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-321 — Revue indépendante automatique avant merge (modèle différent, lecture seule)

## Intention
Sur chaque PR claude/*, une session de revue indépendante (autre modèle, outils en lecture, `--comment`) vérifie périmètre, classe, preuves déclarées et absence de secret ; elle publie PASS ou FAIL comme statut requis pour le merge automatique.

## Périmètre de fichiers
.github/workflows/factory-review.yml, .agents/skills/review-pr/SKILL.md

## Critères de fin
- [ ] PR volontairement fautive (chemin du noyau modifié, secret factice) : FAIL
- [ ] PR correcte : PASS sans commentaire superflu
- [ ] coût par revue mesuré et plafonné (--max-turns)

## Notes
Le reviewer ne modifie jamais la branche (coordination Atlas). Sur dépôt public, la revue ne tourne que sur les branches du dépôt (secrets non transmis aux forks).

Proposé par la recherche `factory` (clé FAC-12) ; intégration 2 du 2026-11-18.

Dépendance gelée retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-382.
