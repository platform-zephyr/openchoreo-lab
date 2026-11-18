---
id: T-313
title: "Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1"
status: todo
phase: P0
adr: [0002, 0013, 0021]
depends_on: [T-061, T-210, T-311]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-313 — Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1

## Intention
Remplacer le déclencheur par label (acteur SmadjaPaul) par workflow_dispatch(ticket, modèle) lancé par Paul ou l'App ; une session neuve par ticket ; --model, --max-turns, timeout, concurrence par ticket ; sortie JSON archivée ; compte rendu au format de mission-contract Atlas.

## Périmètre de fichiers
.github/workflows/claude-agent.yml, tools/factory/run-ticket.sh, docs/AGENT-RUNNERS.md, .github/pull_request_template.md, docs/schema/mission-result.v1.json

## Critères de fin
- [ ] lancement manuel avec une liste d'ID : N PR parallèles sur couloirs distincts (preuve datée)
- [ ] chaque PR porte durée, tours, coût estimé et statuts PASS/FAIL/NOT_TESTED
- [ ] (repris de MOD-4) run de test : la session s'exécute sur le modèle demandé (preuve : modèle consigné dans la sortie result)
- [ ] (repris de MOD-4) entrées `model` et `effort` du workflow passées à claude_args (--model, --effort) ; Sonnet plafonné à `xhigh`
- [ ] (repris de MOD-5) trailers Model, Effort, Escalated-from sur chaque PR d'agent ; mission-result.v1 contient modèle, effort, escalade, tokens, tours, durée, échecs CI, sans aucun prompt
- [ ] (repris de HAR-3) le résumé du job affiche total_cost_usd et num_turns, aucune sortie d'outil
- [ ] `show_full_output` absent ; aucun secret hors jeton Claude

## Notes
Un label posé par GITHUB_TOKEN ne déclenche pas de workflow : utiliser dispatch avec le jeton de l'App. Plafond de départ 4, relevé par T-322.

La proposition visait : T-210 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `factory` (clé FAC-4) ; intégration 2 du 2026-11-18.

Fusion de HAR-3 (même fichier), de la partie « passage du modèle » de MOD-4 et du schéma de MOD-5 (un seul schéma : mission-result.v1, pas de model-run.v1 séparé). L'escalade de MOD-4 est dans T-317.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Version minimale (consensus n°2 et arbitrages de Paul, 2026-11-18) : lancé par Paul (workflow_dispatch) avec l'identité de dev ; les outils étroits, le mode de permission et l'essai du noyau passent à la revue finale T-401.
