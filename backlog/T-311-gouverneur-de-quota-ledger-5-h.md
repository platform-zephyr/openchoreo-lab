---
id: T-311
title: "Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 réelle (max-parallel ou groupes par couloir)"
status: in-progress
phase: P0
adr: [0017, 0021]
depends_on: []
class: REVUE
velocity: true
lane: agents
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-311 — Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 réelle (max-parallel ou groupes par couloir)

## Intention
Le minimum pour lancer le pilote sans dérive : `factory/PAUSE` arrête tout lancement et tout merge automatique ; la concurrence est plafonnée à 3 par une matrice `max-parallel: 3` ou par des groupes de concurrence par couloir, jamais par un groupe unique (un groupe GitHub n'admet qu'un run actif et un en attente, et annule le suivant).

## Périmètre de fichiers
factory/config.yaml, factory/PAUSE, .github/workflows/claude-agent.yml (matrice `max-parallel` ou groupes par couloir), docs/AGENT-PR-MODEL.md

## Critères de fin
- [ ] factory/PAUSE présent = aucun lancement, aucun merge automatique (test) — STATIC PASS : tests/factory/pause-test.sh (lancement) ; NOT_TESTED : run réel, désarmement d'un auto-merge déjà armé
- [ ] concurrence 3 par matrice `max-parallel: 3` ou par groupes de concurrence par couloir ; test : 5 dispatchs → 5 runs terminés, aucun annulé
  STATIC PASS : actionlint 1.7.12, `max-parallel: 3` = config ; NOT_TESTED : run réel de 5 dispatchs (T-304, pilote)
- [x] règle écrite : une clé API facturée au token exige un plafond mensuel Console (MANDAT) ; aucun euro par agent promis

## Notes
Les valeurs sont des estimations côté client (docs headless), pas la facture. Pas d'API de solde d'abonnement lue : NOT_PROVEN, ne pas gratter claude.ai. Fichiers du noyau (factory/) : REVUE.

La proposition visait : T-145 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `factory` (clé FAC-2) ; intégration 2 du 2026-11-18.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Constat P5 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).

Examen du 2026-11-18 : `tests/factory/pause-test.sh` rejoué ici, PASS (dont `max-parallel` workflow = config = 3, aucun groupe de concurrence unique, workflow branché sur le kill-switch ; `factory/PAUSE` absent aujourd'hui). Aucune des deux cases ouvertes n'est prouvable sans run : le test ne couvre ni le désarmement d'un auto-merge déjà armé, ni le lot réel de 5 dispatchs (les runs `claude-agent` existants sont des dispatchs d'une issue). Reste : un run avec `factory/PAUSE` posé, et un dispatch de 5 issues (T-322 ou un essai dédié, geste de Paul pour lancer).
