# Référence OpenChoreo condensée (pour agents)

- **Version documentée : v1.3.x, patch courant v1.3.3** (chart Helm `1.3.3`). Une version d'aperçu `v1.4.0-m.2` existe dans la doc ; elle n'est pas utilisée ici (voir `releases-bindings-promotion.md`).
- **Date de collecte : 2026-11-18.**
- **Licence de la doc :** le dépôt de la documentation (`openchoreo/openchoreo.github.io`) porte une licence **Apache-2.0** (fichier `LICENSE`) ; le pied de page du site indique « Copyright 2026 OpenChoreo Project Authors » (marques de la Linux Foundation). Les fiches ci-dessous sont des résumés originaux avec renvois aux sources, sans copie de longs passages.
- **Méthode et limites de collecte :** `openchoreo.dev` n'était pas joignable depuis la session (hôte hors liste réseau autorisée). Le contenu a été lu à la source dans le dépôt GitHub `openchoreo/openchoreo.github.io`, dossier `versioned_docs/version-v1.3.x/` (commit 147f573, 2026-11-17), dont la version contient 156 pages. Lues en détail ou en grande partie : vue d'ensemble, concepts, guide développeur (projets, composants, workload, dépendances, déploiement), types/traits, ProjectType/ResourceType, GitOps, secrets, multi-cluster, authz/identité, MCP/IA, workflows, CLI, observabilité (alerting, audit), upgrades, support, CRD clés. Seulement survolées (titres, en-têtes, extraits) : référence Helm (`reference/helm/*`), installation k3d et `on-your-environment` détaillées, air-gapped, `local-development`, tutoriels, plugins Backstage secondaires, pages CRD secondaires (traits, workflow plane, alert rules). Les URL citées suivent le motif Docusaurus `https://openchoreo.dev/docs/v1.3.x/<chemin>/` : **motif inféré, non vérifié en ligne**. Repli : `https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/<chemin>.md`.
- Connaissances locales non modifiées : `.agents/skills/openchoreo-developer-gitops/`, `.agents/skills/openchoreo-platform-engineer-gitops/`, `docs/APP-CONTRACT.md`. Chaque fiche se termine par « Écarts avec le dépôt ».

## Index
| Fiche | Contenu |
|---|---|
| [concepts.md](concepts.md) | Plans, hiérarchie des objets, cellule, chaînes de release |
| [component-types-traits.md](component-types-traits.md) | ComponentType/ClusterComponentType, Trait, CEL, validations |
| [projects-components-workloads.md](projects-components-workloads.md) | Project, Component, Workload, endpoints, dépendances |
| [resources-resourcetypes.md](resources-resourcetypes.md) | Resource, ResourceType, sorties, rétention (bases, caches) |
| [project-types-cells.md](project-types-cells.md) | ProjectType, namespace de cellule, quotas et réseau |
| [releases-bindings-promotion.md](releases-bindings-promotion.md) | Releases immuables, bindings, promotion, retour arrière |
| [environments-pipelines.md](environments-pipelines.md) | Environment, DeploymentPipeline, rattachement au data plane |
| [dataplanes-multicluster.md](dataplanes-multicluster.md) | DataPlane, cluster-agent, cluster-gateway, enrôlement distant |
| [secrets.md](secrets.md) | SecretReference, ESO, API de secrets |
| [workflows-builds.md](workflows-builds.md) | Workflow/WorkflowRun, builds, build-and-release par PR, CI externe |
| [api-cli.md](api-cli.md) | API REST, `occ`, mode file-system |
| [mcp-ai-agents.md](mcp-ai-agents.md) | Serveurs MCP (outils par toolset), agents embarqués |
| [gitops.md](gitops.md) | Organisation Git, Flux/Argo, promotion, bonnes pratiques |
| [authz-identity.md](authz-identity.md) | RBAC/ABAC, entitlements, IdP, comptes de service |
| [observability.md](observability.md) | Logs/métriques/traces, alertes, RCA, audit, coûts |
| [backstage-portal.md](backstage-portal.md) | Portail, catalogue, scaffolder, plugins |
| [install-upgrade-support.md](install-upgrade-support.md) | Prérequis, installation, upgrade, support, dimensionnement |

## Écarts transverses à retenir (détail dans chaque fiche)
1. Doc interne incohérente sur `ReleaseBinding.releaseName` (requis ou optionnel) et sur l'emplacement du `secretStoreRef`.
2. Référence CLI incomplète (`project scaffold|deploy`, `projectrelease*`, `resource*` absents de la page CLI alors qu'utilisés ailleurs) ; `occ resource promote` cité par le skill est introuvable dans la doc 1.3.x.
3. Le MCP offre des outils d'écriture sans mode lecture seule : la lecture seule se fait par rôle d'autorisation.
4. Doc centrée sur Flux ; le labo utilise Argo CD (réglages Prune/ignoreDifferences propres au labo).
5. Aucune fonction native de sauvegarde, de base de données de production, de chart Helm tiers ni de politique d'admission (voir `docs/research/CONSOLIDATION.md`).
