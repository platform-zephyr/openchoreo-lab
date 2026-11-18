---
id: T-352
title: "Boucle d'amélioration du harness : journal d'échecs, règle « deux fois = hook ou test », revue mensuelle"
status: deferred
phase: P5
adr: [0012, 0022]
depends_on: [T-061, T-340, T-346]
class: AUTONOME
velocity: false
lane: agents-harness
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-352 — Boucle d'amélioration du harness : journal d'échecs, règle « deux fois = hook ou test », revue mensuelle

## Intention
Chaque échec d'agent (PR rejetée, CI rouge répétée, blocage) reçoit une ligne : cause classée (contexte, outil, hook manquant, test faible, tâche mal posée), correctif au bon étage (hook > test > skill > AGENTS.md) et tâche de banc ajoutée. Une faute vue deux fois crée un ticket HAR. Revue mensuelle par Paul (30 minutes, une page).

## Périmètre de fichiers
docs/harness/FAILURES.md, tools/bench/triage.py

## Critères de fin
- [ ] journal initial avec 5 échecs réels du dépôt (revues de PR #8 et #36, incidents de STATE.md)
- [ ] script : liste les fautes répétées et propose le ticket
- [ ] une tâche de banc créée à partir d'un échec du journal

## Notes
Aucune transcription brute dans le dépôt public : une synthèse sans secret seulement.

Proposé par la recherche `harness` (clé HAR-22) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : règle d'usine d'ADR-0021 (décision 10) ; avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
