# Consolidation pour les ADR de la plateforme

Date : 2026-11-18. Entrées : `docs/reference/openchoreo/` (doc OpenChoreo v1.3.x, patch 1.3.3, lue dans le dépôt de la doc car `openchoreo.dev` était inaccessible) et `docs/research/IDP-AGENTIC-BEST-PRACTICES.md` (sources S1 à S16). Conclusion d'abord, puis détail. Les niveaux : **[D]** dit par la doc, **[L]** déjà prouvé ou décidé dans ce dépôt, **[S]** supposé à prouver. Aucun fait runtime n'est affirmé ici.

## 0. Conclusion
1. OpenChoreo couvre nativement le cœur d'un « IDP pour agents » : modèle déclaratif (Project/Component/Workload/Resource), releases immuables, promotion par bindings, multi-data-plane par agent sortant, autorisation RBAC+ABAC pour tous les clients (UI, CLI, REST, MCP), audit, observabilité. Il ne couvre pas : sauvegardes, bases de production, charts Helm tiers, exposition publique sans LoadBalancer, politiques d'admission, secrets générés, retour machine-lisible de bout en bout pour un agent.
2. La bonne frontière reste celle du dépôt : l'agent écrit une intention (`apps/<nom>/app.yaml`), la CI et `appgen` la valident et la génèrent, Argo applique ; le MCP ne sert qu'en lecture. La doc confirme que ce chemin est supporté (mode `file-system` d'`occ`, workflows qui ouvrent des PR) et que le MCP n'a pas de mode lecture seule.
3. Le levier de sécurité le plus rentable pour des agents est l'**autorisation OpenChoreo par rôle et condition** (client dédié `*:view`, ABAC par environnement) plus l'audit `query_audit_logs`, avant toute écriture MCP, même sous Cloudflare Access.
4. Trois points de la doc contredisent ou ne couvrent pas le dépôt et doivent être tranchés par ADR : l'IdP (Authentik seul, doc centrée ThunderID), la résolution de `secretStoreRef` en multi-cluster, et l'absence d'observability plane au budget actuel.

## (a) Capacités natives utiles

| Besoin | Ce que fait OpenChoreo 1.3.x [D] | Usage recommandé pour le labo |
|---|---|---|
| Déclarer une app simplement | `Component` + `Workload` (image, endpoints, `env`, `dependencies`) + `ComponentType` à schéma OpenAPI ; `occ component scaffold`, `workload create`, `componentrelease generate` en file-system | Garder `app.yaml` comme unique surface ; le schéma du type est le contrat plateforme (lu par `get_component_type_schema`). Étendre le type plutôt que d'ajouter des champs libres. |
| Dépendances et réseau | `dependencies.endpoints` (project/namespace), visibilités `project/namespace/internal/external`, NetworkPolicy dérivées ; `ProjectType` pour default-deny, quota, RBAC | S'appuie sur `cell-restricted` [L]. Cilium requis pour que les NetworkPolicy soient appliquées (OKE : gate Cilium [L]). |
| Multi data plane | `ClusterDataPlane` par cluster, `planeID`, agent sortant WebSocket mTLS, `Environment.dataPlaneRef`, 1 pipeline par chemin de promotion | Un ClusterDataPlane par cluster (OKE, homelab) [L : MULTI-DATAPLANE.md]. Chemin réseau du homelab : NetBird recommandé ; Cloudflare Tunnel HTTP inadapté (TLS terminé). |
| Promotion dev -> prod | `ComponentRelease` immuable + `ReleaseBinding` par env ; `DeploymentPipeline.promotionPaths` ; `occ releasebinding generate` ; workflow `bulk-gitops-release` (PR) ; retour arrière = repointer | Promotion = PR sur `app.yaml` (`environments`), conforme à D-2026-11-18 (dev/prod sur le même OKE). Écart G3 de SCHEMA-GAPS (même `releaseName` partout) à corriger dans `appgen`, pas dans OpenChoreo. |
| Secrets | `SecretReference` + ESO, `secretStoreRef` par plan ; sorties `secretKeyRef` de `ResourceType` (la valeur ne quitte pas le data plane) ; API `occ secret` optionnelle | Garder `features.secretManagement` désactivé ; secrets par nom dans `app.yaml`. Générer les mots de passe de bases sur le data plane (ExternalSecret + générateur) pour lever G9. |
| OIDC / identité | JWT validé par `security.oidc.*` (+ audience), types de sujet configurables, clients dédiés (CLI, MCP, CI, Backstage, Observer) | Un client Authentik par usage (portail, backend, agent-reader, agent-operator, CLI) [L]. Ajuster le claim de sujet des comptes de service [S]. |
| MCP / API pour agents | MCP control plane (7 toolsets, environ 110 outils) + MCP observability (15 outils) ; `evaluate_authz`, `list_authz_actions` ; schémas de création/validation ; REST identique | Exposer uniquement un client lecture seule ; limiter `openchoreoApi.config.mcp.toolsets` ; écrire par Git. Les outils d'écriture restent présents : seule l'authz les neutralise. |
| Observabilité | Observer API (logs, métriques, traces, alertes, incidents), `observability-alert-rule`, SRE Agent (RCA), audit (beta), coûts, DORA (preview) | Plan non déployé (budget) : compenser par Grafana Cloud et par les preuves `golden-paths/_checks`. `query_audit_logs` serait précieux pour attribuer les actions d'agents. |
| Workflows de build | Argo Workflows, `Workflow`/`WorkflowRun`, `*-gitops-release` (build + PR), CI externe via `POST /workloads` | Hors périmètre actuel (images par digest). Si on builde : seule la voie « build puis PR » garde Git maître. |
| Portail | Backstage préconfiguré, catalogue synchronisé (Domain/System/Component), scaffolder avec actions OpenChoreo | Vue humaine ; ne pas en faire un canal d'écriture agent (écrit via l'API). |

## (b) Limites et manques d'OpenChoreo 1.3.x, et ce qu'il faut ajouter autour

| Manque [D sauf mention] | Conséquence | À ajouter autour |
|---|---|---|
| **Stateful** : le type `statefulset` existe, mais les exemples de ResourceType (postgres, valkey, nats) sont des StatefulSet « non destinés à la production » | Pas de base de production prête | ClusterResourceType propre sur un opérateur (CNPG déjà choisi [L]) ; politique de rétention `Retain` ; volumes OCI 50 Go min. à valider (D1/D5). |
| **Sauvegardes / restauration** : aucune fonction native ; l'upgrade recommande un simple `kubectl get -o yaml` | Données irremplaçables refusées par la CI [L] | CNPG + barman vers un objet externe (R2) ; Velero optionnel ; preuve de restauration hors Oracle avant d'ouvrir `irreplaceable`. Déclarer `backup` dans `app.yaml` et le propager en label (G8). |
| **Pas de ResourceReleaseBinding automatique** : le contrôleur ne pin jamais une ResourceRelease | Une base = 2 PR [L] | `appgen pin-resource` ; envisager une automation de PR (bot) qui ouvre la 2e PR après `ResourceRelease` observée. |
| **Charts Helm tiers** : aucun concept natif (Component = workload défini par un ComponentType) | Parcours E illustratif seulement [L] | Garder Helm sous Argo, simplement référencé au catalogue ; durcir le namespace (PSA, NP, quota : G7) ou refuser (archétype F). Un ComponentType `proxy` ne remplace pas un chart. |
| **Politiques d'admission** : OpenChoreo n'en fournit pas hors validations CEL des types ; PSA/NetworkPolicy via ProjectType | Rien n'empêche un objet hors OpenChoreo | VAP natives + Kyverno (voie B) [L] ; CEL `postRenderValidations` des CCT/CPT ; ne jamais assouplir pour un test (AGENTS.md). |
| **MCP sans mode lecture seule** ; outils `update_*` en remplacement complet | Risque d'écrasement par un agent | Rôle `agent-reader` ; test automatique `evaluate_authz` (aucune action d'écriture) ; Cloudflare Access en plus [L]. |
| **Exposition publique sans LoadBalancer** : la doc suppose LoadBalancer par plan | Contraire au quota OCI [L] | Cloudflare Tunnel vers kgateway ClusterIP ; hôtes et `auth` rendus par `appgen` (G6). |
| **Pas d'approbation ni de tests dans DeploymentPipeline** (simple ordre de promotion) | Promotion = décision humaine hors OpenChoreo | PR de promotion en classe REVUE, preuve runtime comme condition de merge (CI ou Job). |
| **Pas de retour machine-lisible de haut niveau** : la santé passe par conditions et événements | Un agent doit agréger lui-même | Script `_checks/run-all.sh` en sortie JSON stable (verdict PASS/FAIL/NOT_TESTED, horodaté) ; schémas d'erreur appgen/CI typés. |
| **Ownership non natif** (annotation `backstage.io/owner`) | Pas de « qui est responsable de cette app » exploitable par agent | Champ `owner` d'`app.yaml` déjà dans le contrat [L] ; l'annoter sur Project/Component. |
| **Observabilité : stack lourde** (OpenSearch, collecteurs) ; audit en beta ; DORA en preview | Hors budget | Grafana Cloud, métriques des vérifs ; reconsidérer le plan quand D1 sera tranché. |
| **Upgrade** : une mineure à la fois, CRD appliquées à la main, bundle de sécurité privé pour les charts [L] | Procédure manuelle, risque de dérive | Runbook d'upgrade MANDAT ; job de contrôle de version (chart, CRD, tag) en CI. |
| **Doc centrée Flux** | Réglages Argo non documentés | Garder `Prune=false/Delete=false` sur releases et Resources, `ignoreDifferences` sur `projectRelease` [L]. |

## (c) Principes IDP agentique retenus (détail et sources : IDP-AGENTIC-BEST-PRACTICES.md)
1. Intention minimale déclarative, plateforme génératrice (S3, S9). Un fichier, un contrat versionné (`v2alpha1`), extensions optionnelles seulement.
2. Git unique canal durable ; PR + CI + réconciliation (S7). Aucune écriture cluster ni MCP en écriture.
3. Garde-fous exécutables : schéma, CI, VAP, PSA, NetworkPolicy, validations CEL (S10, S13, S15). Jamais « le prompt dit non ».
4. Identités d'agents distinctes et à moindre privilège ; jetons liés à l'audience ; pas de passthrough (S6, S13).
5. Classes d'autonomie selon la réversibilité (AUTONOME / REVUE / MANDAT / INTERDIT) (S5, S8, S10).
6. Retours typés et machine-lisibles (entrée invalide, refus, quota, indisponible, rejet de politique) et conditions de statut (S5, S11, S16).
7. Idempotence et déterminisme : `appgen check` sans dérive, releases immuables (S5, S7).
8. Simuler avant d'agir : `plan`, dry-run, `evaluate_authz`, tests de refus rejouables (S5, S8).
9. Preuve runtime datée, par cluster ; k3d n'est pas OKE (S10, S14).
10. Chemins hybrides : l'agent décide, des contrôles déterministes valident (S10).
11. Découvrabilité par machine : `capabilities.yaml`, schémas, catalogue, MCP en lecture (S1, S11, S16).
12. Surface d'outils étroite, nommée, économe en jetons (S11).
13. Plateforme la plus mince, composer des briques matures (S3, S12).
14. Audit distinguant agent/humain et canal ; fiche d'incident sans blâme pour chaque échec (S14, S16).
15. Autonomie progressive, mesurée ; chemin préféré avec sortie documentée (archétype F) (S3, S4, S8).

## (d) Questions ouvertes (à transformer en ADR ou issues)
Déjà ouvertes dans `docs/architecture/DECISIONS-OPEN.md` (D1 à D10, non répétées ici) : capacité OKE, OpenBao, Kyverno, Argo unique, volumes de drill, chemin réseau Talos, noms des data planes, catalogue fédéré, base Backstage, `identityProviders`. Nouvelles ou précisées par cette recherche :

1. **IdP unique Authentik et défauts du chart.** Quelle configuration exacte (`security.oidc.*`, `subjects`, claim de sujet des comptes de service, audience) pour que des jetons Authentik `client_credentials` soient reconnus par l'API, le MCP et l'Observer ? Où vit la liste complète de `authorization.bootstrap.mappings` (liste complète, écrasée par une surcharge) ? ThunderID reste-t-il installé par le chart par défaut et doit-il être désactivé ?
2. **Lecture seule MCP prouvée.** Quelles actions exactes un `agent-reader` doit-il avoir (`list_authz_actions`) ? Test automatique « aucune action d'écriture autorisée » ? Faut-il aussi retirer les toolsets `pe` et `build` ?
3. **`secretStoreRef`** : où l'ExternalSecret est-il rendu et résolu pour un data plane distant ? (Test déjà prévu dans MULTI-DATAPLANE ; attendre la preuve avant de figer l'emplacement des stores.)
4. **Observability plane** : le déployer réduit (logs + métriques, sans RCA) pour offrir `query_*` aux agents, ou rester sur Grafana Cloud ? Coût en mémoire du plan contre valeur des preuves natives et de l'audit `query_audit_logs`.
5. **Construire depuis les sources ?** Adopter le flux `*-gitops-release` (build + PR) avec un digest épinglé en sortie, ou rester sur images prébuildées par digest ? Impact sur `allowedWorkflows`, workflow plane (poids), registre.
6. **Promotion dev -> prod sur le même OKE** : un seul data plane pour deux environnements ou deux ClusterDataPlane logiques (même cluster, `planeID` distincts) ? Conséquence sur l'isolation, les quotas `dp-*` et la règle « `ReleaseBinding` unique par (composant, env) ».
7. **Rendre `ReleaseBinding.releaseName` par environnement** (G3) : `appgen promote` ou deux `app.yaml` ? Sémantique d'un retour arrière en production sans toucher le développement.
8. **Ressources et pin automatique** : automatiser la 2e PR de pin de `ResourceRelease` (bot) ou garder le geste agent ? Risque de pin d'une release mal rendue.
9. **Sauvegardes** : mécanisme exigé pour lever le refus d'`irreplaceable` (CNPG + R2 prouvé ?), fréquence, test de restauration ; qui détient le MANDAT.
10. **Charts Helm tiers** : activer le parcours E avec garde-fous rendus (G7) ou l'abandonner au profit d'archétypes natifs ? Un ComponentType `proxy` ou `statefulset` suffit-il pour quelques apps ?
11. **API de secrets d'OpenChoreo** : confirmer qu'elle reste désactivée ; exiger un test CI qui échoue si `features.secretManagement.enabled=true`.
12. **Audit** : activer l'audit (beta) sans observability plane ? Sinon, quel journal d'actions d'agents (GitHub PR, Argo, audit API) sert de preuve unique ?
13. **Upgrade** : règle « une mineure à la fois », CRD manuelles, `--reset-then-reuse-values` ; qui l'exécute (MANDAT) et comment éviter les `helm upgrade` directs interdits par le bundle de sécurité ?
14. **Version v1.4 (ReleaseLine)** : surveiller pour l'ADR de promotion ; aucune migration avant stabilisation (patch 1.4 stable).
15. **Backstage comme canal de demande** : un template qui ouvre une PR (action GitHub) sans écrire dans le cluster ? Ou renoncer au portail comme canal et garder `tests/idp-demo/run.sh` ?
16. **Lacune de collecte** : relire Harness, Cycloid et les sources S10 à S14 en entier quand le réseau est ouvert (sources imposées non lues, voir IDP-AGENTIC-BEST-PRACTICES §Méthode).
