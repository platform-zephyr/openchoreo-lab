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
- Plafonds (`tools/factory/run-ticket.sh limits`) : Opus 90 min et 150 tours ; Sonnet et Haiku 45 min et 60 tours ; `effort: max` refusé hors Opus.
- Concurrence : `max-parallel: 3` (matrice) et un groupe par issue ; kill-switch `factory/PAUSE` (T-311).
- Identité : `noreply@anthropic.com` ; trailers `Ticket`, `Model`, `Effort`, `Claude-Session` (+ `Escalated-from`) ; l'étape `check-trailers` fait échouer le job sinon.
- Sortie : `mission-result.v1` (`docs/schema/mission-result.v1.json`), archivé en artefact ; le résumé du job affiche `total_cost_usd` et `num_turns`. Ni prompt ni sortie d'outil.
- Tests : `tests/factory/run-ticket-test.sh`. Le job `agent-trailers` de `ci.yaml` (dans `needs` de `ci-ok`) exécute `check-trailers origin/main..HEAD` sur les PR de branche `claude/*` ou `agent/*` ou du bot de l'exécutant. Après chaque run, le workflow poste en commentaire de la PR une ligne (modèle observé, tours, coût, durée, refus de permission) avec le jeton de l'App ; si la sortie `branch_name` est vide, il retrouve la PR `claude/*` ou `agent/*` qui cite l'issue.

## Garde de recouvrement et disjoncteur de quota (T-467)
État : outils et tests livrés (STATIC) ; câblage dans `claude-agent.yml` à faire (section « Câblage à faire » de
`backlog/T-467-*.md`). Tant que ce câblage n'est pas fusionné, rien ne bloque un lot : lancer la garde à la main avant
le dispatch.
- **Recouvrement** : `python3 -I tools/factory/overlap.py --tickets "101,102,103"` (issues ou `T-NNN`). Lit le
  `## Périmètre de fichiers` de chaque ticket (rattaché par `github_issue:`) avec l'analyseur du dispatcher
  (`tools/backlog/admission.py`). Code 4 : deux tickets se recoupent, lot refusé. Code 3 : une référence sans ticket ou
  sans périmètre exploitable dans un lot de plus d'un ticket, lot refusé. Fichiers chauds : `.github/workflows/ci.yaml`,
  `.github/CODEOWNERS`, `tools/dev/check`, `tools/dev/ci-map.tsv`, `AGENTS.md` ; `ci.yaml`, `ci-map.tsv` et `check`
  sont couplés par le test de parité (T-460) : toucher l'un compte pour les trois. Remède : lancer l'un après la fusion
  de l'autre.
- **Disjoncteur de quota** (abonnement Max : un seul jeton, fenêtre de 5 h commune à tous les jobs) :
  - `ledger.py detect --execution-file <sortie de l'action> --state <LIMIT.json>` ouvre le disjoncteur (code 11) si le
    message final de la session est en erreur (`is_error`) et porte une forme officielle du message de limite
    ([doc « Usage limits »](https://code.claude.com/docs/en/errors) : `You've hit your session limit · resets 3:45pm`,
    `weekly limit · resets Mon 12:00am`, `Opus limit`, `Sonnet limit`). Les throttles (429, 529,
    `Server is temporarily limiting requests`) et le texte d'un agent qui cite le message ne déclenchent rien.
  - `ledger.py gate --state factory/LIMIT.json --model <modèle>` : `limited=true|false` pour le planificateur, code 11
    si le lot ne doit pas partir. Une limite Opus ou Sonnet ne bloque que sa famille de modèles ; toute autre limite
    bloque tout.
  - Une fois câblé : `plan` n'émet pas de matrice si `factory/LIMIT.json` est sur `main` ; chaque job `dev` re-contrôle `main`
    et les artefacts `factory-limit-*` des jobs frères du même run avant de lancer l'agent.
  - Reprise : manuelle (T-326). Au reset annoncé (`resume_at`), Paul fusionne une PR qui supprime
    `factory/LIMIT.json` (`ledger.py reset --state factory/LIMIT.json`). Relevé `/usage` : geste de Paul.
- Tests : `tests/factory/overlap-test.sh`, `tests/factory/ledger-test.sh` (hors ligne, sans secret).

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
