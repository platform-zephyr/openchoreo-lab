# Bonnes pratiques d'IDP quand les utilisateurs sont des agents IA

Date : 2026-11-18. Objectif : nourrir les ADR d'un labo où des LLM ajoutent des applications et opèrent la plateforme (OpenChoreo, OKE + cluster local).

## Méthode et fiabilité des sources
Mise à jour du 2026-11-18 : le réseau est ouvert (lecture par `curl`). S1 (Harness), S2 (Cycloid), S10 (Datadog), S11 (Anthropic), S12 (Team Topologies), S13 (Humanitec, page produit) et S14 (Google SRE) ont été relus ; voir leurs marques [V]. Auparavant, seuls les hôtes GitHub étaient joignables. Chaque source porte donc un niveau :
- **[L]** lue au texte (dépôts GitHub : CNCF TAG App Delivery, spécification MCP, OpenGitOps, Backstage, Score, OPA).
- **[V AAAA-MM-JJ + URL]** lue en ligne le 2026-11-18 (`VERIFICATION-2026-11-18.md`).
- **[E]** connue seulement par les extraits d'un moteur de recherche. Les points listés sont ceux que les extraits affirment ; ils ne valent pas lecture de l'article.
Les deux sources imposées (Harness, Cycloid) ont été lues en entier le 2026-11-18 ([V]).

---

## S1. Harness : « 5 best practices for building effective internal developer portals » [V 2026-11-18 + https://www.harness.io/blog/5-best-practices-for-building-effective-internal-developer-portals]
Article lu en entier (publié le 2024-10-17, mis à jour le 2026-08-31).
1. Cinq pratiques confirmées : (1) priorité à l'expérience développeur (persona, libre-service, boucles de retour, vues par développeur) ; (2) intégration sur toute la chaîne (API d'abord, SSO, interface cohérente) ; (3) découvrabilité et documentation (métadonnées et étiquettes, documentation, recherche) ; (4) collaboration et partage de connaissance (contributions, commentaires, historique des changements) ; (5) automatisation et gouvernance (modèles de workflows, politiques de conformité, RBAC).
2. Le billet est la suite d'un article sur les pièges de l'adoption d'un portail (même éditeur) : confirmé.
3. Lecture agentique (interprétation du labo, pas de l'article) : « découvrabilité » devient « interface déclarative et catalogue interrogeables par machine » ; « automatisation + gouvernance » devient « garde-fous exécutables ».
Limite : l'article ne parle pas d'agents IA ; un portail humain n'est qu'une des surfaces.

## S2. Cycloid : « Internal developer portal best practices: a 5-step implementation framework » [V 2026-11-18 + https://www.cycloid.io/blog/internal-developer-portal-best-practices-a-5-step-implementation-framework/]
Article lu en entier ; **correction** : le cadre en cinq étapes est maintenant connu (l'extrait précédent ne donnait que l'étape 1, et la formulation « catalogue de services et formulaires » était approximative).
1. **Catalogue de services avant le libre-service** : sans catalogue, le libre-service est du « shadow IT avec un écran de connexion » ; chez Cycloid, les *Stacks* servent de catalogue (modèles adossés à Git, propriétaire, base de conformité).
2. **Modèles adossés à l'IaC dès le premier jour** : sans cela, le portail devient une source de vérité parallèle et dérive ; chaque action de provisionnement passe par Git (piste d'audit).
3. **Garde-fous FinOps dans le workflow de provisionnement** : coût estimé avant le déploiement, planification de démarrage/arrêt des environnements hors production.
4. **RBAC au niveau du modèle**, pas après le provisionnement : qui peut provisionner quoi, avant le clic ; organisations enfants pour l'isolation multi-locataire.
5. **Instrumentation DORA dès la mise en service** : fréquence de déploiement, délai de livraison, taux d'échec de changement visibles dès le premier déploiement.
Chiffres cités par l'article (à ne pas reprendre sans source primaire) : 40,9 % des initiatives d'ingénierie de plateforme sans valeur démontrée en 12 mois (State of Platform Engineering vol. 4) ; 21 % de dépenses cloud gaspillées (Harness, FinOps in Focus 2025) ; projection Gartner de 85 % d'organisations avec portail en 2028.
Biais : article d'éditeur, les « principes portables » sont illustrés par le produit Cycloid.
Lecture agentique pour le labo : les points 1, 2, 4 sont déjà le contrat (`apps/<nom>/app.yaml` en Git, `generated/`, classes d'autonomie) ; le point 3 correspond à `COST-FREE-TIER.md` ; le point 5 à `DATA-PLATFORM-METRICS.md` §A.

## S3. CNCF TAG App Delivery : Platforms White Paper [L]
URL : https://tag-app-delivery.cncf.io/whitepapers/platforms/ (source lue : https://github.com/cncf/tag-app-delivery/blob/main/platforms-whitepaper/latest/index.md)
1. Une plateforme est « la couche mince raisonnable » qui compose des capacités de fournisseurs (internes ou managés) selon les besoins de ses utilisateurs.
2. Attributs : plateforme comme produit ; expérience utilisateur cohérente via GUI, API, CLI, IDE ; documentation et onboarding (golden path = workflow + gabarit + doc) ; libre-service ; charge cognitive réduite ; optionnelle et composable ; sécurisée par défaut.
3. Exemple de libre-service : demander une base et recevoir localisation et identifiants par CLI ou formulaire.
4. Capacités à considérer : portails, API/CLI, golden paths, automatisation de build et de livraison, observabilité, infrastructure, données, messagerie, identité et secrets, sécurité et application de politiques, stockage d'artefacts.
5. Mesure : retour utilisateur continu, productivité, efficacité organisationnelle ; démarrer par les capacités fréquentes et indifférenciées (pipelines, bases, observabilité) avec quelques équipes pilotes.
6. Réduire la charge de l'équipe plateforme : couche la plus fine possible sur des implémentations managées.

## S4. CNCF Platform Engineering Maturity Model [L]
URL : https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/ (source : https://github.com/cncf/tag-app-delivery/blob/main/platforms-maturity-model/v1/index.md)
1. Cinq aspects évalués séparément : investissement, adoption, interfaces, opérations, mesure ; quatre niveaux (provisoire, opérationnel, scalable, optimisant).
2. Interfaces : de « processus sur mesure » à « outillage standard », puis « solutions en libre-service » (autonomie, peu de support) et « services intégrés ».
3. Niveau « interfaces : libre-service » : cohérence, découvrabilité et portabilité de l'expérience.
4. Chaque niveau coûte plus de budget et de temps : atteindre le plus haut n'est pas un but ; le résultat utile est la liste de ce qu'il faut améliorer.
5. Adoption par « attraction intrinsèque » (valeur évidente, docs et interfaces ergonomiques) plutôt que par injonction.

## S5. Spécification MCP : outils (révisions 2025-06-18 et 2026-07-28) [L]
URL : https://modelcontextprotocol.io/specification/2026-07-28/server/tools (source : dépôt `modelcontextprotocol/modelcontextprotocol`, `docs/specification/…/server/tools.mdx`)
1. Outil = nom unique + `description` + `inputSchema` JSON Schema + `outputSchema` optionnel ; résultats structurés (`structuredContent`) que le serveur DOIT rendre conformes au schéma.
2. Deux niveaux d'erreur : erreurs de protocole (JSON-RPC, outil inconnu, arguments invalides) et erreurs d'exécution dans le résultat avec `isError: true` (le modèle peut les lire et corriger).
3. Annotations de comportement (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`) ; les clients doivent les traiter comme non fiables sauf serveur de confiance.
4. Serveurs : valider toutes les entrées, contrôler l'accès, limiter le débit, assainir les sorties ; clients : confirmer les opérations sensibles, journaliser, appliquer des délais.
5. 2026-07-28 : MCP sans état (plus de session), `server/discover`, résultats avec `resultType`, ordre déterministe de `tools/list` et `ttlMs`/`cacheScope` pour le cache, propagation `traceparent` dans `_meta`, tâches longues en extension.

## S6. MCP : autorisation et bonnes pratiques de sécurité [L]
URL : https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization ; guide : https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices
1. Les jetons doivent être liés à une audience : le serveur n'accepte que les jetons émis pour lui ; le « token passthrough » vers une API aval est interdit (risque de député confus).
2. Minimisation des scopes : éviter les jetons « omnibus » (`*:*`) : rayon d'impact, révocation, bruit d'audit.
3. Le serveur peut annoncer par `WWW-Authenticate` le scope requis (moindre privilège).
4. Vérifier `iss` (RFC 9207), éviter les attaques de mix-up, valider les URI de redirection.

## S7. OpenGitOps : principes [L]
URL : https://opengitops.dev/ (source : https://github.com/open-gitops/documents/blob/main/PRINCIPLES.md)
1. État désiré déclaratif ; versionné et immuable ; tiré automatiquement par des agents ; réconcilié en continu.
2. Conséquence pour les agents IA : le canal d'écriture est une PR sur un dépôt, la boucle de réconciliation fournit la preuve d'application, l'historique Git sert d'audit et de retour arrière.

## S8. Backstage / Spotify : stratégies d'adoption et Software Templates [L]
URL : https://backstage.io/docs/overview/adopting ; https://backstage.io/docs/features/software-templates/ (source : dépôt `backstage/backstage`, dossier `docs/`)
1. Une équipe centrale possède le portail comme un produit : exploitation, adoption, bonnes pratiques encodées en templates, évangélisation.
2. Les templates encodent les pratiques de l'organisation et publient du code et de la configuration ; l'automatisation par « actions » composables.
3. Mode « dry run » des actions du scaffolder : simuler sans effet réel avant d'exécuter.
4. Le portail est une « plateforme de plateformes » : les équipes contributrices livrent leurs capacités par plugins et API.
5. Complément [E : non relu] (extraits InfoQ/Backstage) : le golden path de Spotify est un chemin « opiniâtre et supporté », non obligatoire ; l'écart reste possible. https://www.infoq.com/news/2021/03/spotify-paved-paths

## S9. Score : spécification de charge de travail [L]
URL : https://score.dev/ (source : https://github.com/score-spec/spec)
1. Fichier déclaratif unique, indépendant de la plateforme et de l'environnement : conteneurs, ports de service, `resources` (bd, dns, route) résolues par la plateforme cible.
2. « Étroitement délimitée » : décrit les propriétés de la charge, pas un remplacement du YAML de la plateforme.
3. Contrat dev/ops : si les exigences listées sont honorées, la charge tourne ; la plateforme sécurise les accès aux secrets.
4. Pertinence : modèle direct du contrat `apps/<nom>/app.yaml` (intention, pas manifestes).

## S10. Datadog : « Golden paths for AI agents » [V partiel 2026-11-18 + https://www.datadoghq.com/blog/golden-paths-for-ai-agents]
URL : https://www.datadoghq.com/blog/golden-paths-for-ai-agents ; compagnon : https://www.datadoghq.com/blog/ai-development-golden-paths
1. Les chemins conçus pour des humains doivent changer pour des agents : exécution synchrone et à faible latence.
2. Chemins « hybrides » : l'agent assure les étapes de jugement, des vérifications déterministes décident si le flux avance.
3. Un golden path dit quoi appeler et quand ; il ne rend pas à lui seul les capacités utilisables par un agent.
4. Distinction entre chemins (workflows préférés) et contrôles (skills, hooks, tests) qui maintiennent l'agent sur le chemin ; mesurer l'effet avant de généraliser (le chiffre « agents 13 % plus rapides » n'a pas été retrouvé sur la page lue : [NV]). Confirmé par la page : un golden path agentique se conçoit autour d'un « modèle d'exécution » (synchrone à faible latence pour le temps réel, durable et reprenable pour les tâches longues) et sépare les étapes probabilistes de l'agent des étapes déterministes (CI, politiques, autorisation, approbations) qui décident si le flux avance.
5. Un billet voisin (« Operating shared platforms at agent scale ») traite de l'exploitation de plateformes partagées à l'échelle des agents (non lu).

## S11. Anthropic : « Writing effective tools for agents » [V 2026-11-18 + https://www.anthropic.com/engineering/writing-tools-for-agents]
URL : https://www.anthropic.com/engineering/writing-tools-for-agents
1. Concevoir les outils pour des agents, pas comme des API pour développeurs.
2. Choisir quels outils construire (et lesquels ne pas construire), et les nommer avec des espaces de noms pour des frontières claires.
3. Retourner un contexte utile et économe en jetons ; décrire précisément les outils (le prompt de l'outil compte).
4. Messages d'erreur qui disent le format attendu ; boucles d'évaluation avec jeux de tests pour améliorer les outils.

## S12. Team Topologies (synthèse de Martin Fowler) [V 2026-11-18 + https://martinfowler.com/bliki/TeamTopologies.html : charge cognitive, libre-service, mode collaboration temporaire puis X-as-a-Service confirmés ; « plateforme viable la plus mince » non retrouvé dans les passages lus]
URL : https://martinfowler.com/bliki/TeamTopologies.html
1. But premier d'une plateforme : réduire la charge cognitive des équipes qui livrent (flux), pas seulement standardiser ou réduire les coûts.
2. Libre-service par défaut ; la collaboration avec l'équipe plateforme est temporaire, en attendant le mode « X-as-a-Service ».
3. « Plateforme viable la plus mince » : ne pas l'épaissir au-delà de l'utile.
4. Charge extrinsèque (déploiement, configuration) à retirer ; l'équipe plateforme a elle aussi une charge cognitive limitée.

## S13. Humanitec Platform Orchestrator et garde-fous pour agents [V partiel 2026-11-18 + https://humanitec.com/product : l'Orchestrator choisit le module Terraform selon environnement, projet et classe de ressource, « no human in the loop », RBAC et gouvernance ; déploiements par vagues et billet Qovery non relus : [E]]
URL : https://humanitec.com/product ; https://www.qovery.com/blog/policy-guardrails-ai-agents-infrastructure-automation-platforms
1. Couche de gouvernance entre ce que demande l'agent et ce qui est provisionné ; mêmes règles que le déclencheur soit un humain ou une IA.
2. Déploiements par vagues avec règles, pour contenir l'échec.
3. L'agent ne détient jamais d'identifiants bruts : il appelle un petit nombre d'opérations pré-approuvées.
4. Les garde-fous posés au niveau de l'orchestrateur ne se transmettent pas aux capacités individuelles : la plateforme doit les appliquer elle-même.

## S14. Google SRE : toil, automatisation, post-mortems sans blâme [V 2026-11-18 + https://sre.google/sre-book/eliminating-toil/ (toil : manuel, répétitif, automatisable, tactique, sans valeur durable, croît linéairement ; **plafond de 50 %**) et https://sre.google/sre-book/postmortem-culture/ (« Blameless postmortems are a tenet of SRE culture »)]
URL : https://sre.google/sre-book/table-of-contents/ ; atelier : https://sre.google/workbook/table-of-contents/
1. Toil = travail manuel, répétitif, automatisable, sans valeur durable ; plafond d'environ 50 % du temps sur l'opérationnel.
2. Idéal : systèmes « automatiques et non seulement automatisés » (ils se réparent).
3. Post-mortems sans blâme : analyser ce qui a échoué dans les processus et systèmes ; modèle standard ; changement culturel autant que technique.
4. Pertinence : toute panne d'agent donne une fiche d'incident et une correction du garde-fou, pas du prompt seul.

## S15. Open Policy Agent (OPA) [L, limité]
URL : https://www.openpolicyagent.org/ (source : https://github.com/open-policy-agent/opa)
1. Moteur de politique généraliste, projet CNCF gradué : application unifiée de politiques « sur toute la pile ».
2. Le dépôt OPA contient un `AGENTS.md` pour guider les PR assistées par IA : l'écosystème traite déjà les agents comme contributeurs.
3. Pour le labo, l'équivalent Kubernetes natif est déjà en place (ValidatingAdmissionPolicy, Kyverno selon `docs/KYVERNO-POLICY-CONTRACT.md`) ; OPA n'est cité que comme référence de politique-comme-code.

## S16. Billets sur les agents comme utilisateurs de plateforme [E : non relus le 2026-11-18]
- Warp : https://www.warp.dev/articles/internal-developer-platform-agentic-coding-tools ; Red Hat : https://www.redhat.com/pt-br/blog/why-developer-portals-matter-more-age-ai-agents ; DuploCloud : https://duplocloud.com/blog/agentic-internal-developer-platform/ ; SoftwareSeni : https://www.softwareseni.com/platform-engineering-2-0-rebuilding-for-the-agent-era ; PlatformCon : https://platformcon.com/sessions/agent-golden-paths-building-platform-guardrails-for-ai-that-operates-at-population-scale
1. Les agents demandent des environnements, ouvrent des PR et consomment des golden paths à vitesse machine, sans le jugement d'un développeur.
2. Taxonomie proposée humain / agent / hybride ; l'observabilité doit distinguer les changements d'agents de ceux des humains.
3. Erreurs lisibles par machine : entrée invalide, refus d'autorisation, limitation de débit, indisponibilité temporaire, rejet de politique non réessayable ; pour le réessayable, indiquer le délai.
4. Le portail devient un fournisseur de contexte (catalogue et templates exposés par MCP) ; les avis divergent sur l'obsolescence des portails.
Ces billets sont des positions de praticiens et de vendeurs, pas des études.

---

## Synthèse : principes pour un IDP opéré par des agents
Chaque principe renvoie aux sources ; **(labo)** indique l'état déjà observé dans le dépôt.

1. **Une intention déclarative minimale, pas des manifestes.** Un fichier court par application (image, port, taille, secrets par nom, exposition) ; la plateforme génère le reste. (S3, S9, S12 ; labo : `app.yaml` + `appgen`.)
2. **Git est le seul canal d'écriture durable.** L'agent propose par PR ; la réconciliation applique ; l'historique donne audit et retour arrière. (S7 ; labo : AGENTS.md.)
3. **Garde-fous exécutables, pas des consignes.** Schéma, CI, politiques d'admission, PSA, NetworkPolicy refusent ce qui est interdit même si l'agent se trompe ; un prompt n'est pas un contrôle. (S10, S13, S15.)
4. **Identité d'agent distincte, à moindre privilège.** Client dédié, rôle en lecture par défaut, portée par namespace/environnement, jetons liés à l'audience, pas de passthrough ni de scope « omnibus ». (S6, S13 ; labo : `openchoreo-agent-reader`.)
5. **Séparer lecture, proposition et application.** Classes AUTONOME / REVUE / MANDAT / INTERDIT selon l'irréversibilité et le rayon d'impact ; l'humain valide le public, les données, l'argent, le réseau. (S5, S8, S10 ; labo : platform-guardrails.)
6. **Retour machine-lisible et typé.** Erreurs qui distinguent entrée invalide, refus, quota, indisponibilité temporaire, rejet de politique ; message qui dit comment corriger ; conditions de statut (`Ready/Synced`) plutôt que du texte libre. (S5, S11, S16.)
7. **Idempotence et déterminisme.** Générateur reproductible (0 dérive à `check`), releases immuables, `tools/list` stable, mêmes entrées = mêmes sorties, rejeu sans effet de bord. (S5, S7 ; labo : appgen check, ComponentRelease.)
8. **Simuler avant d'agir.** Mode `plan`/dry-run, `evaluate_authz`, tests de refus rejouables, validation CEL avant rendu. (S8, S5.)
9. **Preuve runtime datée.** Chaque affirmation de succès s'accompagne d'une observation lue (statut, logs, métriques) avec date et cluster ; k3d n'est pas OKE. (S10, S14 ; labo : PASS/FAIL/NOT_TESTED/BLOCKED.)
10. **Chemins hybrides : jugement de l'agent, contrôle déterministe.** L'agent choisit l'archétype et écrit l'intention ; des vérifications automatiques décident si on avance. (S10.)
11. **Découvrabilité lisible par machine.** Catalogue, schémas de types, capacités par cluster et exemples exposés en fichiers ou outils (MCP, `get_*_schema`), pas seulement en pages de portail. (S1, S3, S11, S16 ; labo : `capabilities.yaml`, `schema/`.)
12. **Surface d'outils étroite et nommée.** Peu d'outils, bien décrits, par espace de noms, retours économes en jetons ; supprimer les outils d'écriture inutiles pour l'agent. (S11, S5.)
13. **La plateforme la plus mince.** Ne pas réimplémenter ce qu'un composant mature fait ; composer (OpenChoreo, CNPG, ESO, Argo) et réduire la charge de l'équipe plateforme. (S3, S12.)
14. **Sécurité par défaut, exceptions explicites.** Valeurs par défaut restrictives ; toute exception (`securityExceptions`) déclarée, motivée, revue. (S3 ; labo : `cell-restricted`.)
15. **Observabilité des agents eux-mêmes.** Audit « qui a fait quoi » avec distinction agent/humain et canal (`rest`/`mcp`), journal des appels d'outils, traces corrélées (`traceparent`). (S5, S16 ; OpenChoreo : `query_audit_logs`.)
16. **Boucle d'apprentissage sans blâme.** Chaque échec produit une fiche et un garde-fou amélioré (test, règle CI, schéma), pas seulement un prompt corrigé ; mesurer l'impact des changements de chemins. (S14, S10.)
17. **Réduire le toil de l'opérateur humain.** Les décisions REVUE doivent arriver avec preuves, diff et rollback prêts ; sinon l'humain devient le goulot. (S14, S12.)
18. **Autonomie progressive et mesurée.** Monter le niveau d'autonomie par catégorie après des preuves répétées ; ne pas viser le niveau maximal par principe. (S4, S10.)
19. **Chemin préféré, pas prison.** Golden path supporté, avec sortie documentée (archétype F, REVUE) pour ce qui ne rentre pas ; l'écart est visible, pas caché. (S3, S8.)
20. **Contrats versionnés et stables.** `apiVersion` du contrat, ajouts optionnels seulement, migrations explicites ; les agents lisent la version avant d'écrire. (S5, S9.)

## Non couvert (à faire quand l'accès réseau sera ouvert)
Lecture directe de S1, S2, S10 à S14 : **faite le 2026-11-18** (voir ci-dessus). Reste : S16, platformengineering.org (non joignable, aucune extraction obtenue) ; documentation Kratix et Humanitec (une page README Kratix seulement) ; Cloud Native Maturity Model : page d'accueil lue le 2026-11-18 (5 niveaux Build, Operate, Scale, Improve, Adapt ; version 4.0 bêta, quatre piliers People/Process/Policy/Technology, https://maturitymodel.cncf.io/), niveaux détaillés non lus ; billet « Building effective agents » d'Anthropic.
