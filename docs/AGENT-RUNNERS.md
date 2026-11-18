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
- Identité : `noreply@anthropic.com` ; trailers `Ticket`, `Model`, `Effort`, `Claude-Session` (+ `Escalated-from`). Le prompt donne la valeur de `Claude-Session` : l'URL du run (`<server>/<dépôt>/actions/runs/<run_id>`) ; l'agent ne la cherche plus dans l'environnement. L'étape `check-trailers` tourne même si l'étape de l'agent échoue (`always()`).
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
