# Usine d'agents 24/7 : moyens, limites, architecture, débit

Statut : recherche (docs seulement, rien d'exécuté). Date : 2026-11-18. Auteur : sous-agent de recherche pour le coordinateur.
Niveaux de preuve : [L] lu dans une source primaire le 2026-11-18 ; [D] déduit ; [H] hypothèse non mesurée ; [NP] non prouvé.
Aucun secret ni valeur de jeton dans ce fichier (dépôt public).

## 0. Conclusion

1. Le goulot n'est pas le nombre de jobs : c'est le **quota d'abonnement partagé** (fenêtre de 5 h + plafond hebdomadaire) puis la **latence humaine** (28 tickets actifs sur 88 portent un MANDAT, 31 une REVUE ; S0 : 0 ticket autonome pur). Plus d'agents ne servent à rien si le quota ou les gestes de Paul bloquent.
2. Sur Max, trois chemins de calcul consomment le même quota : sessions cloud (y compris Projects et tâches planifiées), `claude-code-action` (jeton `claude setup-token`), `claude -p` sur le homelab. Les **environnements auto-hébergés officiels sont réservés à Team/Enterprise** : pas pour Max [L].
3. Le homelab (8845HS, 64 Go) sert à : travailleur `claude -p` en tirage sortant (k3d, tâches longues), pool Remote Control (`--capacity`, `--spawn worktree`). Pas de runner GitHub sur ce dépôt public : GitHub le déconseille et les minutes hébergées y sont gratuites [S16]. Il ne multiplie pas le quota.
4. Recommandation : dispatcher **déterministe en code** (pas un LLM), exécutants multiples, coordinateur humain-LLM seulement pour décider, **mandats de lot** signés une fois par étape, **merge armé à l'avance** (auto-merge sous conditions), ntfy uniquement sur `needs-paul` ou blocage > seuil, un **résumé quotidien** unique.
5. Plafond de parallélisme à viser : 6 agents au pilote, 8 à 10 si la mesure de quota le permet. Au-delà, le graphe des dépendances et les couloirs de fichiers limitent plus que les slots [D].
6. MVP (S0-S3, 29 tickets) : **5 à 7 jours** calendaires, dont 3 jours imposés par la porte ADR-0020, quel que soit N ≥ 4 [H]. Incréments I1-I8 (57 tickets) : 1 à 2 semaines de plus si le quota tient [H].
7. Premier acte : mesurer. Un pilote de 24 h à N=3 produit le coût réel par ticket (`total_cost_usd`, tours, durée) et le pourcentage de quota consommé ; tout le reste (N, modèle par ticket, plan Max ou Ultra) se règle sur cette mesure.
8. Risque n°1 : sessions cloud et tâches planifiées agissent avec l'identité GitHub de Paul [L] ; cela contredit T-215 (aucun agent avec le compte admin). Les agents ne mergent donc jamais depuis ce chemin ; le merge passe par une GitHub App.
9. Risque n°2 : dépôt public + exécution de code tiers. Aucun runner auto-hébergé enregistré (GitHub : « almost never » pour un dépôt public) ; travailleur homelab en tirage sortant, sans secret ni kubeconfig.
10. Rien n'est promis en euros par agent : l'abonnement n'expose pas de facture par token (T-145).

## 1. Sources primaires lues (2026-11-18)

| Id | Source | Sert à |
|---|---|---|
| S1 | https://code.claude.com/docs/en/claude-code-on-the-web | sessions cloud, `--cloud`, parallélisme, auto-fix, limites |
| S2 | https://code.claude.com/docs/en/routines | tâches planifiées : déclencheurs, plafonds horaires, mode auto |
| S3 | https://code.claude.com/docs/en/github-actions | claude-code-action, jeton Max, coûts |
| S4 | https://raw.githubusercontent.com/anthropics/claude-code-action/main/docs/security.md | modèle de sécurité de l'action |
| S5 | https://code.claude.com/docs/en/authentication | `setup-token`, précédence des identifiants |
| S6 | https://code.claude.com/docs/en/headless | `claude -p`, `--output-format json`, `--bare`, permissions |
| S7 | https://code.claude.com/docs/en/permission-modes | auto, dontAsk, bypassPermissions |
| S8 | https://code.claude.com/docs/en/claude-projects | Projects : coordinateur, threads, pause, 500 threads/jour |
| S9 | https://code.claude.com/docs/en/agents | comparatif du parallélisme (subagents, agent view, teams, projects) |
| S10 | https://code.claude.com/docs/en/self-hosted-environments | runners officiels : Team/Enterprise seulement |
| S11 | https://code.claude.com/docs/en/remote-control | pool local : `--capacity`, `--spawn worktree` |
| S12 | https://code.claude.com/docs/en/cloud-environments | VM 4 vCPU/16 Go/30 Go, setup script, secrets réseau |
| S13 | https://code.claude.com/docs/en/costs | `/usage`, parallélisme et coût, reprise après limite |
| S14 | https://code.claude.com/docs/en/agent-sdk/overview | SDK : clé API, pas de login claude.ai pour des tiers |
| S15 | https://claude.com/pricing et https://support.claude.com/en/articles/11014257 (404 ce jour), /11049741, /11145838 | plans et fenêtres |
| S16 | https://docs.github.com/en/actions/reference/limits, .../usage-limits-billing-and-administration, .../security/secure-use, pages « automatically merging a pull request » (lues via curl) | concurrence, durée de job, gratuité, runners auto-hébergés, auto-merge |
| S17 | `docs/AGENT-IDENTITY.md` du dépôt (limites GitHub déjà vérifiées par un autre agent) | App, rulesets, quota d'App |

## 2. Q1. Moyens de faire tourner Claude en continu

| Moyen | Ce que c'est (source) | Avantages | Limites | Coût |
|---|---|---|---|---|
| Sessions cloud (`claude --cloud`, web, mobile) | VM Anthropic Ubuntu x86_64, 4 vCPU/16 Go/30 Go [S12] ; un `--cloud` = une session indépendante, parallèles [S1] | aucune infra ; continue laptop fermé ; push via proxy GitHub ; secrets réseau injectés sans exposition | VM en pause après quelques minutes d'inactivité, récupérée ensuite [S1][S12] ; commandes 2 min par défaut, 10 min max ; limites partagées avec tout l'usage du compte [S1] ; pas de plafond de sessions publié pour Max [NP] | quota d'abonnement, pas de facture VM [S1] |
| Projects (coordinateur Claude) | une conversation lance des threads cloud en parallèle ; Pause globale ; reprise auto après limite ; 500 nouveaux threads/jour [S8] | « combien de threads » à la demande ; vue « Waiting on you » ; auto-fix des PR | bêta publique, déploiement progressif ; limite de threads = préférence, pas plafond ; règles `.claude/settings.json` non appliquées [S8] | quota (« plus vite qu'une session ») |
| Tâches planifiées (routines) | cloud, déclencheurs : horaire, API (`/fire`, jeton), événement GitHub [S2] | sans machine ; réveil par API depuis le homelab ; mode auto | aperçu de recherche ; ≥ 1 h entre exécutions ; 100 exécutions planifiées/h/compte ; 30/h par tâche (Run now + API) et 100/h/compte pour l'API ; plafonds horaires sur événements GitHub, sans dépassement payant [S2] ; commits sous l'identité de Paul [S2] | quota ; au-delà, rejet sauf crédits d'usage |
| claude-code-action (runner hébergé) | action GitHub ; secret `CLAUDE_CODE_OAUTH_TOKEN` pour Max [S3] | déjà en place (`claude-agent.yml`) ; une PR par job ; `--max-turns`, timeout, concurrence | minutes Actions en plus du quota [S3], gratuites pour les runners hébergés standard d'un dépôt public [S16] ; commits du `GITHUB_TOKEN` ne déclenchent pas la CI [S3] ; bots refusés par défaut, écriture requise [S4] ; journaux publics | quota seulement (minutes gratuites en dépôt public [S16]) |
| Même action sur runner auto-hébergé (homelab) | runner GitHub classique, hors « environnement auto-hébergé » Claude | k3d local ; réseau homelab ; durée libre | GitHub : un runner auto-hébergé « ne devrait presque jamais être utilisé pour un dépôt public », car tout PR peut le compromettre [S16] ; et les minutes hébergées sont déjà gratuites : **gain faible, risque élevé. Écarté tant que le dépôt est public** | électricité ; mêmes quotas Claude |
| `claude -p` en boucle sur le homelab | CLI non interactive, `--max-turns`, `--max-budget-usd`, JSON `total_cost_usd`, `--resume` [S6] | contrôle total, ledger par tentative, reprise | depuis 2.1.302 démarre en mode Manuel : passer `--permission-mode auto` ou `dontAsk` + `--allowedTools` [S6][S7] ; `--bare` ne lit pas le jeton OAuth [S5][S6] ; il faut la supervision du processus | quota |
| Pool Remote Control (homelab) | `claude remote-control --capacity N --spawn worktree` (défaut 32) [S11] | sessions locales pilotables du téléphone ; accès aux ressources du homelab | demande un `/login` interactif (le jeton `setup-token` ne peut pas ouvrir de session RC [S5]) ; une session survivant à l'expiration du login se déconnecte [S5] ; API key non prise en charge [S11] | quota |
| Agent SDK headless | bibliothèque Python/TS [S14] | orchestration programmable | la page demande une clé API ; les tiers n'ont pas le login claude.ai [S14] ; usage personnel sur abonnement : [NP] | facturé à l'API (plafond Console) |
| Auto-hébergé officiel | runners Anthropic-orchestrés [S10] | n/a | **Team/Enterprise seulement** [S10] | n/a |

Écarté pour la voie principale : Agent SDK sur abonnement (zone grise [NP]) ; environnements auto-hébergés (plan). Gardé pour dépasser le quota seulement si Paul le décide : clé API Console avec plafond de dépense (`anthropic_api_key`), 1 ligne dans le workflow (`docs/AGENT-RUNNERS.md`).

## 3. Q2. Limites réelles du plan Max et mesure

Faits [L, S15] : Max = 100 $/mois, « 5x Pro every 5 hours and every week », plafond hebdomadaire commun à tous les modèles et plafond hebdomadaire séparé pour « Fable » ; reset hebdomadaire fixe par compte ; « no guaranteed uninterrupted service ». Ultra = 200 $/mois, « 10x Pro weekly », **pas de limite de 5 h pour un compte vérifié**. Claude et Claude Code partagent les mêmes limites. La page tarifaire du jour ne montre qu'un palier Max (le « 20x » cité dans le brief n'y figure pas : à reconfirmer dans l'abonnement de Paul).
Conséquence [D] : pour du 24/7, la fenêtre de 5 h casse la continuité (arrêt puis reprise) ; Ultra supprime cette fenêtre mais ne double que le plafond hebdomadaire. Le débit soutenu est donc fixé par le **plafond hebdomadaire**, qu'aucune source ne chiffre en tokens [NP].
Sessions parallèles : aucun nombre publié pour le compte Max. Seuls chiffres lus : Projects 500 threads/jour [S8] ; routines 100/h et 30/h [S2] ; `--capacity` 32 [S11] ; message « organisation à sa limite de sessions cloud simultanées » [S2] (valeur inconnue). Les agents multiplient la consommation à proportion [S1][S9] ; une équipe d'agents ≈ 7× en mode plan [S13].

Mesurer (sans promettre) :
- Aval : `/usage` (barres de plan + attribution par skill/subagent/MCP), `claude.ai/settings/usage`, `/status` [S13][S15]. `/usage` est local à la machine [S13].
- Par tentative : `claude -p --output-format json` donne `total_cost_usd`, `num_turns`, `duration_ms` ; **estimation côté client**, pas la facture [S6]. Le gouverneur somme ces valeurs par fenêtre de 5 h et par semaine (ledger), comme proxy.
- Réaction aux refus : messages « session limit », « weekly limit », « Opus limit » (changer de famille de modèle permet de continuer après la limite d'un modèle seul) [S13] ; `CLAUDE_CODE_RETRY_WATCHDOG` et `autoContinueAtUsageLimit` gèrent l'attente [S13]. Le disjoncteur du dispatcher arrête les lancements à la première limite et reprend au reset annoncé.
- Aucune API officielle du solde d'abonnement lue : [NP]. Ne pas bâtir de décision sur un scraping de claude.ai.

Dépasser 4 jobs : (a) concurrence GitHub : 20 jobs standard simultanés en plan Free, 40 Pro, 60 Team, 500 Enterprise, file d'attente au-delà, hausse sur ticket de support ; un job dure 6 h au plus [S16] ; l'action actuelle limite 1 job par issue, pas globalement ; (b) plusieurs sessions cloud / Projects ; (c) travailleur homelab « pull » (`claude -p`, sans runner GitHub) ; (d) pool Remote Control. Le plafond « 4 » de `docs/AGENT-RUNNERS.md` est une prudence de quota, pas une limite technique.

## 4. Q3. Réduire les interventions de Paul

Constat [L repo] : 28 des 88 tickets actifs portent un MANDAT et 31 une REVUE ; S0 compte 7 REVUE et 2 MANDAT, aucun ticket autonome pur. Le temps de réponse de Paul est le chemin critique (CONSENSUS §Constat 2).

1. **Mandat de lot** : un fichier signé par Paul (PR approuvée, chemin du noyau `missions/mandates/<étape>.yaml`) liste, par étape : tickets couverts, chemins autorisés, plafond de diff, plafond de dépense, date d'expiration, conditions (CI verte, revue indépendante PASS). Il pré-approuve le **merge** de PR REVUE conformes et **jamais** : un secret, un accès, une dépense hors free tier, un apply, une classe INTERDIT, un fichier hors liste (platform-guardrails §1-2). La classe reste recalculée depuis les chemins (T-210).
2. **Gestes MANDAT en une séance par étape** : un assistant (`tools/factory/gestes.sh`, généré depuis les tickets `MANDAT` de l'étape) imprime la liste ordonnée des gestes exacts (noms, jamais de valeurs) et vérifie chaque effet en lecture. Cible : ≤ 30 min par étape, 14 étapes (S0-S3, PORTE, I1-I8).
3. **Merge armé** : l'agent ouvre la PR et exécute `gh pr merge --auto --squash` (GitHub tient le merge jusqu'à `ci-ok` et aux revues requises). Pour le noyau (CODEOWNERS), l'approbation de Paul sur le téléphone (application GitHub) suffit à déclencher le merge : un tap, sans retour dans le terminal. L'auto-merge existe en dépôt public Free ; il doit être activé dans le dépôt [S16].
4. **Auto-merge sous conditions** (App de merge, jamais le compte de Paul) : auteur `claude/*` via l'App ; tous les chemins hors noyau ; classe AUTONOME recalculée ; `ci-ok` vert ; revue indépendante PASS ; diff ≤ seuil ; pas d'autre PR ouverte sur la même (app, env) (CONSENSUS #10) ; pas de `PAUSE`. Sinon : label `needs-paul`.
5. **Files d'attente** : dispatcher à file par couloir ; file de merge sérialisée pour les points chauds (`lab-apps.yaml`) ; rebase automatique par l'App (l'auto-fix cloud ne voit pas les conflits [S1]).
6. **ntfy seulement si nécessaire** : (i) `needs-paul` posé, (ii) usine en pause (budget, boucle, kill-switch), (iii) ticket `blocked` > 6 h, (iv) incident runtime. Tout le reste va dans **un seul résumé quotidien** (issue « Usine : résumé » commentée une fois par jour par la tâche planifiée du trieur) : fusionnées, en cours, bloquées, % de quota, gestes attendus, prochain lot.
7. **Reprise automatique** : tentative échouée → 1 reprise sur une branche neuve avec le journal d'échec (max_attempts 2, contrat Atlas) ; limite de quota → pause + reprise au reset ; runner perdu → bail expiré après 3 h sans commentaire (coordination Atlas) ; deux échecs → `blocked` avec cause et demande précise ; jamais de 3e tentative sans humain.
8. **Mobile** : Projects affiche « Waiting on you » ; les approbations d'outil se donnent dans le thread [S8] ; les notifications du bureau couvrent erreurs et demandes d'entrée [S8]. Les threads cloud ignorent les règles de permission du dépôt [S8] : les garde-fous restent dans GitHub (ruleset, CODEOWNERS), pas dans `.claude/`.

## 5. Q4. Architecture recommandée « usine 24/7 »

```
backlog/*.md ──► [Trieur quotidien: tâche planifiée cloud]  ──► issue « Usine : résumé » + ntfy si blocage
                          │ (lecture seule, regénère ROADMAP, détecte tickets bloqués)
                          ▼
        [Dispatcher: workflow factory-dispatch, cron 15 min + sur merge + manuel]   ◄── factory/config.yaml (noyau), PAUSE
          next.py (prêts, classe recalculée) → admission (couloir, ressources exclusives, chevauchement de chemins,
          budget, disjoncteur) → workflow_dispatch(ticket, modèle, étape)
                          ▼
   ┌─────────────── Exécutants (une session neuve par ticket, un ticket = une branche = une PR) ───────────────┐
   │ E1 claude-code-action runner hébergé (45 min) │ E2 travailleur homelab claude -p (k3d, tâches longues)   │
   │ E3 session cloud / Projects (travail ouvert, revue) │ E4 pool Remote Control homelab (ressources locales)  │
   └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                          ▼ PR + mission-result.v1 (Atlas) + journal JSON (tours, durée, coût estimé)
        [Revue indépendante: autre modèle/session, lecture seule] ─► [App de merge: conditions §4.4] ─► Argo CD
                          ▼
        [Preuve runtime T-005] ─► fiche d'incident / revert (un seul propriétaire : T-106)
```

Rôles :
- **Trieur** : tâche planifiée cloud (1 run/jour, loin des plafonds [S2]). Lecture seule, produit le résumé. Ne lance rien.
- **Dispatcher (T-210 réécrit)** : code, pas un LLM. Stateless : relit backlog, PR et runs à chaque tick (Atlas « Avant toute action »). Étape S0 : manuel avec liste d'ID ; S1 : cron. Un label posé par `GITHUB_TOKEN` ne déclenche pas de workflow [S3] : on lance par `workflow_dispatch` avec le jeton de l'App.
- **Exécutants** : même consigne, outils par voie (headless-profile Atlas : cloud = fichiers, git, `gh api`, `just` ; pas de kubectl). Jeton `setup-token` d'un an, modèle seul [S5] ; voie `-p` : `--permission-mode auto --permission-prompts none`, `--max-turns`, `--max-budget-usd` [S6][S7] ; si bypass requis : conteneur non root seulement [S7]. Modèle par ticket (champ `model`) : `haiku` scripts/docs, `sonnet` défaut, `opus` noyau/sécurité/conception ; le classifieur d'auto utilise Sonnet par défaut [S7].
- **Coordinateur** : Projects ou session de Paul. Il aide à décider et consigne la décision (Atlas) ; il ne dispatche pas. Seul rôle autorisé sur OKE (DEV-FACTORY).
- **Garde-fous** : budget (ledger 5 h/semaine, seuils 70 % ralentir, 85 % arrêter AUTONOME, 100 % pause ; réserve 15 % pour Paul) ; boucles (max_attempts 2, pas de seconde PR d'agent sur la même (app, env), pas de bot déclenchant un bot : `allowed_bots` vide [S3][S4]) ; conflits (couloirs, 1 agent sur `contrat-appgen` avant T-214, `exclusive_resources`, vérification des chemins ouverts) ; kill-switch `factory/PAUSE` (noyau) + Pause de projet [S8] ; PR du noyau jamais fusionnables sans Paul (CODEOWNERS) ; `show_full_output` désactivé (journaux publics) [S3][S4].
- **Observabilité** : par tentative, un `mission-result.v1` et une ligne de journal ; agrégat quotidien. Indicateurs : tickets fusionnés/jour, délai ticket→merge, taux de succès 1re tentative, taux de revert, nombre de gestes humains/jour, % quota 5 h et hebdomadaire, temps d'inactivité des slots, rebasages. Sortie : résumé quotidien ; plus tard, métriques sur le homelab (ADR-0019).
- **Homelab** : VM dédiée Proxmox (≈ 8 vCPU, 32 Go, VLAN isolé, sans kubeconfig, sans identifiants) ; un travailleur interroge GitHub en sortant (ticket affecté, `claude -p` dans un worktree, conteneur détruit après), donc aucun code de PR de fork ne s'y exécute. Un job ≈ 1 à 2 Go hors k3d ; k3d ≈ 4 Go [H] : 6 à 8 jobs simultanés dans 64 Go. Un runner Actions ne s'y enregistre que si le dépôt devient privé.

## 6. Q5. Débit et calendrier

Hypothèses [H], à remplacer par la mesure du jour 2 :
H1 durée d'une tentative d'agent 40 min ; H2 CI + merge 20 min ; H3 1,35 tentative par ticket ; H4 marge de file et de rebase +30 % → cycle ≈ 1,75 h par ticket et par slot, soit 13,7 tickets/jour/slot en théorie ; H5 facteur d'efficacité 0,25 (graphe, couloirs, gestes, pauses de quota). Stock actif : MVP 29 (S0 9, S1 4, S2 6, S3 10) ; porte 1 ; I1-I8 57 ; MANDAT dans I1-I8 : 20.

| N agents | Plafond théorique (t/j) | Réaliste (t/j) | MVP S0-S3 | I1-I8 (57) | Remarque |
|---|---|---|---|---|---|
| 3 (pilote) | 41 | ≈ 10 | 5-7 j | 12-14 j | mesure du coût par ticket |
| 4 | 55 | ≈ 14 | 5-7 j | 9-11 j | état actuel prévu (T-210) |
| 6 | 82 | ≈ 20 | 5-6 j | 7-9 j | cible pilote étendu |
| 8-10 | 110-137 | ≈ 20-25 (plafond du graphe) | 5-6 j | 6-8 j | gain faible, quota critique |

Lecture : le **MVP ne descend pas sous 5 jours** : chemin critique d'environ 8 vagues × 1,75 h ≈ 14 h de travail, plus les 3 jours de preuve de la porte (ADR-0020), plus les gestes de Paul d'ouverture (T-061, T-215, T-001, T-002 en une séance de ≈ 45 min) [H]. Les incréments profitent davantage de N (couloirs larges) mais butent sur 20 gestes MANDAT et sur le quota. **Si le quota hebdomadaire limite à 50 % du débit réaliste, les durées doublent** ; la décision Max → Ultra se prend quand la consommation hebdomadaire dépasse 70 % au jour 3 (Ultra : plafond hebdomadaire 2× et plus de fenêtre de 5 h pour un compte vérifié [S15]).
Ordre conseillé : jour 0 gestes de S0 ; jours 1-2 pilote N=3 en dispatch manuel ; jour 3 cron + auto-merge conditionnel ; jours 4-6 N=6 ; I1 dès que S3 est PASS (T-210 « une ou deux étapes ouvertes à la fois »).

## 7. Non prouvé et à tester en premier

| Point | Test |
|---|---|
| Quota hebdomadaire réel (tokens) | pilote 24 h : % consommé vs `total_cost_usd` cumulé |
| Concurrence cloud maximale pour Max | lancer 6, 10, 15 sessions ; observer « limite de sessions simultanées » |
| Identité de commit/PR des sessions cloud (Paul vs App) | une session cloud ouvre une PR du noyau : doit rester non fusionnable (T-215 essai) |
| Auto-merge dans le ruleset actuel (0 approbation, Code owners) | disponible en dépôt public Free [S16] ; réglage « Allow auto-merge » à activer ; PR de test AUTONOME et noyau |
| Usage de `claude -p` avec `CLAUDE_CODE_OAUTH_TOKEN` sur le travailleur homelab | une exécution datée ; vérifier `/status` (méthode de login) |
| SDK sur abonnement | ne pas l'utiliser avant confirmation Anthropic [S14] |

## 8. Gestes uniques de Paul (résumé ; détail dans `backlog/proposals/factory.yaml`)

1. Confirmer le plan (Max pilote ; seuil de passage à Ultra) et fixer la dépense maximale de crédits d'usage (0 par défaut).
2. T-215 étendu : GitHub App (Contents RW, Pull requests RW, Actions RW pour `workflow_dispatch`, Metadata R) sur ce dépôt seul ; option « Allow auto-merge » ; ruleset inchangé (`ci-ok`, Code owners).
3. `claude setup-token` puis `gh secret set CLAUDE_CODE_OAUTH_TOKEN` (déjà documenté) ; jeton d'API de routine (`/fire`) créé sur le web, rangé en secret du dépôt.
4. Installer l'application GitHub de Claude sur le dépôt ; activer Projects si la bêta est ouverte ; créer l'environnement cloud « lab-agents » (accès réseau limité, secrets réseau).
5. Homelab : VM `agents-01`, VLAN isolé, `claude setup-token` pour le travailleur, un `/login` interactif pour le pool Remote Control (renouvelable avant expiration).
6. ntfy : un sujet privé, jeton en secret du dépôt, abonnement sur le téléphone ; notifications de l'application GitHub activées.
7. Signer le mandat de lot de chaque étape (PR approuvée sur mobile) et dérouler la liste de gestes de l'étape.

## 9. Proposition d'ADR

# ADR-0021 — Usine d'agents 24/7 et minimisation des interventions
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0012, ADR-0013, ADR-0017, ADR-0020, D-2026-11-15-03 (homelab-infra), contrat de mission Atlas

## Contexte
Objectif : finir vite en heures réelles, avec peu de gestes humains. Mesures lues : 28 tickets actifs sur 88 portent un MANDAT et 31 une REVUE ; l'abonnement impose une fenêtre de 5 h et un plafond hebdomadaire partagés par tous les chemins de calcul ; les sessions cloud et les tâches planifiées agissent avec l'identité GitHub de leur propriétaire ; les environnements auto-hébergés officiels exigent Team/Enterprise. T-210 (dispatcher manuel, plafond 4) et T-145 (plafond LLM) existent sans gouverneur de quota ni mandat de lot.

## Décision
1. Le **quota d'abonnement est la ressource gérée** : un gouverneur de budget (ledger par fenêtre de 5 h et par semaine, seuils 70/85/100 %, réserve de 15 % pour Paul) borne le lancement des agents ; un disjoncteur arrête les lancements à la première limite et reprend au reset.
2. Le **dispatcher est du code déterministe** (T-210 réécrit) : prêts → admission (couloir, ressources exclusives, chevauchement de chemins, budget) → un exécutant par ticket ; classe recalculée depuis les chemins ; `max_attempts` 2 ; une seule PR d'agent par (app, env).
3. Plusieurs **exécutants interchangeables** (runner hébergé, travailleur homelab `claude -p` en tirage sortant, sessions cloud, pool Remote Control) partagent le même contrat de mission et le même ledger. Le homelab n'enregistre aucun runner sur ce dépôt public (GitHub le déconseille), n'héberge aucun secret et n'accepte aucune connexion entrante.
4. **Aucun agent ne merge avec l'identité de Paul.** Le merge passe par une GitHub App sous conditions écrites : chemins hors noyau, classe AUTONOME, `ci-ok`, revue indépendante PASS, diff plafonné, pas de pause. Le noyau (CODEOWNERS) exige l'approbation de Paul, pré-armée par auto-merge.
5. Un **mandat de lot** par étape, signé par PR dans le noyau, pré-approuve le merge de PR REVUE conformes à sa liste ; il n'ouvre jamais un secret, un accès, une dépense hors free tier, un apply, ni une action INTERDIT. Il expire.
6. **Notifications** : ntfy seulement pour `needs-paul`, pause de l'usine, ticket bloqué > 6 h, incident runtime ; sinon un résumé quotidien unique.
7. Le **coordinateur** décide, il ne dispatche pas ; un kill-switch `factory/PAUSE` (noyau) arrête tout lancement.
8. Le **modèle** est choisi par ticket (`model`), par défaut Sonnet ; Opus pour noyau, sécurité et conception ; Haiku pour scripts et documentation.

## Conséquences
Contrat : champs `stage` et `model` des tickets ; fichier `factory/config.yaml` ; `missions/mandates/`. Plateforme : App GitHub étendue (T-215), workflow `factory-dispatch`, travailleur homelab en tirage. Agents : journal JSON par tentative. Coût : aucun hors abonnement ; une clé API facturée au token exige un plafond mensuel Console (T-145). Le débit est borné par le quota : le calendrier du §6 se recalcule après le pilote.

## Alternatives écartées
Dispatcher LLM : coût de quota et non-déterminisme. Agent SDK sur abonnement : conditions non confirmées. Environnements auto-hébergés officiels : réservés à Team/Enterprise. Merge par le compte de Paul : contredit T-215. Plus de 10 agents d'emblée : graphe et quota limitent avant les slots. Clé API par défaut : dépense non maîtrisée.

## Vérification
Pilote 24 h (coût par ticket, % de quota) ; PR de test du noyau non fusionnable ; test négatif : mandat expiré ou chemin hors liste → `needs-paul` ; drill de limite de quota (reprise au reset) ; drill de boucle (3e tentative refusée) ; relecture hebdomadaire du résumé.

## Références
S1 à S17 ci-dessus ; `docs/CLOUD-AGENTS.md`, `docs/AGENT-RUNNERS.md`, `docs/AGENT-PR-MODEL.md`, `docs/DEV-FACTORY.md`, `/home/user/atlas/dispatcher/mission-contract.md`, `headless-profile.md`, `policies/`.
