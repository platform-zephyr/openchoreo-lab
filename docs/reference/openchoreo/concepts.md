# Concepts OpenChoreo (vue d'ensemble)

Version documentée : v1.3.x (dernier patch listé : v1.3.3). Collecte : 2026-11-18.
Convention de sources : `https://openchoreo.dev/docs/v1.3.x/<chemin>/` (motif Docusaurus inféré ; le site était inaccessible depuis la session de collecte, le contenu a été lu dans le dépôt `openchoreo/openchoreo.github.io`, `versioned_docs/version-v1.3.x/<chemin>.md`, commit 147f573).

## À quoi ça sert
OpenChoreo est un IDP open source (Apache-2.0, issu de WSO2) au-dessus de Kubernetes : abstractions développeur (Project, Component, Workload, Resource) + briques plateforme (types, traits, workflows, environnements). L'état est déclaratif (CRD `openchoreo.dev/v1alpha1`), Kubernetes est le système d'enregistrement. Il expose un même plan de contrôle par portail Backstage, CLI `occ`, API REST et serveurs MCP.
Source : https://openchoreo.dev/docs/v1.3.x/overview/what-is-openchoreo/

## Les plans (multi-plane)
| Plan | Rôle | Contenu notable |
|---|---|---|
| Control plane | Cerveau : CRD, contrôleurs, API, authz, Backstage, cluster-gateway | ne fait pas tourner d'apps |
| Data plane | Cluster où tournent les workloads | cluster-agent (WebSocket sortant), kgateway, ESO, cert-manager |
| Workflow plane | Builds/automatisations (Argo Workflows) | optionnel, aucun port entrant |
| Observability plane | Logs, métriques, traces, alertes, Observer API | optionnel ; modules OpenSearch/Prometheus |
Tout peut tenir dans un cluster ou être réparti (voir `dataplanes-multicluster.md`).
Source : https://openchoreo.dev/docs/v1.3.x/concepts/platform-abstractions/ et https://openchoreo.dev/docs/v1.3.x/overview/architecture/

## Hiérarchie des objets
```
Namespace (label openchoreo.dev/control-plane: true)
 └ Project ── type: (Cluster)ProjectType ── deploymentPipelineRef
     ├ Component ── componentType: (Cluster)ComponentType, traits[], workflow
     │   └ Workload (1 par composant : container, endpoints, dependencies)
     └ Resource ── type: (Cluster)ResourceType (base de données, cache, file…)
```
Cluster-scopés par défaut : ClusterComponentType, ClusterTrait, ClusterResourceType, ClusterProjectType, ClusterWorkflow, ClusterDataPlane, ClusterWorkflowPlane, ClusterObservabilityPlane, ClusterAuthzRole(Binding). Variantes namespace-scopées pour surcharger/isoler.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/resource-relationships/

## Chaînes de déploiement (même schéma partout)
- Component -> ComponentRelease (immuable) -> ReleaseBinding (par environnement) -> RenderedRelease -> data plane.
- Resource -> ResourceRelease -> ResourceReleaseBinding -> RenderedRelease.
- Project (+ProjectType) -> ProjectRelease -> ProjectReleaseBinding -> namespace de cellule + NetworkPolicy/quota.
Détail : `releases-bindings-promotion.md`.

## Cellule (cell)
Un Project devient, par environnement, un namespace data-plane `dp-{ns}-{project}-{env}-{hash}` possédé par le ProjectReleaseBinding. Intra-cellule : libre ; inter-cellules : par passerelles (northbound/southbound/westbound/eastbound). Cilium (NetworkPolicy) et kgateway (Gateway API) sont les composants cités.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/runtime-model/

## Invariants et pièges
- Les références `type`, `owner`, `environment` des bindings sont immuables après création (supprimer/recréer pour changer).
- Un Component ne peut pas exister sans Project ; supprimer un Project supprime composants, workloads, releases, bindings (finalizer).
- Un Component n'est déployé qu'après `Ready` de ses Resources dépendantes (render gate).
- Les noms `{workloadType}/{componentTypeName}` : `deployment`, `statefulset`, `cronjob`, `job`, `proxy`.

## Ce qu'un agent LLM doit savoir
- Tout est objet Kubernetes lisible (`kubectl get`, `occ ... get`, MCP `get_*`) ; les conditions `Ready/Synced/...` sont le retour machine-lisible.
- Ne jamais créer les objets à la main dans ce dépôt : `apps/<nom>/app.yaml` -> `tools/appgen` -> `generated/`.

## Écarts avec le dépôt
- La doc cite Cilium comme moteur de NetworkPolicy ; sur OKE (`FLANNEL_OVERLAY`) les NetworkPolicy ne sont pas appliquées (APP-CONTRACT §0.6) : le gate Cilium reste nécessaire.
- La doc liste « quatre » types de workload puis cinq (proxy inclus) : lire cinq.
