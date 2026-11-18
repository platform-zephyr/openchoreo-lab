# Environment et DeploymentPipeline

## À quoi ça sert
Un Environment est un étage du cycle de livraison relié à un data plane ; un DeploymentPipeline fixe les chemins de promotion autorisés entre environnements. Un Project référence un pipeline (`spec.deploymentPipelineRef`).
Source : https://openchoreo.dev/docs/v1.3.x/concepts/platform-abstractions/

## Environment (namespace-scopé)
| Champ | Sens |
|---|---|
| `dataPlaneRef {kind: DataPlane\|ClusterDataPlane, name}` | cible ; absent : repli sur DataPlane `default` du namespace, puis ClusterDataPlane `default`, puis le premier disponible |
| `isProduction` | drapeau de production (défaut `false`) |
| `gateway.ingress/egress.external/internal` | surcharge de gateway (`name`, `namespace`, listeners http/https/tls : `listenerName`, `port`, `host`) |
Conditions : `Ready`, `DataPlaneConnected`, `GatewayConfigured`. Annotation `defaultNotificationChannel` côté alertes.
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/environment/

## DeploymentPipeline
```yaml
spec:
  promotionPaths:
    - sourceEnvironmentRef: {name: development}
      targetEnvironmentRefs: [{name: production}]
```
`kind` par défaut `Environment`. Un chemin peut avoir plusieurs cibles. Condition `Available`. Annotations `display-name`, `description`.
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/deployment-pipeline/

## Multi-environnement natif
Pas de branches ni d'overlays Kustomize par environnement : un binding par env, mêmes releases, surcharges dans le binding. C'est ce qui permet d'attacher `development` et `production` à deux data planes (OKE et local) : voir `dataplanes-multicluster.md`.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/overview/

## Invariants et pièges
- La promotion n'est validée que par rapport au pipeline (`--use-pipeline` pour `releasebinding generate`) ; le pipeline lui-même ne déclenche pas de tests ni d'approbations (la doc parle de point d'intégration : à construire).
- Pas de nom d'environnement dans les types/traits : seule la config d'environnement diffère.
- Les conditions ABAC peuvent restreindre un agent à certains environnements (`resource.environment`) : voir `authz-identity.md`.

## Ce qu'un agent LLM doit savoir
`list_environments`, `list_deployment_pipelines`, `get_deployment_pipeline` (MCP, lecture) décrivent la topologie. Environment et pipeline sont des objets plateforme : modification par PR REVUE sous `platform/`.

## Écarts avec le dépôt
Le labo expose `environments: [development, production]` dans `app.yaml` et `cluster: k3d|oke` ; la doc, elle, rattache l'environnement à un data plane par `dataPlaneRef`. Le mapping environnement -> data plane (OKE/homelab) est donc un choix d'ADR à écrire (voir CONSOLIDATION).

## Exemple d'Environment avec data plane dédié
```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: Environment
metadata: {name: production, namespace: default}
spec:
  dataPlaneRef: {kind: ClusterDataPlane, name: oke-prod}
  isProduction: true
```
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/environment/
