---
id: T-313
title: "Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1"
status: in-progress
phase: P0
adr: [0002, 0013, 0021]
depends_on: [T-210, T-311]
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
.github/workflows/claude-agent.yml, .github/workflows/ci.yaml, tools/factory/run-ticket.sh, docs/AGENT-RUNNERS.md, .github/pull_request_template.md, docs/schema/mission-result.v1.json, tests/factory/

## Critères de fin
- [ ] lancement manuel avec une liste d'ID : N PR parallèles sur couloirs distincts (preuve datée)
- [ ] chaque PR porte durée, tours, coût estimé et statuts PASS/FAIL/NOT_TESTED
- [x] (repris de MOD-4) run de test : la session s'exécute sur le modèle demandé (preuve : modèle consigné dans la sortie result) (2026-11-18 : run `claude-agent` 44307563892, artefact `mission-result-57` : `model_requested` = `model_observed` = `claude-sonnet-5-5`, 10 tours, `total_cost_usd` 0,1652 ; RUNTIME)
- [x] (repris de MOD-4) entrées `model` et `effort` du workflow passées à claude_args (--model, --effort) ; Sonnet plafonné à `xhigh`
- [ ] (repris de MOD-5) trailers Model, Effort, Escalated-from sur chaque PR d'agent ; mission-result.v1 contient modèle, effort, escalade, tokens, tours, durée, échecs CI, sans aucun prompt
- [x] (repris de HAR-3) le résumé du job affiche total_cost_usd et num_turns, aucune sortie d'outil
- [x] `show_full_output` absent ; aucun secret hors jeton Claude
- [x] config git `noreply` et trailers (Ticket, Model, Effort, Claude-Session) imposés par l'exécutant dès S0 ; un commit d'agent sans trailer ou avec un e-mail personnel est refusé par la CI (test) — PROUVÉ (RUNTIME) : un commit d'agent sans trailer est refusé : run 44326043746, contrôle `check-trailers` du workflow (FAIL `trailers_refused`) et job CI `agent-trailers` sur la PR #77 ; accepté avec trailers injectés : run 44331128791 (issue 74, PR #81 du bot : 27 tours, 0,66 $, statut PASS, commit avec les 5 trailers injectés par le hook, 18 checks verts dont `agent-trailers`, branche `claude/issue-74-…` retrouvée, commentaire `report`), 2026-11-18
- [x] plafonds par modèle : Opus 90 min et 150 tours ; Sonnet et Haiku 45 min et 60 tours (`timeout-minutes`, `--max-turns`)

## Notes
Avancement 2026-11-18 (niveau STATIC : `tests/factory/run-ticket-test.sh`, 22 contrôles PASS ; `tests/factory/pause-test.sh` PASS ; `check.py` 0 erreur). Cases cochées : model/effort dans claude_args, résumé du job, `show_full_output` absent, plafonds. Reste NOT_TESTED, faute de run réel (geste de Paul, dispatch + jeton) : lancement parallèle, durée/tours/coût dans chaque PR, modèle observé en run réel, trailers Model/Effort/Escalated-from sur chaque PR (le prompt les exige, rien ne le prouve), mission-result.v1 complet (échecs CI = 0 provisoire). Reste à faire dans un autre périmètre : brancher `run-ticket.sh check-trailers` dans `ci.yaml` pour refuser tout commit d'agent sans trailer (la preuve existe dans le job du workflow et en test, pas dans la CI des PR).
Un label posé par GITHUB_TOKEN ne déclenche pas de workflow : utiliser dispatch avec le jeton de l'App. Plafond de départ 4, relevé par T-322.

La proposition visait : T-210 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `factory` (clé FAC-4) ; intégration 2 du 2026-11-18.

Fusion de HAR-3 (même fichier), de la partie « passage du modèle » de MOD-4 et du schéma de MOD-5 (un seul schéma : mission-result.v1, pas de model-run.v1 séparé). L'escalade de MOD-4 est dans T-317.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Version minimale (consensus n°2 et arbitrages de Paul, 2026-11-18) : lancé par Paul (workflow_dispatch) avec l'identité de dev ; les outils étroits, le mode de permission et l'essai du noyau passent à la revue finale T-401.

Arbitrage Fable (arbitrage Fable, 2026-11-18) : `noreply` et trailers imposés dès S0 (F2) ; plafonds Opus portés à 90 min / 150 tours (P6).

Examen du 2026-11-18 (RUNTIME, run 44307563892 → PR #63, ouverte par `openchoreo-worker[bot]`). Prouvé : modèle observé = demandé ; `mission-result.v1` archivé avec modèle, effort, escalade (null), tokens, tours, durée, échecs CI (0 provisoire), sans prompt ; commit en `noreply@anthropic.com` avec `Ticket`, `Model`, `Effort`, `Claude-Session`. Reste : (a) lancement parallèle de N issues sur couloirs distincts, jamais joué ; (b) le corps de la PR #63 dit « non mesuré » pour durée, tours et coût : la case « chaque PR porte durée, tours, coût » n'est pas prouvée ; (c) trailers « sur chaque PR » : une seule PR d'essai, `Escalated-from` jamais exercé ; (d) l'étape `check-trailers` du job était `skipped` dans ce run, et `ci.yaml` n'appelle pas `run-ticket.sh check-trailers` : le refus par la CI d'un commit sans trailer n'est prouvé que par test (22 contrôles PASS rejoués ici). Écart levé (2026-11-18, `gh api` en lecture seule sur les artefacts `mission-result-57` des 10 runs de l'issue #57) : les 13 tours et ~0,14 $ de la note T-304 sont ceux du run 44299104705 (13 tours, 0,1425 $), pas du run 44307563892 (10 tours, 0,1652 $) ; la note T-304 donne maintenant le chiffre par run.

Suite du 2026-11-18 (niveau STATIC, aucun run joué) : (1) `ci.yaml` porte le job `agent-trailers` (`run-ticket.sh check-trailers origin/main..HEAD` sur les PR dont la branche commence par `claude/` ou `agent/` ou dont l'auteur est le bot de l'exécutant), dans `needs` de `ci-ok` ; le job n'a pas de `if` (un job `skipped` ferait échouer `ci-ok`), seules ses étapes sont conditionnelles ; (2) `claude-agent.yml` publie une ligne (`run-ticket.sh comment`) en commentaire de PR avec le jeton de l'App ; (3) la branche de l'agent est retrouvée par la PR `claude/*` ou `agent/*` qui cite l'issue quand la sortie `branch_name` de l'action est vide : c'était le cas du run 44307563892 (PR #63 sur la branche `agent/issue-57-…`, d'où `no_branch`, `check-trailers` ignoré et aucun contrôle). Preuves : `tests/factory/run-ticket-test.sh` (cas négatifs : commit sans trailer, e-mail personnel, `Claude-Session` absent ; contrôle du branchement `ci.yaml`) ; actionlint et yamllint verts. NOT_TESTED : exécution réelle du job `agent-trailers` sur une PR, du commentaire de PR et de la résolution de branche (prochain dispatch) ; le commentaire n'est pas le corps de la PR : la case « chaque PR porte durée, tours, coût » reste ouverte jusqu'à une PR réelle.
