---
id: T-466
title: "Durcissement de l'usine : plafonds de tours, étape Verdict, trailers always(), branche REST, prompt, outils étroits, job report"
status: in-progress
phase: P0
adr: [0021, 0022]
depends_on: [T-313]
class: REVUE
velocity: true
lane: factory
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-466 — Durcissement de l'usine : plafonds de tours, étape Verdict, trailers always(), branche REST, prompt, outils étroits, job report

## Intention
Corriger les défauts Q1, Q2 et Q6 de l'audit du premier run multi-issues (2026-11-18, run 44313706955). Le job `dev issue 66` était `failure` alors que la PR #70 était fusionnée : l'action refuse un résultat dont `num_turns` (79) dépasse `--max-turns` (60). `mission-result` disait `PASS` pour ce job en échec. Le contrôle des trailers était `skipped`. Le prompt exigeait `Claude-Session` sans sa valeur, d'où des refus `env` et `printenv`. `Bash(python3:*)` équivalait à un shell libre.

## Périmètre de fichiers
.github/workflows/claude-agent.yml, tools/factory/run-ticket.sh, tests/factory/, docs/AGENT-RUNNERS.md, docs/schema/mission-result.v1.json

## Critères de fin
- [x] plafonds de tours : Sonnet et Haiku 100, Opus 200 ; `timeout-minutes` ≤ 55 hors Opus (test `tests/factory/run-ticket-test.sh`)
- [x] étape `claude` en `continue-on-error` ; étape finale « Verdict » (`run-ticket.sh verdict`) seule juge du statut du job, d'après `steps.claude.outcome`, `max_turns` et l'issue du contrôle des trailers
- [x] motif `turn_cap_exceeded` (et `agent_error`, `action_error`, `trailers_refused`) dans `mission-result.v1` : schéma et test ; invariant testé : jamais `PASS` pour un job en échec (artefact, commentaire de PR, commentaire d'issue)
- [x] `always()` sur le contrôle des trailers
- [x] branche retrouvée par l'API REST `pulls?state=all` (pas l'index de recherche), nom imposé `claude/issue-<n>-*` dans le prompt
- [x] prompt : valeur de `Claude-Session` (URL du run), « ne lis jamais l'environnement », « n'attends pas la CI après l'auto-merge », `Closes #<n>` dans le corps de PR
- [x] `allowedTools` : `Bash(python3:*)` remplacé par des préfixes étroits ; ajout de `tools/dev/check`, `tests/`, `gh pr list`, `gh search` ; aucun `gh api` ; hooks inchangés
- [x] job `report` (`if: always()`) : commentaire de chaque issue avec le statut corrigé, jeton d'App neuf
- [ ] run réel (RUNTIME, preuve datée) : un dispatch de 2 issues ou plus montre le Verdict, le contrôle des trailers après un échec de l'agent, la branche retrouvée par REST et le commentaire `report` sur chaque issue
- [ ] run réel : aucun refus `env`, `printenv` ou `python3` dans `mission-result.permission_denials`

## Notes
Avancement 2026-11-18 (niveau STATIC) : `tests/factory/run-ticket-test.sh` PASS (cas Verdict, schéma, structure du workflow) ; actionlint propre ; expression jq de l'étape « Branche » rejouée en lecture seule sur l'API REST pulls (issue 66 → `claude/issue-66-ci-parity`, issue 57 → `agent/issue-57-…`, issue 6 → vide). NOT_TESTED : tout le reste en run réel (dispatch, geste de Paul).

Règle du Verdict (choisie ici, détail dans `docs/AGENT-RUNNERS.md`) : session réussie au-delà du plafond avec une branche livrée → `NOT_TESTED` / `turn_cap_exceeded`, job vert avec avertissement (le livrable existe, le budget est dépassé) ; session coupée par le CLI (`error_max_turns`) → `FAIL`. `no_branch`, `agent_error`, `trailers_refused`, `model_mismatch` et `action_error` → job rouge.

Jeton d'App (limite connue, non corrigée ici). Un jeton d'installation vit 1 h. Hors Opus, `timeout-minutes` = 45 (≤ 55, testé). Opus garde 90 min : après 60 min, push, PR, auto-merge et commentaire de PR échouent ; le job `report` a son propre jeton. Proposition pour Opus (à faire dans un ticket suivant, non implémentée) :
1. l'agent ne pousse plus : `--disallowedTools "Bash(git push:*)"` et pas de `gh pr create` ; il commit seulement ;
2. une étape après l'agent génère un jeton neuf (`actions/create-github-app-token`), pousse la branche `claude/issue-<n>-*`, ouvre la PR (`Closes #<n>`) et arme l'auto-merge ;
3. le commentaire de PR utilise ce même jeton neuf ;
4. variante plus simple : plafonner Opus à 55 min tant que 1 à 3 ne sont pas faits.
La régénération en cours de session n'est pas possible : l'action reçoit le jeton une fois, en entrée.

Hors périmètre, gardé pour d'autres tickets (audit, Q2 à Q5) : ledger et disjoncteur `LIMIT.json` branchés dans `plan` ; refus de recouvrement des périmètres ; contrôle périmètre ↔ critères dans `check.py` ; outils CI (`toolchain.lock`) sur le runner ; `check-selftest` en `NOT_TESTED` sous sandbox ; `client-id` au lieu de `app-id` ; suppression des branches fusionnées.

Implémentations publiques consultées :
- https://github.com/anthropics/claude-code-action/blob/469588f42e6b1e94cd14ad09dccfeaec772ce0fd/base-action/src/run-claude-sdk.ts | MIT | adapté (idée) | l'action lève une erreur si `num_turns` > `maxTurns` après une session réussie, et écrit quand même le fichier d'exécution : d'où `continue-on-error` et la lecture de `execution_file` par le Verdict.
- https://github.com/anthropics/claude-code-action/blob/469588f42e6b1e94cd14ad09dccfeaec772ce0fd/action.yml | MIT | adopté | sorties `conclusion`, `execution_file`, `branch_name`, `session_id` ; aucune ligne copiée.
- https://github.com/anthropics/claude-code-action/blob/469588f42e6b1e94cd14ad09dccfeaec772ce0fd/docs/usage.md | MIT | adopté | mode auto : une règle d'autorisation étroite évite la revue de sécurité, une règle large est ignorée : d'où des préfixes étroits plutôt que `Bash(python3:*)`.
- https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app | documentation | adopté | un jeton d'installation expire au bout de 1 h.
