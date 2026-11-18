# Recherche — Routage des modèles par tâche (Claude Max, Claude Code, DeepSeek, agentgateway)

Date : 2026-11-18 · Statut : recherche pour ADR (rien appliqué, aucun secret, aucun cluster touché).
Marques : **[C]** lu dans une source primaire à la date indiquée ; **[2nd]** source secondaire (recherche web, non officielle) ;
**[E]** connaissance du chercheur, non revérifiée ; **[H]** hypothèse à mesurer. Preuve runtime : aucune (NOT_TESTED).

## 1. Conclusion
1. **Défaut : Sonnet 5.5 (`claude-sonnet-5-5`, effort `high`)**. C'est le modèle le moins cher de la famille 5 qui reste « agentique » :
   Terminal-Bench 4.0 à 70,6 %, devant Opus 5.5 (66,4 %) et Haiku 5.5 (39,2 %) [C, §2]. Il coûte la moitié d'Opus et le quart de Fable.
2. **Haiku 5.5 (effort `medium` ou `low`)** pour les tâches courtes, vérifiées par la CI ou sans écriture de code (tickets, veille, résumés,
   `app.yaml` de l'archétype A). Anthropic le déconseille pour le codage agentique complexe [C].
3. **Opus 5.5 (effort `high`)** pour ce dont l'erreur coûte cher (admission, RBAC, secrets, noyau), pour la revue adverse et en escalade.
   **Fable 5.2** seulement sur demande de Paul ou après deux échecs d'Opus : il consomme le quota plus vite et plafonne à 50 % du hebdomadaire [C].
4. **DeepSeek** : utile pour les services IA internes sur données publiques et comme second fournisseur (quota indépendant du plan Max).
   **Les sources primaires DeepSeek n'ont pas pu être lues** (hôtes bloqués) : aucun tarif DeepSeek n'est acté ici (§3, §6).
5. Le choix par ticket se fait par des **règles lisibles par machine** (`backlog/proposals/model-routing.yaml`), un champ `model` dans l'en-tête
   qui ne peut que **monter** au-dessus du plancher de la règle, et une **mesure** par (type de tâche, modèle) qui ajuste les règles (§5).

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

## 3. Ce qui n'a pas pu être lu (BLOCKED)
`api-docs.deepseek.com`, `huggingface.co`, `www.swebench.com`, `www.tbench.ai`, `agentgateway.dev` : hôtes hors liste réseau de la session.
**À autoriser pour clore l'étude.** Repli : recherche web [2nd] (résultats contradictoires) et README GitHub d'agentgateway [C13].
- DeepSeek [2nd, novembre 2026, non vérifié] : deux modèles `deepseek-flash` (V4.1 Flash) et `deepseek-v4-pro`, contexte 1 M, sortie jusqu'à 384 k ;
  tarif heures creuses / pleines : Flash ≈ 0,15 / 0,60 → 0,30 / 1,20 ; Pro ≈ 0,66 / 1,98 → 1,32 / 3,96 $/MTok ; alias `deepseek-chat` et
  `deepseek-reasoner` retirés le 2026-07-24 (une source donne une autre date). Appels de fonctions, endpoint compatible Anthropic, rétention
  et localisation des données : **NOT_TESTED**, à lire dans la doc officielle avant toute règle `status: active`.
- agentgateway [C13] : fournisseurs OpenAI, Anthropic, Gemini, Bedrock via une API compatible OpenAI ; répartition de charge et bascule ; budgets
  et limites de débit ; OpenTelemetry. Le support natif de l'API Messages d'Anthropic (nécessaire pour Claude Code derrière le gateway) n'est **pas confirmé**.
- Terminal-Bench / SWE-bench : seuls les chiffres de l'éditeur sont lus ; pas de classement indépendant. Un score éditeur n'est pas un banc de ce dépôt.

## 4. Coût comparé
**Plan Max = forfait ; le « coût » est le quota.** Mesure retenue : le quota consommé par ticket, pas des euros. Proxy [H] : le quota suit
le prix API, soit Haiku ≈ 0,05 ×, Sonnet 1 ×, Opus 2 ×, Fable 4 × (Fable est de plus plafonné à 50 %). À valider avec `/status` avant/après un ticket (MOD-8).
**API au token** : seulement si le quota Max ne suffit pas (COST-FREE-TIER §3 : MANDAT et plafond mensuel côté console).

Exemple [H, estimation] d'une session d'agent : 2,0 M tokens lus en cache, 0,3 M écrits en cache (5 min), 0,1 M d'entrée fraîche, 80 k de sortie.
| Modèle | Coût API de la session |
|---|---|
| Haiku 5.5 | ≈ 0,11 $ |
| Sonnet 5.5 | ≈ 1,95 $ |
| Opus 5.5 | ≈ 3,90 $ |
| Fable 5.2 | ≈ 7,40 $ |
| DeepSeek Flash / Pro [2nd] | ≤ 0,4 $ / ≤ 1,7 $ (borne haute : tout l'entrant au tarif creux sans remise de cache) |

**Quand DeepSeek est pertinent** : (1) **services IA internes** (classification, résumé, extraction) sur données publiques, derrière le gateway, avec
budget bloquant (ADR-0018) ; (2) **indépendance du quota** Max (un ticket de plus sans consommer la semaine) et bascule si l'API Claude est indisponible ;
(3) **agents externes** de faible risque sur dépôt public, si un endpoint compatible Claude Code est confirmé. **Pas pertinent pour** : logs de production,
secrets, noms d'utilisateurs ou tout contenu `data-class` ≠ public (fournisseur tiers, localisation des données non lue) ; noyau et sécurité.
À prix de liste, **Haiku 5.5 (0,10/0,50) n'est pas plus cher que DeepSeek Flash [2nd]** : pour des données sensibles, Haiku via le gateway est le choix par défaut.
Sans cache, DeepSeek Pro ne bat pas nettement Sonnet 5.5 sur une session d'agent : son intérêt est le quota, pas le prix.

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
Détail et tickets : `backlog/proposals/model-routing.yaml` (MOD-1 à MOD-13).

## 6. Grille de routage (proposée ; chaque ligne est [H] jusqu'à l'étalonnage MOD-7)
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
| Revue adverse | Opus 5.5 (`high`), modèle ≠ auteur | Fable pour ADR et noyau |
| Diagnostic d'incident (prod) | Sonnet 5.5 (`high`), Claude seulement | Opus après 2 hypothèses non prouvées |
| Remédiation | Sonnet 5.5 (`high`), PR seulement | Opus si données ou revert en échec |
| Coordination / planification | Opus 5.5 (`high`) | Fable pour arbitrage inter-ADR |
| Banc d'intentions | Sonnet 5.5 (`high`) ; matrice Haiku/Sonnet/Opus en étalonnage | preuve runtime déterministe, pas de juge LLM |
| Veille de releases | Haiku 5.5 (`low`) ; DeepSeek Flash possible (données publiques) | Sonnet si rupture détectée |
| Services internes IA | Haiku 5.5 (sensible) ; DeepSeek Flash/Pro (public, [2nd] à vérifier) | Haiku ↔ DeepSeek en bascule ; budget bloquant |

## 7. Proposition d'ADR

```markdown
# ADR-0021 — Routage des modèles par tâche
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0012, ADR-0017, ADR-0018 ; D-2026-11-16-07 (homelab-infra)

## Contexte
- Les agents utilisent un forfait Claude Max (quota hebdomadaire commun, Fable plafonné à 50 %) ; le workflow `claude-agent.yml` ne fixe aucun modèle.
- La famille Claude 5 couvre un rapport de prix de 1 à 80 ; Sonnet 5.5 égale Opus 5.5 sur Terminal-Bench 4.0 pour la moitié du prix (lu le 2026-11-18).
- DeepSeek est prévu pour les services IA internes via agentgateway ; ses sources primaires n'ont pas été lues.

## Décision
1. Chaque ticket a un modèle et un effort calculés par `backlog/routing.yaml` (premier critère qui correspond) ; le défaut est Sonnet 5.5 `high`.
2. Le champ `model:` d'un ticket peut relever le plancher de la règle, jamais l'abaisser ; la classe et le plancher sont recalculés depuis les chemins.
3. Plancher Opus 5.5 pour admission, RBAC, secrets, noyau (ADR-0002) et revue adverse, avec un modèle différent de l'auteur ; Fable seulement sur demande de Paul ou après deux échecs d'Opus.
4. Escalade d'un cran après 2 échecs de CI ou 2 constats bloquants ; tout cran est consigné dans la PR.
5. Aucun log de production, secret ou donnée `data-class` ≠ public ne va à un fournisseur autre qu'Anthropic ; DeepSeek n'entre qu'après lecture des sources primaires, par le gateway, avec budget bloquant.
6. Toute dépense à l'API au token est un MANDAT avec plafond mensuel côté console.
7. Les règles se changent par PR, sur la base de mesures (n ≥ 20 par type et modèle).

## Conséquences
- Champ d'en-tête, `route.py`, entrées `model`/`effort` du dispatcher, trailers de PR, rapport hebdomadaire. Un modèle retiré (≥ 2027-09) impose une PR de règles.
- Coût : un banc d'étalonnage consomme du quota ; le routage peut être faux au départ (hypothèses [H]).

## Alternatives écartées
- Opus partout : 2× le quota de Sonnet sans gain mesuré. Haiku partout : 39 % à Terminal-Bench. Choix libre par l'agent : non reproductible.
- DeepSeek pour tous les agents : confidentialité et endpoint non vérifiés.

## Vérification
- `check.py` refuse un `model` inconnu ou sous le plancher ; la PR d'un agent porte `Model:` ; le rapport hebdomadaire existe ; un cas de test prouve la montée d'un cran.

## Références
Sources §8 ; `docs/research/COST-FREE-TIER.md`, `docs/adr/0018-services-ia.md`.
```

## 8. Sources (lues le 2026-11-18)
[C1] platform.claude.com/docs/en/about-claude/models/overview · [C2] …/about-claude/pricing · [C3] anthropic.com/claude-sonnet-5-5 · [C4] anthropic.com/claude-haiku-5-5 ·
[C5] anthropic.com/claude-opus-5-5 · [C6] support.claude.com/en/articles/11049741-what-is-the-max-plan · [C7] …/15424964-claude-fable-models-on-your-plan ·
[C8] …/11145838-using-claude-code-with-your-pro-or-max-plan · [C9] …/11647753-understanding-usage-and-length-limits · [C10] code.claude.com/docs/en/model-config ·
[C11] code.claude.com/docs/en/sub-agents · [C12] code.claude.com/docs/en/github-actions · [C13] github.com/agentgateway/agentgateway ·
[2nd] recherches web « DeepSeek API pricing » du 2026-11-18 (cloudzero.com, verdent.ai, activepieces.com, nxcode.io…), non officielles.
