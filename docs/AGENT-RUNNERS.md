# Agents sur runners GitHub (claude-code-action)

Principe : issue + label `agent:dev` (posé par Paul) -> job GitHub (ubuntu-24.04-arm) -> branche `claude/*` -> PR -> `ci-ok`
-> file de fusion -> Argo CD déploie. L'agent n'a aucun accès OKE ; la preuve runtime reste au coordinateur
(tests/golden-path-*, tests/idp-demo). Frontière de privilèges : docs/AGENT-PR-MODEL.md (CODEOWNERS + ruleset).

## Mise en route (Paul, une fois)
1. Dans le dépôt : `claude` puis `/install-github-app` (admin du dépôt ; choisir CE dépôt seulement). Ne garde pas le workflow
   qu'il propose : celui de `.github/workflows/claude-agent.yml` fait foi.
2. Jeton : `claude setup-token`, puis `gh secret set CLAUDE_CODE_OAUTH_TOKEN` (abonnement Max : quotas partagés avec tes
   sessions, 4 jobs max en parallèle au départ). Pour dépasser 4 : clé API Console avec plafond de dépense, remplacer
   `claude_code_oauth_token` par `anthropic_api_key` (une ligne).
3. Créer le label `agent:dev` : `gh label create agent:dev --color 1d76db`.
4. Approuver la PR de ce workflow (zone `.github/`).
5. Test : issue « modèle Tâche pour un agent » sur `apps/echo-demo` (modification triviale), label `agent:dev`. Vérifier : branche
   `claude/*`, PR ouverte, `ci-ok` lancé sur la PR (le jeton de l'App déclenche la CI ; un GITHUB_TOKEN standard ne le ferait pas).

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
