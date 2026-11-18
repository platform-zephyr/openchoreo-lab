---
id: T-315
title: "Merge automatique sous conditions : auto-merge natif pendant le dev, App de merge en FINAL"
status: todo
phase: P0
adr: [0002, 0021]
depends_on: [T-061, T-061b, T-210, T-321]
class: REVUE + MANDAT
velocity: true
lane: gouvernance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-315 — Merge automatique sous conditions : auto-merge natif pendant le dev, App de merge en FINAL

## Intention
Armer `gh pr merge --auto --squash` avec le jeton de l'App quand : auteur claude/*, chemins hors noyau, classe AUTONOME recalculée, ci-ok vert, revue indépendante PASS, diff sous le seuil, une seule PR par (app, env), pas de PAUSE. Noyau : armer aussi, mais l'approbation de Paul sur mobile reste requise.

## Périmètre de fichiers
.github/workflows/factory-merge.yml, tools/factory/merge_gate.py, tests/factory/

## Critères de fin
- [ ] matrice de tests : chaque condition fausse = label needs-paul, aucun merge (7 cas négatifs)
- [ ] essai daté : PR AUTONOME fusionnée sans humain ; PR du noyau fusionnée après un seul tap d'approbation de Paul
- [ ] aucun contournement : pas de --admin, ruleset et checks requis intacts

## Notes
MANDAT : activer « Allow auto-merge » ; vérifier le comportement avec le ruleset à 0 approbation (NOT_PROVEN à ce jour). Pas d'automerge des digests d'actions ni d'apps avant T-124 (CONSENSUS #10).

Proposé par la recherche `factory` (clé FAC-6) ; intégration 2 du 2026-11-18.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-007, T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

(consensus n°2 et arbitrages de Paul, 2026-11-18) : pendant le développement, l'auto-merge natif est armé par la session (identité de Paul) avec les mêmes conditions ; l'App de merge arrive avec T-215 (FINAL).
