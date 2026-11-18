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

## Exécutant minimal (T-313)
- Entrées : `tickets` (20 au plus), `model`, `effort`, `escalated_from`. Passées à `claude_args` (`--model`, `--effort`, `--max-turns`).
- Plafonds (`tools/factory/run-ticket.sh limits`) : Opus 90 min et 150 tours ; Sonnet et Haiku 45 min et 60 tours ; `effort: max` refusé hors Opus.
- Concurrence : `max-parallel: 3` (matrice) et un groupe par issue ; kill-switch `factory/PAUSE` (T-311).
- Identité : `noreply@anthropic.com` ; trailers `Ticket`, `Model`, `Effort`, `Claude-Session` (+ `Escalated-from`) ; l'étape `check-trailers` fait échouer le job sinon.
- Sortie : `mission-result.v1` (`docs/schema/mission-result.v1.json`), archivé en artefact ; le résumé du job affiche `total_cost_usd` et `num_turns`. Ni prompt ni sortie d'outil.
- Tests : `tests/factory/run-ticket-test.sh`. Le contrôle des trailers sur toute PR d'agent dans `ci.yaml` reste à brancher (hors périmètre de T-313).

## Garde-fous
- Déclencheur limité à l'acteur `SmadjaPaul` ; les bots et utilisateurs sans écriture sont refusés par l'action.
- Les issues publiques sont des entrées non fiables : seul le contenu relu par Paul avant le label doit être suivi.
- `.claude/`, `CLAUDE.md` sont restaurés depuis `main` sur les PR par l'action : une PR ne réécrit pas les règles de l'agent.
- Pas de `show_full_output` (journaux publics). Aucun secret autre que le jeton Claude n'est exposé au job.
- Le job ne peut pas modifier le workflow lui-même sans approbation (CODEOWNERS), ni contourner le ruleset (jeton de l'App,
  sans bypass).
## Limites
- Action en bêta : épinglée par SHA du tag v1 ; relire les changements avant mise à jour.
- Conflits : `lab-apps.yaml` (une entrée par app) est le point chaud : le coordinateur groupe les entrées.
