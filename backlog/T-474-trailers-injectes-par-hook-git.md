---
id: T-474
title: "Trailers de commit injectés par un hook git du workflow (Ticket, Model, Effort, Escalated-from, Claude-Session)"
status: in-progress
phase: P0
adr: [0021, 0022]
depends_on: [T-466]
class: REVUE
velocity: true
lane: factory
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-474 — Trailers de commit injectés par un hook git du workflow

## Intention
Ne plus dépendre de la mémoire du modèle pour les trailers. Run usine 44326043746 (issue 74, T-470) : la PR #77 est livrée, mais son commit n'a aucun des trailers exigés (`Ticket`, `Model`, `Effort`, `Claude-Session`) malgré le prompt qui les donnait ; `check-trailers` refuse à raison (`FAIL trailers_refused`). Le workflow installe donc, avant l'agent, un hook git hors du dépôt qui ajoute ces trailers et impose l'identité `noreply@anthropic.com`. `check-trailers` reste le juge final.

## Périmètre de fichiers
.github/workflows/claude-agent.yml, tools/factory/commit-trailers.sh, tools/factory/run-ticket.sh, tests/factory/, docs/AGENT-RUNNERS.md, backlog/T-474-trailers-injectes-par-hook-git.md, backlog/STATUS.md

## Critères de fin
- [x] `tools/factory/commit-trailers.sh install <rép>` : hooks `prepare-commit-msg` et `commit-msg` (copie du script, 0555), valeurs dans `trailers.values` (0444), répertoire 0555 ; variable absente ou invalide → code 2, message explicite, rien d'installé ; commit d'essai dans un dépôt temporaire avant de rendre la main
- [x] hook : trailers absents ajoutés avec `git interpret-trailers` dans l'ordre `Ticket`, `Model`, `Effort`, `Escalated-from` (si non vide), `Claude-Session` ; valeur fausse ou en double remplacée (un seul exemplaire) ; `Co-Authored-By` gardé ; valeurs lues à côté du hook, jamais dans l'environnement de l'agent ; auteur ou committer autre que `noreply@anthropic.com` → commit refusé
- [x] workflow : étape `hooks` après `ticket` et avant `claude` (valeurs : entrées du workflow, URL du run, `AGENT_TICKET_ID` de `run-ticket.sh ticket-env` ; aucun secret) ; répertoire à root (`sudo chown`) ; `core.hooksPath` dans `.git/config` et par `GIT_CONFIG_COUNT` dans `$GITHUB_ENV` ; `GIT_AUTHOR_*` et `GIT_COMMITTER_*` dans l'`env` du job ; prompt : « un hook ajoute les trailers, ne contourne aucun hook »
- [x] `check-trailers` lit les trailers avec `--no-divider` (une ligne `---` du corps ne coupe pas le message), comme le hook
- [x] `tests/factory/commit-trailers-test.sh` PASS (2026-11-18, 45 cas) : sans trailers, partiels, valeur fausse, doublons, multi-lignes avec `---`, `--allow-empty`, éditeur avec commentaires, message vide (commit annulé), `--amend`, `--no-verify`, merge `--no-ff`, identité refusée, valeurs absentes ou altérées, environnement de l'agent ignoré, cas négatifs d'installation, garde Bash (`--no-verify`, `-n`, `-anm` refusés), structure du workflow ; test du test : workflow muté (étape `hooks` après `claude`) → FAIL
- [x] `actionlint` propre ; `shellcheck` propre sur les scripts touchés ; `tests/factory/*.sh` tous PASS ; `tools/backlog/check.py` 0 erreur
- [ ] run réel (RUNTIME, preuve datée) : un dispatch montre l'étape `hooks` verte, des commits de l'agent avec les 5 trailers et `check-trailers` PASS
- [ ] run réel : vérifier que l'environnement du job (`GIT_CONFIG_*`, `GIT_AUTHOR_*`) atteint le Bash de l'agent dans `claude-code-action`

## Notes
Avancement 2026-11-18 (niveau STATIC). NOT_TESTED : tout le comportement sur le runner (sudo, `RUNNER_TEMP`, propagation de l'environnement à l'agent).

Choix : `prepare-commit-msg`, car githooks(5) dit qu'il « n'est pas supprimé par l'option `--no-verify` » ; `commit-msg` repasse après l'éditeur (il est, lui, supprimé par `--no-verify`). Une valeur présente est remplacée par celle du workflow plutôt que gardée : l'agent ne connaît pas mieux que le workflow le modèle, l'effort ou l'URL du run. Un message vide (hors commentaires) reste vide : git annule le commit ; le hook ne fabrique pas un message de trailers seuls. Une issue sans ticket fait échouer l'installation (avant : simple avertissement) ; `check-trailers` l'aurait refusée de toute façon.

Risque résiduel (détail : `docs/AGENT-RUNNERS.md`) : l'agent garde `Bash(git:*)`, donc `git -c core.hooksPath=<autre> commit`, `git commit-tree` et la réécriture d'historique restent possibles ; la garde Bash laisse passer `git -C <dir> commit --no-verify` (sans effet sur `prepare-commit-msg`). Suite proposée (autre ticket, couloir `agents-harness`) : refuser `core.hooksPath`, `commit-tree` et `-C <dir> ... --no-verify` dans `.claude/hooks/pretool-bash-guard.sh`. `check-trailers` reste le juge final dans tous les cas.

Implémentations publiques consultées :
- https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt | GPL-2.0 (documentation) | adopté (idée, aucune ligne copiée) | `prepare-commit-msg` modifie le message en place et n'est pas supprimé par `--no-verify` ; `commit-msg` l'est ; `core.hooksPath` change le répertoire des hooks. Permalien par tag, pas par SHA40 : l'API GitHub et git-scm.com étaient inaccessibles depuis la session (403, DNS).
- https://github.com/git/git/blob/v2.43.0/Documentation/git-interpret-trailers.txt | GPL-2.0 (documentation) | adopté (outil amont appelé, aucune ligne copiée) | `--in-place`, `--trailer`, `--where end`, `--if-exists replace`, `--if-missing add`, `--no-divider` (« ne pas traiter `---` comme la fin du message ») : l'outil standard de git fait l'insertion, pas un code propre.
- Code propre (dernier recours) : `strip_keys` (awk) retire les doublons du bloc final, car `--if-exists replace` ne retire qu'une occurrence (constaté avec git 2.43.0, test « doublons de l'agent »).
