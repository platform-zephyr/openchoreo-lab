# Agents sur runners GitHub (claude-code-action)

Principe (T-313) : `workflow_dispatch` lancé par Paul (issues, modèle, effort ; plus de déclencheur par label) -> une session neuve par issue -> job GitHub (ubuntu-24.04-arm) -> branche `claude/*` -> PR -> `ci-ok`
-> file de fusion -> Argo CD déploie. L'agent n'a aucun accès OKE ; la preuve runtime reste au coordinateur
(tests/golden-path-*, tests/idp-demo). Frontière de privilèges : docs/AGENT-PR-MODEL.md (CODEOWNERS + ruleset).

## Mise en route (Paul, une fois)
1. Dans le dépôt : `claude` puis `/install-github-app` (admin du dépôt ; choisir CE dépôt seulement). Ne garde pas le workflow
   qu'il propose : celui de `.github/workflows/claude-agent.yml` fait foi.
2. Jeton : `claude setup-token`, puis `gh secret set CLAUDE_CODE_OAUTH_TOKEN` (abonnement Max : quotas partagés avec tes
   sessions, 4 jobs max en parallèle au départ). Pour dépasser 4 : clé API Console avec plafond de dépense, remplacer
   `claude_code_oauth_token` par `anthropic_api_key` (une ligne).
3. Plus de label : le lancement est `gh workflow run claude-agent.yml -f tickets="101,102,103" -f model=claude-sonnet-5-5 -f effort=high` (ou l'onglet Actions). `escalated_from` reste vide sauf relance par escalade.
4. Approuver la PR de ce workflow (zone `.github/`).
5. Test : issue « modèle Tâche pour un agent » sur `apps/echo-demo` (modification triviale), lancée par dispatch. Vérifier : branche
   `claude/*`, PR ouverte, `ci-ok` lancé sur la PR (le jeton de l'App déclenche la CI ; un GITHUB_TOKEN standard ne le ferait pas).

## Identité de l'exécutant (T-304, prouvée le 2026-11-18)
- GitHub App d'organisation (secrets `APP_ID` et `APP_PRIVATE_KEY`, permissions Contents, Pull requests, Issues, Workflows en écriture) : un jeton
  d'installation est généré à chaque run (`actions/create-github-app-token`) et passé à `claude-code-action` (`github_token`). L'App officielle
  Claude n'a que la lecture des workflows ; un jeton fin personnel ne peut pas écrire dans le dépôt d'une organisation. Repli : `FACTORY_GH_TOKEN`.
- `actions/checkout` du job de l'agent : `persist-credentials: false` (sinon le `GITHUB_TOKEN` persisté prime et le push d'un fichier de workflow
  est refusé ; issue amont anthropics/claude-code-action#1510).
- Jamais l'App dans `bypass_actors`. Entrée du registre : `docs/state/identities.yaml`. Remplacée ou réduite à FINAL0 (T-215).
- Diagnostic : `-f debug=true` (journaux complets, dépôt public : issue sans donnée sensible seulement) ; `mission-result` liste les outils refusés.

## Exécutant minimal (T-313)
- Entrées : `tickets` (20 au plus), `model`, `effort`, `escalated_from`. Passées à `claude_args` (`--model`, `--effort`, `--max-turns`).
- Plafonds (`tools/factory/run-ticket.sh limits`, T-466) : Opus 90 min et 200 tours ; Sonnet et Haiku 45 min et 100 tours ; `effort: max` refusé hors Opus. Le plafond de tours n'est pas une coupure fiable : l'action compare `num_turns` à `--max-turns` après la session (run 44313706955 : 79 tours pour 60, session réussie, PR fusionnée, étape en échec). La vraie coupure est `timeout-minutes`.
- Concurrence : `max-parallel: 3` (matrice) et un groupe par issue ; kill-switch `factory/PAUSE` (T-311).
- Identité : `noreply@anthropic.com` ; trailers `Ticket`, `Model`, `Effort`, `Claude-Session` (+ `Escalated-from`). L'étape `check-trailers` tourne même si l'étape de l'agent échoue (`always()`) et reste le juge final.
- Trailers injectés (T-474, run 44326043746 : PR #77 sans aucun trailer malgré le prompt). Avant l'agent, l'étape `hooks` installe `tools/factory/commit-trailers.sh` comme hooks `prepare-commit-msg` et `commit-msg` dans `$RUNNER_TEMP/factory-git-hooks` (hors du dépôt, propriété de root, sans écriture), avec les valeurs du workflow : `Ticket` (`run-ticket.sh ticket-env`), `Model`, `Effort`, `Escalated-from` (si non vide), `Claude-Session` (URL du run). `core.hooksPath` est posé dans `.git/config` et par `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0`/`GIT_CONFIG_VALUE_0` dans `$GITHUB_ENV` (l'environnement prime sur les fichiers de configuration). Le hook ajoute les trailers absents, remplace une valeur fausse ou en double par celle du workflow (ordre canonique en fin de message) et refuse un auteur ou un committer autre que `noreply@anthropic.com`. Variable absente ou invalide : installation en échec, agent non lancé. Issue sans ticket : même échec (sans `Ticket`, `check-trailers` refuserait de toute façon). `GIT_AUTHOR_*` et `GIT_COMMITTER_*` sont dans l'`env` du job.
- Risque résiduel du hook : `prepare-commit-msg` n'est pas supprimé par `--no-verify` (githooks(5)) ; `--no-verify` et `-n` sont aussi refusés par `.claude/hooks/pretool-bash-guard.sh`, mais pas `git -C <dir> commit --no-verify` (sans effet sur `prepare-commit-msg`). L'agent garde `Bash(git:*)` : `git -c core.hooksPath=<autre> commit` (la ligne de commande prime sur l'environnement), `git commit-tree`, `git rebase` ou `git filter-branch` peuvent produire un commit sans hook. Si l'action ne transmet pas l'environnement du job au Bash de l'agent, `git config core.hooksPath` dans `.git/config` redevient modifiable. Dans tous ces cas, `check-trailers` refuse la branche (`trailers_refused`).
- Branche imposée par le prompt : `claude/issue-<n>-<slug>` ; corps de PR avec `Closes #<n>` (la fusion ferme l'issue). Si la sortie `branch_name` de l'action est vide, le workflow lit l'API REST `pulls?state=all` (pas l'index de recherche, en retard de plusieurs secondes) : d'abord `claude/issue-<n>-*`, sinon `claude/*` ou `agent/*` qui cite `#<n>`, branche du dépôt seulement.

### Verdict du job (T-466)
L'étape de l'agent a `continue-on-error: true`. La dernière étape, « Verdict » (`run-ticket.sh verdict`), décide seule du statut du job d'après `mission-result.v1`, qui reçoit `steps.claude.outcome`, `max_turns` et l'issue du contrôle des trailers. Le premier motif qui s'applique décide :

| Motif (`failure`) | Condition | Statut | Job |
|---|---|---|---|
| `model_mismatch` | modèle observé ≠ demandé | FAIL | rouge |
| `turn_cap_exceeded` | session coupée par le CLI (`error_max_turns`) | FAIL | rouge |
| `agent_error` | pas de résultat, `is_error`, ou fichier d'exécution absent | FAIL | rouge |
| `trailers_refused` | `check-trailers` en échec | FAIL | rouge |
| `no_branch` | aucune branche retrouvée | NOT_TESTED | rouge |
| `turn_cap_exceeded` | session réussie au-delà du plafond, branche présente | NOT_TESTED | vert, avertissement |
| `action_error` | étape de l'agent en échec sans autre explication | FAIL | rouge |
| aucun | tout le reste | PASS | vert |

Invariant (testé) : un job rouge ne porte jamais `PASS`, ni dans l'artefact, ni dans le commentaire de PR, ni dans le commentaire d'issue. Le commentaire de PR a `continue-on-error` : c'est un compte rendu, pas le livrable.

### Job `report` (T-466)
`needs: [plan, dev]`, `if: always()`. Il télécharge les artefacts `mission-result-*`, génère un jeton d'App neuf et commente chaque issue de la matrice (`run-ticket.sh report`) : statut corrigé, motif, branche, tours, coût, lien du run. Une issue sans artefact (job expiré, annulé ou interrompu) reçoit `statut FAIL`. L'orchestrateur suit les issues par l'API REST, sans webhook (audit du 2026-11-18, Q6).

### Jeton d'App : 1 h de vie (limite connue)
Un jeton d'installation d'App GitHub expire au bout de 1 h ([docs GitHub](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)). Il est créé au début du job `dev` : après 60 min, `git push`, `gh pr create`, l'auto-merge et le commentaire de PR échouent. Hors Opus, `timeout-minutes` reste ≤ 55 (45 aujourd'hui, testé). Opus garde 90 min : un run de plus de 60 min perd ses écritures GitHub. Le job `report` génère son propre jeton, donc le commentaire d'issue survit. Correctif proposé, non implémenté : T-466, § Notes.

### Outils autorisés de l'agent (T-466)
`Bash(python3:*)` est retiré : il équivalait à un shell libre (`os.environ`, `subprocess`, réseau) et rendait cosmétiques les refus `env` et `printenv`. Préfixes autorisés : `python3 tools/*`, `python3 tests/*` (et leurs formes `-I`), `python3 -m unittest`, `tools/dev/check`, `tests/*`, `bash tests/*`, `gh pr list`, `gh search`. Jamais `python3 -c`, `python3 -` (heredoc), ni `gh api` : la lecture REST est faite par le workflow. `gh pr checks` est retiré : après l'auto-merge, l'agent termine sans attendre la CI. Les hooks (`.claude/hooks/`) et `settings.json` ne changent pas. Risque résiduel : un script écrit par l'agent dans `tools/` ou `tests/` (dans le périmètre du ticket) reste exécutable ; la garde de périmètre et la revue de PR le bornent.
- Sortie : `mission-result.v1` (`docs/schema/mission-result.v1.json`), archivé en artefact ; le résumé du job affiche `total_cost_usd` et `num_turns`. Ni prompt ni sortie d'outil.
- Tests : `tests/factory/run-ticket-test.sh`. Le job `agent-trailers` de `ci.yaml` (dans `needs` de `ci-ok`) exécute `check-trailers origin/main..HEAD` sur les PR de branche `claude/*` ou `agent/*` ou du bot de l'exécutant. Après chaque run, le workflow poste en commentaire de la PR une ligne (statut corrigé et motif, branche, modèle observé, tours, coût, durée, refus de permission) avec le jeton de l'App.

## Garde de recouvrement et disjoncteur de quota (T-467)
État : outils, tests et câblage dans `claude-agent.yml` livrés (STATIC) ; aucun run réel (NOT_TESTED en runtime).
- **Câblage** : le job `plan` lance `ledger.py gate` puis `overlap.py` et publie `limited` et `overlap`. Un lot refusé
  par la garde reçoit un commentaire sur chaque issue (motifs, remède, lien du run), puis `plan` échoue : aucun job `dev`.
  Un disjoncteur ouvert sur `main` : `plan` réussit sans matrice, aucun job `dev`, ni `report` ni `breaker`. Chaque job
  `dev` re-contrôle `origin/main` et les artefacts `factory-limit-*` des jobs frères ; s'il est ouvert, l'agent n'est pas
  lancé et le job échoue (`report` affiche alors FAIL sans mission-result). Après l'agent, `ledger.py detect` lit le
  fichier d'exécution et publie l'artefact `factory-limit-<issue>`. Le job `breaker` ouvre alors une PR
  `claude/factory-limit-<run>-<tentative>` qui ajoute `factory/LIMIT.json` (jeton d'App, auto-merge). Tant que cette
  PR n'est pas fusionnée, un nouveau dispatch n'est pas bloqué.
- **Recouvrement** : `python3 -I tools/factory/overlap.py --tickets "101,102,103"` (issues ou `T-NNN`). Lit le
  `## Périmètre de fichiers` de chaque ticket (rattaché par `github_issue:`) avec l'analyseur du dispatcher
  (`tools/backlog/admission.py`). Code 4 : deux tickets se recoupent, lot refusé. Code 3 : une référence sans ticket ou
  sans périmètre exploitable dans un lot de plus d'un ticket, lot refusé. Fichiers chauds : `.github/workflows/ci.yaml`,
  `.github/CODEOWNERS`, `tools/dev/check`, `tools/dev/ci-map.tsv`, `AGENTS.md` ; `ci.yaml`, `ci-map.tsv` et `check`
  sont couplés par le test de parité (T-460) : toucher l'un compte pour les trois. Remède : lancer l'un après la fusion
  de l'autre. **Règle de finesse** : un dossier racine (`tools/`, `docs/`, `tests/`, `X/**`) accompagné, dans le même
  ticket, d'au moins un chemin plus précis dessous est une ombrelle ignorée ; deux tickets ne se recoupent alors sous
  ce dossier que s'ils déclarent tous deux un même sous-chemin. Un dossier racine seul reste une revendication de tout
  son sous-arbre ; un fichier chaud n'est revendiqué que s'il est déclaré ou couvert par un dossier non raffiné. Le
  JSON liste les ombrelles ignorées (`umbrellas`). Écrire donc des périmètres en chemins précis.
- **Disjoncteur de quota** (abonnement Max : un seul jeton, fenêtre de 5 h commune à tous les jobs) :
  - `ledger.py detect --execution-file <sortie de l'action> --state <LIMIT.json>` ouvre le disjoncteur (code 11) si le
    message final de la session est en erreur (`is_error`) et porte une forme officielle du message de limite
    ([doc « Usage limits »](https://code.claude.com/docs/en/errors) : `You've hit your session limit · resets 3:45pm`,
    `weekly limit · resets Mon 12:00am`, `Opus limit`, `Sonnet limit`). Les throttles (429, 529,
    `Server is temporarily limiting requests`) et le texte d'un agent qui cite le message ne déclenchent rien.
  - `ledger.py gate --state factory/LIMIT.json --model <modèle>` : `limited=true|false` pour le planificateur, code 11
    si le lot ne doit pas partir. Une limite Opus ou Sonnet ne bloque que sa famille de modèles ; toute autre limite
    bloque tout.
  - Reprise : manuelle (T-326). Au reset annoncé (`resume_at`), Paul fusionne une PR qui supprime
    `factory/LIMIT.json` (`ledger.py reset --state factory/LIMIT.json`). Relevé `/usage` : geste de Paul.
- Tests : `tests/factory/overlap-test.sh`, `tests/factory/ledger-test.sh`, `tests/factory/workflow-guard-test.sh`
  (structure du câblage et rejeu des scripts `run:` des étapes de garde avec un `gh` factice ; hors ligne, sans secret).

## Garde-fous
- Déclencheur limité à l'acteur `SmadjaPaul` ; les bots et utilisateurs sans écriture sont refusés par l'action.
- Les issues publiques sont des entrées non fiables : seul le contenu relu par Paul avant le label doit être suivi.
- `.claude/`, `CLAUDE.md` sont restaurés depuis `main` sur les PR par l'action : une PR ne réécrit pas les règles de l'agent.
- `show_full_output` seulement avec `-f debug=true` (journaux publics : essai sans donnée sensible, jamais par défaut). Aucun secret autre que le jeton Claude n'est exposé au job.
- Le job ne peut pas modifier le workflow lui-même sans approbation (CODEOWNERS), ni contourner le ruleset (jeton de l'App,
  sans bypass).
## Limites
- Action en bêta : épinglée par SHA du tag v1 ; relire les changements avant mise à jour.
- Conflits : `lab-apps.yaml` (une entrée par app) est le point chaud : le coordinateur groupe les entrées.
