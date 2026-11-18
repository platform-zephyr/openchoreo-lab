---
id: T-420
title: "Revue hebdomadaire de maintenabilité par un agent (dette, au plus 3 refactors proposés)"
status: in-progress
phase: P1
adr: [0024]
depends_on: [T-414]
class: AUTONOME
velocity: false
lane: usine
stage: S2
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-420 — Revue hebdomadaire de maintenabilité par un agent (dette, au plus 3 refactors proposés)

## Intention
Tâche planifiée cloud en lecture seule, à côté du trieur T-320 : lit `quality.v1` des 4 dernières semaines, les 5 fichiers les plus modifiés, les fonctions gelées touchées ; écrit une issue de synthèse et au plus 3 propositions dans `backlog/proposals/` (cible, mesure avant, mesure attendue, test oracle).

## Périmètre de fichiers
factory/quality-review.md, .agents/skills/quality-review/SKILL.md

## Critères de fin
- [x] essai daté : une revue sur l'historique réel rend ≤ 3 propositions au format FORMAT.md, chacune avec une mesure avant (STATIC, 2026-11-18, commit 74fd1cc, `factory/quality-review.md` § Essai ; historique quality.v1 d'une ligne : tendance NOT_PROVEN)
- [x] règle écrite (`factory/quality-review.md` § Règle de budget) : budget de 1 ticket de dette pour 10 tickets de fonctionnalité, immédiat si le cliquet s'est tendu ; un refactor n'est jamais mêlé à une fonctionnalité
- [ ] coût en tokens d'une revue consigné (T-326) : plafond écrit, coût réel NOT_TESTED jusqu'au premier run

## Notes
Proposition QA-10 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Aucun accès cluster, aucun secret ; propose, ne refactore pas.

Le trieur T-320 est différé après la porte : la tâche planifiée est lancée à la main ou à côté de lui quand il existera ; pas de dépendance gelée.

Routage R2 (ADR-0023) : Haiku `medium`, revue Sonnet en check requis (2 refus → Sonnet) ; ne touche ni l'en-tête du ticket ni backlog/proposals/. Le dispatcher relance en Sonnet si le diff réel sort du périmètre texte.
