---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Usine d'agents : art antérieur à réutiliser (T-477)

Date : 2026-11-18. Étude seulement : aucun code repris, aucun cluster touché. Dépôt PUBLIC : aucune valeur sensible.
Méthode : skill `prior-art` (niveau `complet`), contenu externe traité comme donnée. Lecture par WebFetch et WebSearch ;
`git clone` et le téléchargement d'archives ont été refusés dans cette session (voir §7). Légende : **[V]** lu le 2026-11-18 ;
**[NV]** non lu ou non vérifié ; **[E]** estimation de l'auteur. Les SHA viennent de la page « commits » lue par WebFetch : à
revérifier par `git ls-remote` avant toute copie.

## 0. Conclusion
1. **Rien n'est à adopter tel quel comme usine.** Les trois « software factories » lues (coleam00, AlexPEClub, SSW) visent
   d'autres socles (Archon, VPS Docker, plugin de scaffolding). Notre socle (`claude-code-action` + matrice + backlog en
   fichiers) est équivalent ou meilleur sur la garde de recouvrement, le disjoncteur de quota et les trailers (§5).
2. **Le plus gros gain est dans Claude Code lui-même, pas dans un dépôt tiers.** Trois options natives ne sont pas utilisées
   par `claude-agent.yml` : `--max-budget-usd` (plafond de coût par run), `--permission-prompts none` (un refus est annoncé
   « non approuvable, ne pas réessayer »), et l'injection du corps de l'issue dans le prompt (un tour `gh issue view` de moins)
   [V][S1]. Effort S ; vise directement « 79 tours / 1,8 $ » et « refus qui coûtent des tours ».
3. **Deux idées à adapter, à fort levier :** (a) la *finalisation déterministe* (l'agent ne pousse pas, n'ouvre pas la PR ;
   une étape du workflow le fait avec un jeton d'App neuf) [V][S3][S4] : supprime le problème du jeton d'1 h, la branche
   introuvable et ~5 à 10 tours par run [E] ; (b) le *journal de métriques par run* avec un résumé hebdomadaire
   (`metrics.jsonl` + `factory-stats` chez AlexPEClub) [V][S4] : sans lui, on ne sait pas si un changement de l'usine aide.
4. **Le reste est à ignorer** pour l'instant : catalogues de sous-agents génériques (VoltAgent : prompts de 1 000 mots,
   outils d'écriture sur un « reviewer »), orchestrateurs tmux/IDE, plateformes fermées, mémoire inter-projets.
5. Gain total estimé des 5 premières recommandations : **2 à 4 jours** de conception évités et **30 à 50 % de tours** en moins
   par run simple [E, à mesurer par T-479].

## 1. Verdict par source
| Source (permalien) | Licence | Dernière activité | Verdict | Ce que ça nous épargne |
|---|---|---|---|---|
| [coleam00/ai-software-factory @3c696c8](https://github.com/coleam00/ai-software-factory/tree/3c696c853f519da20459e91fc52c1112c5d262f8) [V] | MIT (commit « add MIT license ») | 2026-11-13 | **ADAPTER** idées : porte de fusion déterministe sur preuves, *holdout* (scénarios cachés au constructeur par un hook), `halt`/`pause` distincts, `protected_paths`, réclamation par commentaire | 1 j de conception du « juge » et des scénarios d'acceptation |
| [coleam00/Archon](https://github.com/coleam00/Archon) [V] | MIT | actif (PR d'oct. 2026) | **IGNORER** comme moteur (TypeScript, serveur, 23 k étoiles mais dépendance lourde) ; **idée** : nœud « boucle jusqu'à ce qu'une commande shell réussisse, plafond d'itérations » | — |
| [AlexPEClub/software-factory @dedba50](https://github.com/AlexPEClub/software-factory/tree/dedba50403f225b9c6e210944c348673c72bc228) [V] | MIT | 2026-11-12 (créé le 9, 17 commits, « première version ») | **ADAPTER** : le runner n'écrit aucun code ; l'agent ne fusionne jamais lui-même ; build valide seulement si la vérification est verte sur le commit exact poussé ; agent d'acceptation séparé (2 tours max) ; `metrics.jsonl` + `factory-stats` | 0,5 j sur la finalisation et la mesure |
| [SSWConsulting/factory-builder @06631e1](https://github.com/SSWConsulting/factory-builder/tree/06631e1e9c0d93f6275a6c20a3b8ace9b8d05077) [V] | **aucune licence visible** | 2026-11-17 | **IDÉE seulement** (aucune ligne copiable) : statuts de porte `NOT RUN / BLOCKED / FAILED / WAIVED`, « une porte verte n'est pas une autorité de merge », contrats hachés | conforte notre Verdict (T-466) |
| [FlorianBruniaux/…/agentic-software-factories.md @e0d8cbb](https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/e0d8cbbc02d54f9b326fc0c6bf3240a7b80c8a7f/guide/workflows/agentic-software-factories.md) [V] | CC BY-SA 4.0 (texte ; gabarits CC0) | 2026-11-09 | **LIRE, ne pas copier** (share-alike) : niveaux L1-L6, piège de la « CI décorative », revue par risque, `/goal`, auto-fix de PR | carte des options en 30 min |
| Gist « Maciejd » : [gist.github.com/Maciejd](https://gist.github.com/Maciejd) [V] | — | 2014 | **Introuvable sous ce nom** : 4 gists Java de 2014, sans rapport. Le gist pertinent est probablement [Maciejdziuba/88890d7e…](https://gist.github.com/Maciejdziuba/88890d7e0eeefa5a8738bbe9fd5e20b8) [V] | — |
| Gist Maciejdziuba « software-factory » (SKILL.md) [V] | **aucune licence** | actif 2026-11-11 | **IDÉE** : 4 portes (produit, architecture, design du programme, tranches verticales) ; « jamais de test qui passe sur le code d'avant » ; portes sautées sous ~100 lignes de diff | règle de découpage des tickets |
| [VoltAgent/awesome-claude-code-subagents @ed74d11](https://github.com/VoltAgent/awesome-claude-code-subagents/tree/ed74d115b7fb7026a22a4f816a8e3250f425e3b4) [V] | MIT | 2026-11-02 | **IGNORER** : `code-reviewer` a `Write, Edit, Bash` et `model: inherit` ; contraire à notre reviewer en lecture seule (T-341). Le README dit lui-même ne pas auditer les agents | — |
| [hesreallyhim/awesome-claude-code @4d2f98d](https://github.com/hesreallyhim/awesome-claude-code/tree/4d2f98d0f70d8f9abaae9275606d19a5061ba95c) [V, 200 k/243 k caractères lus] | licence non lue [NV] | 2026-11-18 | **INDEX** : a mené à ccpm, ralph-claude-code, claude-code-security-review | — |
| [automazeio/ccpm](https://github.com/automazeio/ccpm) [V] | MIT | non lue [NV] | **ADAPTER** l'idée PRD → épopée → tâches (≤ 10 par épopée, `depends_on`, `parallel`, `conflicts_with`) | modèle de décomposition (§3) |
| [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) [V] | MIT | v0.11.5, date non lue [NV] | **ADAPTER** seuils : disjoncteur « 3 boucles sans changement de fichier », « 5 boucles même erreur » | calibrage du disjoncteur de boucle (T-317) |
| [anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review) [V] | MIT | non lue [NV] | **PLUS TARD** (FINAL0) : action officielle ; « pas durcie contre l'injection, PR de confiance seulement » | — |
| Plugin officiel `code-review@claude-plugins-official` [V][S2] | (Anthropic) | doc 2026 | **ADOPTER pour T-321** : revue de PR par skill officiel, `--comment`, outil MCP de commentaire en ligne | 1 j sur T-321 |
| `/goal`, Stop hook, `--max-budget-usd`, `--permission-prompts none` [V][S1][S5] | (Anthropic) | doc 2026 | **ADOPTER** : options natives | voir §0.2 |
| awesomeclaude.ai : `/claude-code-workflows`, `/claude-code-tips`, `/claude-code-best-practices`, `/ralph-wiggum` | — | — | **NOT_TESTED** : hôte hors liste réseau de la session (DNS refusé) | — |
| Plugin `ralph-wiggum` (anthropics/claude-code) | — | — | **NOT_TESTED** : README brut en 404 à l'URL essayée ; sources tierces contradictoires (défaut d'itérations 30 ou illimité) | — |

## 2. Matrice douleur → solution existante
| Douleur de la journée | Solution existante | Où | Statut chez nous |
|---|---|---|---|
| Verdict faux sur échec | Statuts de porte `NOT RUN/FAILED/WAIVED`, jamais « passed » par défaut ; vérif sur le commit exact poussé | SSW `gates.py` [V] ; AlexPEClub `factory-verify` [V] | Équivalent (Verdict T-466) ; ajouter « commit exact » à la finalisation (R4) |
| Trailers oubliés par le modèle | Ne pas demander au modèle ; le faire hors modèle | ccpm impose un format de commit par prompt (plus faible) [V] | **Mieux chez nous** (hook git root, T-474) |
| Refus de permission qui coûtent des tours | `--permission-prompts none` : le refus dit « personne ne peut approuver, ne réessaie pas » ; `permission_denials` dans le résultat | Claude Code [V][S1] | **Absent** : R1 |
| Jeton d'App 1 h vs runs longs | Le runner (pas l'agent) pousse et ouvre la PR ; jeton créé après l'agent | AlexPEClub [V] ; coleam00 porte déterministe [V] | **Absent** : R4 |
| Quota Max partagé sans disjoncteur | `MAX_CALLS_PER_HOUR`, disjoncteur OPEN/HALF_OPEN ; `maxParallel` 1-2 sur abonnement | ralph-claude-code [V] ; AlexPEClub [V] | Équivalent (ledger T-467) ; manque le plafond par run (R1) |
| Recouvrements de fichiers | Réclamation par commentaire, « la plus ancienne gagne » ; `conflicts_with` par tâche | coleam00 [V] ; ccpm [V] | **Mieux chez nous** (`overlap.py` par périmètre, avant dispatch) |
| Tickets trop gros pour un run | ≤ 10 tâches par épopée ; tranches verticales ; portes sautées sous ~100 lignes | ccpm [V] ; gist Maciejdziuba [V] | **Absent** : R3 |
| STATUS périmé | Fichiers = source, scripts de statut | ccpm [V] | Équivalent (STATUS généré + contrôle CI T-475) |
| CI vs local divergents | « CI décorative » : vérifier que la vérif tourne vraiment | guide Bruniaux [V] | Équivalent (`tools/dev/check`, `ci-map.tsv`, T-460) |
| 79 tours / 1,8 $ pour un ticket simple | `--max-budget-usd`, `--max-turns`, issue précise, CLAUDE.md court | Doc Actions « Manage costs » [V][S2] | Partiel (max-turns) : R1 + R2 (mesure) |
| Coût fixe par run | Contexte livré dans le prompt ; ~33 Ko lus à chaque run (AGENTS, STATE, MISSION, AGENT-PR-MODEL) [mesuré] | Doc Actions [V][S2] | **Absent** : R1 (corps d'issue) puis R6 (paquet de contexte) |

## 3. Patterns à fort levier non encore utilisés
| Pattern | Source | Chez nous | Effort |
|---|---|---|---|
| Plafond de coût natif par run (`--max-budget-usd`) | Claude Code [V][S1] | non | S |
| Refus définitifs (`--permission-prompts none` ou `denyInsteadOfPrompting`) | Claude Code [V][S1] | non | S |
| Finalisation déterministe (push, PR, auto-merge par le workflow) | AlexPEClub, coleam00 [V] | non (l'agent pousse) | M |
| Journal de métriques par run + résumé (tours, coût, refus, verdict par modèle) | AlexPEClub `metrics.jsonl` [V] | artefacts `mission-result` épars ; T-323 gelé | S |
| Boucle « jusqu'au critère » vérifiée par commande, plafonnée | `/goal` [V][S5], Archon loop node [V], Ralph | Stop hook `check --fast` (T-331) : déjà la version déterministe | — (fait) |
| Disjoncteur de non-progrès (N tours sans écriture de fichier) | ralph-claude-code [V] ; `/goal` s'arrête sans usage d'outil [V] | non | S (dans T-317) |
| Spec/PRD → tickets bornés (≤ 10, dépendances, `conflicts_with`) | ccpm [V] | tickets écrits à la main | M |
| Revue adversariale par un autre modèle, skill officiel | plugin `code-review` [V][S2] ; coleam00 « deux reviewers qui n'ont pas écrit » | T-321 à faire | M |
| Scénarios d'acceptation cachés au constructeur (*holdout*) | coleam00 `holdout_fence.py` [V] ; AlexPEClub acceptance [V] | non | L |
| Évals de l'usine (banc de tâches réelles, pass^k) | Anthropic evals [V, cité par AGENT-HARNESS S7] | T-346 gelé | L |
| Dispatch par lot Opus → sous-agents Sonnet en worktree | Claude Code worktrees [V][S6] ; L1 `/batch` du guide [V, non vérifié en doc officielle] | **fait** (skill orchestrate-backlog) | — |
| `halt` (bloque lancement et continuation) distinct de `pause` (timer seul) | coleam00 [V] | un seul `factory/PAUSE` | S |
| Gabarit d'issue d'agent (contexte en amont) | Doc Actions [V][S2] | T-436 à faire | S |

## 4. Recommandations classées (gain / effort)
**R1 — Plafonds natifs dans l'exécutant (S, gain élevé). Ticket T-478.** `--max-budget-usd` par modèle (via
`run-ticket.sh limits`), `--permission-prompts none`, corps de l'issue passé dans le prompt (fichier, pas `gh issue view`).
Périmètre : `.github/workflows/claude-agent.yml`, `tools/factory/run-ticket.sh`, `tests/factory/run-ticket-test.sh`,
`tests/factory/workflow-guard-test.sh`. Critères : options présentes et testées hors ligne ; version de Claude Code de l'action
≥ v2.1.259 prouvée ; un run réel avec `total_cost_usd` ≤ plafond et aucun refus répété.

**R2 — Statistiques de l'usine par run (S, gain élevé : mesure de tout le reste). Ticket T-479.** `tools/factory/stats.py`
lit des `mission-result.v1` et rend, par modèle et par ticket : runs, tours (médiane, p90), coût, durée, refus par outil,
verdicts. Périmètre : `tools/factory/stats.py`, `tests/factory/stats_test.py`. Critères : tests avec cas négatifs ; sortie
JSON et Markdown ; aucune sortie d'outil ni valeur sensible.

**R3 — Garde de taille des tickets (S, gain moyen). Ticket T-480.** Avertissement de `check.py` quand un ticket actif dépasse
ce qu'un run absorbe (seuils initiaux [E] : > 8 éléments de périmètre, > 6 critères, glob `**` sur un répertoire de code).
Inspiré de ccpm (≤ 10 tâches) et des tranches verticales. Périmètre : `tools/backlog/sizing.py`,
`tests/backlog/test_sizing.py`, `tools/backlog/check.py`.

**R4 — Finalisation déterministe (M, gain élevé). Après T-478 (même fichier).** L'agent commit seulement ; une étape suivante
crée un jeton d'App neuf, pousse `claude/issue-<n>-*`, ouvre la PR (gabarit + mission-result), arme l'auto-merge, puis le
Verdict lit la CI du commit exact. Périmètre : `claude-agent.yml`, `tools/factory/finalize.sh`, `tests/factory/`.

**R5 — Revue indépendante par le plugin officiel `code-review` (M). Réoriente T-321** vers l'amont : skill officiel, autre
modèle, outils en lecture, statut requis ; pas de prompt maison.

**R6 — Paquet de contexte de run (S).** Un fichier généré (≤ 4 Ko : règles utiles, périmètre, critères) remplace la lecture
de STATE.md et MISSION.md par l'agent de l'usine. À mesurer avec T-479 avant/après.

**R7 — Disjoncteur de non-progrès (S). À verser dans T-317** : seuils de ralph-claude-code (3 boucles sans écriture,
5 boucles même erreur) comme valeurs initiales.

**R8 — `halt` distinct de `pause` (S).** `factory/HALT` refuse aussi les relances et la reprise ; `PAUSE` ne bloque que les
nouveaux lancements. À décider après le pilote T-322.

## 5. Ce que nous faisons déjà mieux ou de façon équivalente (ne pas refaire)
- **Garde de recouvrement par périmètre avant dispatch** (`overlap.py`) : plus sûr que la réclamation par commentaire
  (coleam00) et que `conflicts_with` déclaré à la main (ccpm).
- **Trailers par hook git root, hors modèle** (T-474) : aucune source lue ne le fait ; ccpm s'en remet au prompt.
- **Disjoncteur de quota Max avec état sur `main`** (ledger T-467) : équivalent au disjoncteur de Ralph, adapté au partage.
- **Hooks déterministes** (périmètre, Bash, Stop `check --fast` + leak-guard) : c'est déjà la forme « commande » de `/goal`,
  plus fiable que l'évaluateur LLM qui lit seulement la transcription [V][S5].
- **Verdict séparé de la sortie de l'action** (T-466) ; **statuts STE80** ; **backlog en fichiers + score** (T-476).
- **Kill-switch sur `main` + `max-parallel`** : équivalent à `halt`/`parallel` de coleam00.
- **Art antérieur borné** (ADR-0024) et **contrôle local = CI** (`tools/dev/check`) : rien de plus abouti dans les sources.

## 6. Risques
- **Injection via contenus tiers** : les catalogues (VoltAgent, awesome-*) et les plugins tiers sont des prompts non audités ;
  le README de VoltAgent le dit [V]. Ne jamais installer un plugin ou sous-agent tiers dans l'usine ; le reviewer reste en
  lecture seule (T-341). Le corps d'issue injecté (R1) est écrit par un compte à droit d'écriture, mais il reste une donnée :
  le cadrer comme telle dans le prompt.
- **Revue LLM** : `claude-code-security-review` n'est « pas durcie contre l'injection » [V] ; le guide cite des résultats
  qui affaiblissent la revue d'un LLM par un LLM [V, non vérifié]. La revue (R5) complète `ci-ok`, ne le remplace pas.
- **Auto-fix et commentaires** : des réponses d'agent sur une PR peuvent déclencher des workflows pilotés par commentaire [V].
- **Licences** : SSW et le gist Maciejdziuba n'ont **pas de licence** (idée seulement) ; le guide Bruniaux est **CC BY-SA**
  (aucune copie de texte) ; MIT pour coleam00, AlexPEClub, Archon, ccpm, ralph-claude-code, VoltAgent : copie possible avec
  ligne `NOTICE`, mais aucune copie n'est proposée ici.
- **Dépendances** : Archon et les orchestrateurs tmux/IDE ajouteraient un service à opérer ; rejetés. Les options natives (R1)
  dépendent de la version de Claude Code embarquée par l'action épinglée : à prouver (T-478).
- **Coût du plafond** : `total_cost_usd` est une estimation côté client [V][S1] ; sur l'abonnement Max, le plafond borne le
  run, pas la facture.

## 7. Non lu, NOT_TESTED
- awesomeclaude.ai (4 pages) : hôte hors liste réseau de la session. Pour les lire : ajouter l'hôte à l'environnement.
- README brut du plugin `ralph-wiggum` : 404 à l'URL essayée ; non retrouvé.
- Code des dépôts (`holdout_fence.py`, `gates.py`, runner d'AlexPEClub) : `git clone` et archives refusés dans cette session ;
  seuls les README ont été lus. Licence de SSW et date de dernier commit de ccpm, ralph-claude-code, security-review : NOT_TESTED.
- Les SHA viennent de pages lues par un modèle de synthèse (WebFetch) : à confirmer par `git ls-remote` avant de citer en PR.
- Les gains en temps et en tours sont des estimations [E] : T-479 les mesure.

## 8. Sources
- [S1] https://code.claude.com/docs/en/headless — `--max-budget-usd`, `--permission-prompts none`, `permission_denials`, `--bare`, `total_cost_usd` (estimation) [V]
- [S2] https://code.claude.com/docs/en/github-actions — `claude_args`, plugin `code-review`, « Manage costs » [V]
- [S3] https://github.com/coleam00/ai-software-factory (README @3c696c8) [V]
- [S4] https://github.com/AlexPEClub/software-factory (README @dedba50) [V]
- [S5] https://code.claude.com/docs/en/goal — évaluateur Haiku, Stop hook, `-p` [V]
- [S6] https://code.claude.com/docs/en/common-workflows — worktrees, `claude --worktree` [V]
- Autres : SSW factory-builder, guide Bruniaux, gists Maciejd et Maciejdziuba, VoltAgent, hesreallyhim, ccpm,
  ralph-claude-code, Archon, claude-code-security-review (liens du §1) [V]. Recherche web : « gist Maciejd Claude Code software factory » (2026-11-18).
- Dépôt : `docs/research/AGENT-FACTORY-24-7.md`, `docs/research/AGENT-HARNESS.md` (non repris ici), `.github/workflows/claude-agent.yml`,
  `.claude/settings.json`, `tools/factory/`, tickets T-317, T-321, T-323, T-337, T-341, T-346, T-352, T-436, T-466, T-467, T-474.
