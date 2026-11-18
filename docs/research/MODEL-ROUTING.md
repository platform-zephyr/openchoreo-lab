# Recherche — Routage des modèles par tâche (Claude Max, Claude Code, DeepSeek, agentgateway)

Date : 2026-11-18 · Statut : recherche pour ADR (rien appliqué, aucun secret, aucun cluster touché).
Marques : **[C]** lu dans une source primaire à la date indiquée ; (sources tierces lues par curl aussi marquées [C]) ;
**[E]** connaissance du chercheur, non revérifiée ; **[H]** hypothèse à mesurer. Preuve runtime : aucune (NOT_TESTED).

## 1. Conclusion
1. **Défaut : Sonnet 5.5 (`claude-sonnet-5-5`, effort `high`)**, mais « le moins cher » n'est **pas prouvé** : sur le classement Terminal-Bench 4.1 (agent Claude Code, effort `max`),
   Sonnet 5.5 fait 63,9 % pour 7,3 k$ et 19,4 G tokens, Opus 5.5 65,8 % pour 4,7 k$ [C14] : Sonnet est deux fois moins cher au token mais consomme 2,4 fois plus de tokens.
   Le bon indicateur est le **quota (ou le coût) par ticket fusionné** : MOD-7 compare Sonnet `high` et Opus `medium`.
2. **Haiku 5.5 (`medium`/`low`)** pour les tâches courtes vérifiées par la CI ou sans code (40,0 % à TB 4.1 [C14]) ; Anthropic le déconseille pour le codage agentique complexe [C4].
3. **Opus 5.5 (`high`)** pour la sécurité, le noyau, la revue adverse, l'escalade. **Fable 5.2 sort de l'échelle** : 65,8 % comme Opus 5.5 mais 16,5 k$ contre 4,7 k$ [C14],
   et il plafonne à 50 % du quota hebdomadaire [C7] : sur demande de Paul seulement.
4. **DeepSeek** (lu à la source, §3) : **`deepseek-flash` ≈ Haiku 5.5** (38,5 % contre 40,0 % à TB 4.1) pour 0,2 k$ contre 1,0 k$ ; **`deepseek-v4-pro` est à écarter pour les agents** (6,7 %).
   Flash convient aux services IA internes et à la veille sur données publiques, par agentgateway ; jamais pour les logs de production (la politique de confidentialité autorise l'entraînement sur les entrées).
5. Le choix par ticket se fait par des **règles lisibles par machine** (`backlog/proposals/model-routing.yaml`), un champ `model` d'en-tête qui ne peut que **monter**
   au-dessus du plancher, et une **mesure** par (type de tâche, modèle) qui ajuste les règles (§5).

## 2. Faits lus (sources primaires, lues le 2026-11-18)
| Modèle | ID API | Entrée / sortie ($/MTok) | Lecture de cache | Effort par défaut | Pensée |
|---|---|---|---|---|---|
| Fable 5.2 | `claude-fable-5-2` | 8 / 40 | 0,20 | `high` | adaptative, toujours active |
| Opus 5.5 | `claude-opus-5-5` | 4 / 20 | 0,20 | `medium` | adaptative, toujours active |
| Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 | 0,10 | `high` | adaptative |
| Haiku 5.5 | `claude-haiku-5-5` | 0,10 / 0,50 (prompt ≤ 100 k) ; 0,50 / 2,50 au-delà | 0,01 / 0,05 | `medium` | adaptative |

- Tous : contexte 1 M, sortie 128 k, Batch −50 % (pas avec le mode rapide, offert pour Fable 5.2 et Opus 5.5) [C1, C2].
- Benchmarks publiés par Anthropic [C3, C4, C5] (SWE-bench Verified **non publié** pour ces modèles ; Fable 5.2 : aucun chiffre trouvé) :

| Benchmark | Haiku 5.5 | Sonnet 5.5 | Opus 5.5 |
|---|---|---|---|
| Terminal-Bench 4.0 | 39,2 % | 70,6 % | 66,4 % (effort `xhigh`, ±2,6) |
| FrontierCode 1.1 Main | 46,4 % | 52,1 % (`xhigh`) ; 46,2 % (`max`) | 54,4 % (max) ; 54,6 % (`medium`) |
| CursorBench 4.0 | — | 55,5 % | 57,8 % (max) ; 52,5 % (`medium`) |
| OSWorld 2.1 | 72,4 % (sous-ensemble) | 80,1–83,9 % | 81,8 % |

  Lectures : (a) Sonnet ≈ Opus sur le code agentique, pour la moitié du prix ; (b) Opus à `medium` perd ~2 à 5 points face à `max` ;
  (c) **Sonnet à `max` fait moins bien qu'à `xhigh`** (modifications hors périmètre, délais) : plafonner Sonnet à `xhigh` ;
  (d) les tâches Terminal-Bench ne sont pas des manifestes Kubernetes : l'étalonnage sur ce dépôt (§5) prime sur ces scores.
- **Plan Max** : 100 $/mois pour 5× l'usage Pro, par fenêtre de 5 h et par semaine ; un plafond hebdomadaire commun à tous les modèles [C6].
  Fable est inclus mais limité à **50 % du plafond hebdomadaire** et « s'use plus vite » [C7]. Les crédits API mensuels de Max **ne servent pas**
  dans Claude Code [C8]. Au plafond : attendre, passer à Ultra, activer des crédits d'usage (tarif API) [C8]. Prix du 20× : non lu.
  **La consommation relative Opus/Sonnet/Haiku n'est pas publiée** dans les pages lues ; seule consigne : baisser l'effort réduit l'usage [C9].
- Claude Code : `--model`, `ANTHROPIC_MODEL`, `model` dans `settings.json`, `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` ; alias `fable|opus|sonnet|haiku|opusplan` ;
  ID complet pour épingler ; sous-agents : champs `model` et `effort`, `CLAUDE_CODE_SUBAGENT_MODEL` (+ `_FORCE`) ; `ANTHROPIC_BASE_URL` change la
  destination, pas le modèle [C10, C11]. `claude-code-action` : `claude_args: --model …`, jeton d'abonnement `CLAUDE_CODE_OAUTH_TOKEN` ou clé API [C12].
  Le workflow actuel (`.github/workflows/claude-agent.yml`) ne fixe **aucun** `--model` : il tourne sur le défaut de Claude Code.

## 3. Sources tierces lues à la source (curl, 2026-11-18)
- **DeepSeek, Models & Pricing** [C15] : `deepseek-flash` (DeepSeek-V4.1-Flash-1017) et `deepseek-v4-pro` (V4-Pro-0813), contexte 1 M, sortie 384 k, appels d'outils, JSON, thinking `low/high/max`, Flash avec vision, Pro sans.
  $/MTok, creux / pointe : Flash entrée 0,15 / 0,30, **cache 0,003 / 0,006**, sortie 0,60 / 1,20 ; Pro entrée 0,66 / 1,32, cache 0,022 / 0,044, sortie 1,98 / 3,96. Pointe = 01-04 h et 06-10 h UTC, lundi-vendredi
  (donc le matin européen) ; le reste, week-ends compris, est au tarif creux. Concurrence : Flash 2500, Pro 500 par compte [C16].
- **DeepSeek et Claude Code** [C17, C18] : base `https://api.deepseek.com/anthropic` (API Messages) ; Claude Code se règle par `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL=deepseek-flash[1m]`.
  **Piège** : tout nom `claude-opus*` est routé vers `deepseek-v4-pro` (facturé au tarif Pro) ; `claude-sonnet*` et `claude-haiku*` vers `deepseek-flash` : il faut fixer les alias Opus/Sonnet/Haiku sur `deepseek-flash`.
  Ignorés : `cache_control` (le cache est automatique), `mcp_servers`, `budget_tokens` ; `thinking` accepte enabled/disabled ; `output_config` ne porte que `effort`.
- **DeepSeek, données** [C19] : politique de confidentialité (grand public) : société de Hangzhou, entrées collectées, utilisées pour fournir et **entraîner/améliorer** les services, droit d'opposition mentionné,
  conservation « aussi longtemps que nécessaire ». Les conditions de la plateforme API sont illisibles (connexion coupée) : **NOT_PROVEN** pour la rétention de l'API. Conséquence : données publiques seulement.
- **agentgateway 1.7** [C13, C20] : route `/v1/messages` native avec conversion vers Responses, Chat Completions ou Bedrock Converse si le fournisseur n'a pas le format Messages (la conversion Responses perd l'historique
  de pensée, Chat Completions le garde) ; fournisseur `deepseek` intégré (`baseUrl` par défaut `https://api.deepseek.com/v1`) ; **clés virtuelles** avec budgets en tokens ou en dollars, restriction de modèles,
  révocation et rotation, catalogue de coûts et tableau de bord par modèle/fournisseur/utilisateur. Bascule entre fournisseurs : page « Resiliency » non lue, à prouver en k3d.
- **Terminal-Bench 4.1** [C14], tous avec l'agent Claude Code, effort `max`, mis à jour le 2026-11-17 : Opus 5.5 65,8 % ±3,1 ; Fable 5.2 65,8 % ±2,8 ; Sonnet 5.5 63,9 % ±3,0 ; Haiku 5.5 40,0 % ±3,6 ;
  DeepSeek V4.1 Flash 1017 38,5 % ±3,8 ; Sonnet 5 12,1 % ; DeepSeek V4 Pro 0813 6,7 % ±2,5. Les intervalles se recouvrent pour Opus, Fable et Sonnet : aucune différence démontrée entre eux.
  Notes DeepSeek [C21] : Flash 1017 annonce 42,3 % à TB 4.0 (framework Claude Code) contre 70,6 % pour Sonnet 5.5 [C3].
- **SWE-bench** [C22] : la page publique ne contient que des résultats jusqu'à février 2026, sans modèle de la famille 5 ni DeepSeek V4 : **inutilisable** ici, abandonné au profit de TB 4.1 et du banc du dépôt.
- Limites : benchmarks d'éditeur ou de classement public, tâches de terminal, pas des manifestes Kubernetes ; un score n'est pas un banc de ce dépôt (§5).

## 4. Coût comparé
**Plan Max = forfait ; le « coût » est le quota.** Mesure retenue : le quota consommé par ticket, pas des euros. Proxy [H] : le quota suit
le prix API, soit Haiku ≈ 0,05 ×, Sonnet 1 ×, Opus 2 ×, Fable 4 × (Fable est de plus plafonné à 50 %). À valider avec `/status` avant/après un ticket (MOD-8).
**API au token** : seulement si le quota Max ne suffit pas (COST-FREE-TIER §3 : MANDAT et plafond mensuel côté console).

Exemple [H, estimation de l'auteur] d'une session d'agent : 2,0 M tokens lus en cache, 0,3 M écrits (5 min), 0,1 M d'entrée fraîche, 80 k de sortie ; DeepSeek : 2,0 M au tarif cache, 0,4 M au tarif non caché.
| Modèle | Coût API de la session |
|---|---|
| Haiku 5.5 | ≈ 0,11 $ |
| DeepSeek Flash | ≈ 0,11 $ (creux) ; ≈ 0,23 $ (pointe) |
| DeepSeek V4 Pro | ≈ 0,47 $ (creux) ; ≈ 0,94 $ (pointe) |
| Sonnet 5.5 | ≈ 1,95 $ |
| Opus 5.5 | ≈ 3,90 $ |
| Fable 5.2 | ≈ 7,40 $ |
Ces coûts supposent la même consommation de tokens : au classement TB 4.1 Sonnet consomme 2,4 × plus de tokens qu'Opus, ce qui renverse le rapport de coût (1,6 × plus cher) : mesurer (MOD-7).

**Quand DeepSeek est pertinent** : (1) **services IA internes** (classification, résumé, extraction) et **veille** sur données publiques, `deepseek-flash` derrière le gateway, budget bloquant (ADR-0018) ;
(2) **indépendance du quota** Max et bascule si l'API Claude est indisponible ; (3) **agents externes** de faible risque sur dépôt public avec Claude Code (`deepseek-flash` seulement, effort `max`),
à planifier au tarif creux (hors 06-10 h UTC en semaine). **Pas pertinent pour** : logs de production, secrets, `data-class` ≠ public, noyau et sécurité (entrées utilisables pour l'entraînement, API non lue) ;
`deepseek-v4-pro` pour des agents (6,7 % à TB 4.1). À prix de liste, Flash coûte autant que Haiku 5.5 : son intérêt est le quota et la bascule ; pour des données sensibles, Haiku via le gateway reste le choix.
Toute dépense DeepSeek est un MANDAT avec plafond mensuel (COST-FREE-TIER §3).

## 5. Mécanique
**Fixer le modèle.** (a) En-tête de ticket : deux champs facultatifs `model:` (ID complet épinglé, ex. `claude-sonnet-5-5`) et `effort:`. (b) Le dispatcher
(T-210) calcule `route(ticket)` = règle de `backlog/routing.yaml` appliquée au couloir, à la classe recalculée depuis les chemins, aux mots-clés ; le champ
`model` ne peut que **relever** le plancher (jamais passer sous Opus pour une règle `floor: opus`). (c) Il transmet `--model` et `--effort` à
`claude-code-action` par `claude_args` (entrée `workflow_dispatch` `model`, `effort`). (d) Sessions locales ou cloud : `claude --model … --effort …`.
(e) Sous-agents : `model:` et `effort:` dans `.claude/agents/*.md` (ex. exploration en `haiku`, revue en `opus`) ; `CLAUDE_CODE_SUBAGENT_MODEL=haiku` pour le défaut.
(f) Services IA : le modèle est choisi par la clé virtuelle (`allowedModels`, budget) du gateway (ADR-0018), jamais par l'application.
**Escalade.** Échelle : Haiku → Sonnet `medium` → Sonnet `high` → Opus `high` → Fable `high` → humain. Déclencheurs : 2 échecs de CI sur la même cause ;
2 constats bloquants de la revue adverse ; ticket sorti de son périmètre de fichiers ; cause non prouvée après 2 hypothèses (diagnostic). Un seul cran à la fois ;
chaque cran est consigné (`Escalated-from:`). **Descente** : quand 20 tâches consécutives d'un type réussissent du premier coup, rejouer 10 % des suivantes au cran inférieur.
**Mesure.** Par PR : `Model:`, `Effort:`, `Escalated-from:` (trailers/labels), nombre d'échecs CI, constats de revue, interventions humaines, `usage` de
la sortie `result` de Claude Code [E, COST-FREE-TIER §5], durée. Indicateurs par (type, modèle) : réussite au premier passage, revert sous 7 jours,
taux d'escalade, quota ou coût par PR fusionnée ; intervalle de Wilson, **décision seulement à n ≥ 20**. Banc : T-044 rejoué sur Haiku, Sonnet, Opus.
Détail et tickets : `backlog/proposals/model-routing.yaml` (MOD-1 à MOD-13). Services IA : le gateway est le seul détenteur de la clé DeepSeek (clé virtuelle par usage).

## 6. Grille de routage (proposée ; chaque ligne est [H] jusqu'à l'étalonnage MOD-7 ; Fable hors échelle)
| Tâche | Modèle (effort) | Escalade |
|---|---|---|
| Recherche / documentation | Sonnet 5.5 (`medium`) ; Haiku pour fiches simples | Opus `high` si synthèse contradictoire |
| Rédaction de tickets | Haiku 5.5 (`medium`) | Sonnet après 1 rejet du lint backlog |
| Code Python/YAML simple | Sonnet 5.5 (`medium`) | Sonnet `high`, puis Opus après 2 échecs CI |
| Refactor appgen | Sonnet 5.5 (`high`) | Opus `high` après 2 échecs CI ou > 5 modules |
| CI GitHub Actions | Sonnet 5.5 (`high`) + revue Opus si noyau | Opus après 2 échecs |
| Manifestes K8s / OpenChoreo | Sonnet 5.5 (`high`) | Opus `high` après 2 échecs k3d |
| Sécurité, admission, RBAC, secrets | Opus 5.5 (`high`) | Fable `high` après 2 constats bloquants |
| Revue de code | Sonnet 5.5 (`high`) ; Opus si REVUE ou MANDAT | Opus |
| Revue adverse | Opus 5.5 (`high`), modèle ≠ auteur | Opus `max` pour ADR et noyau ; Fable sur demande de Paul |
| Diagnostic d'incident (prod) | Sonnet 5.5 (`high`), Claude seulement | Opus après 2 hypothèses non prouvées |
| Remédiation | Sonnet 5.5 (`high`), PR seulement | Opus si données ou revert en échec |
| Coordination / planification | Opus 5.5 (`high`) | Opus `max`, puis Paul |
| Banc d'intentions | Sonnet 5.5 (`high`) ; matrice Haiku/Sonnet/Opus en étalonnage | preuve runtime déterministe, pas de juge LLM |
| Veille de releases | Haiku 5.5 (`low`) ; `deepseek-flash` au tarif creux (données publiques) | Sonnet si rupture détectée |
| Services internes IA | Haiku 5.5 (sensible) ; `deepseek-flash` (public) ; pas de V4 Pro | Haiku ↔ DeepSeek en bascule ; budget bloquant |

## 7. Proposition d'ADR

```markdown
# ADR-0021 — Routage des modèles par tâche
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0012, ADR-0017, ADR-0018 ; D-2026-11-16-07 (homelab-infra)

## Contexte
- Les agents utilisent un forfait Claude Max (quota hebdomadaire commun, Fable plafonné à 50 %) ; le workflow `claude-agent.yml` ne fixe aucun modèle.
- La famille Claude 5 couvre un rapport de prix de 1 à 80 ; sur Terminal-Bench 4.1 (2026-11-17) Opus 5.5, Fable 5.2 et Sonnet 5.5 sont indiscernables (65,8 / 65,8 / 63,9 %), Fable coûte 3,5 × Opus.
- `deepseek-flash` égale Haiku 5.5 (38,5 / 40,0 %) à 1/5 du coût du classement ; `deepseek-v4-pro` échoue (6,7 %) ; la politique DeepSeek autorise l'entraînement sur les entrées.

## Décision
1. Chaque ticket a un modèle et un effort calculés par `backlog/routing.yaml` (premier critère qui correspond) ; le défaut est Sonnet 5.5 `high`.
2. Le champ `model:` d'un ticket peut relever le plancher de la règle, jamais l'abaisser ; la classe et le plancher sont recalculés depuis les chemins.
3. Plancher Opus 5.5 pour admission, RBAC, secrets, noyau (ADR-0002) et revue adverse, avec un modèle différent de l'auteur ; Fable seulement sur demande de Paul.
4. Escalade d'un cran après 2 échecs de CI ou 2 constats bloquants ; tout cran est consigné dans la PR.
5. Aucun log de production, secret ou donnée `data-class` ≠ public ne va à un fournisseur autre qu'Anthropic ; DeepSeek n'entre que par le gateway (`deepseek-flash` seulement, alias Claude Code épinglés), avec budget bloquant et MANDAT de dépense.
6. Toute dépense à l'API au token est un MANDAT avec plafond mensuel côté console.
7. Les règles se changent par PR, sur la base de mesures (n ≥ 20 par type et modèle).

## Conséquences
- Champ d'en-tête, `route.py`, entrées `model`/`effort` du dispatcher, trailers de PR, rapport hebdomadaire. Un modèle retiré (≥ 2027-09) impose une PR de règles.
- Coût : un banc d'étalonnage consomme du quota ; le routage peut être faux au départ (hypothèses [H]).

## Alternatives écartées
- Opus partout : prix au token double de Sonnet (mais Sonnet consomme plus de tokens : à mesurer). Haiku partout : 39 % à Terminal-Bench. Choix libre par l'agent : non reproductible.
- DeepSeek pour tous les agents : entrées utilisables pour l'entraînement, API non lue, V4 Pro à 6,7 %.

## Vérification
- `check.py` refuse un `model` inconnu ou sous le plancher ; la PR d'un agent porte `Model:` ; le rapport hebdomadaire existe ; un cas de test prouve la montée d'un cran.

## Références
Sources §8 ; `docs/research/COST-FREE-TIER.md`, `docs/adr/0018-services-ia.md`.
```

## 8. Sources (lues le 2026-11-18)
[C1] platform.claude.com/docs/en/about-claude/models/overview · [C2] …/about-claude/pricing · [C3] anthropic.com/claude-sonnet-5-5 · [C4] anthropic.com/claude-haiku-5-5 ·
[C5] anthropic.com/claude-opus-5-5 · [C6] support.claude.com/en/articles/11049741 (Max) · [C7] …/15424964 (Fable) · [C8] …/11145838 (Claude Code sur Pro/Max) · [C9] …/11647753 (limites) ·
[C10] code.claude.com/docs/en/model-config · [C11] …/sub-agents · [C12] …/github-actions · [C13] github.com/agentgateway/agentgateway · [C14] tbench.ai/leaderboard (Terminal-Bench 4.1) ·
[C15] api-docs.deepseek.com/quick_start/pricing · [C16] …/quick_start/rate_limit · [C17] …/guides/anthropic_api · [C18] …/quick_start/agent_integrations/claude_code · [C19] cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html ·
[C20] agentgateway.dev/docs/standalone/latest/llm/{api-types/messages, providers/deepseek, cost-controls, cost-controls/virtual-keys} (v1.7) · [C21] api-docs.deepseek.com/updates · [C22] swebench.com.
