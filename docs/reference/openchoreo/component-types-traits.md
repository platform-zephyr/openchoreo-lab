# ComponentType, ClusterComponentType, Trait, CEL

## À quoi ça sert
Un ComponentType est le gabarit plateforme qui transforme l'intention d'un Component en ressources Kubernetes. Il sépare l'interface développeur (schéma de paramètres) de la gouvernance (templates). Un Trait ajoute une capacité transverse (stockage, autoscaling, alertes) sans modifier le type.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/platform-abstractions/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/component-types/overview/

## Champs clés (ComponentType / ClusterComponentType, même spec)
| Champ | Sens |
|---|---|
| `workloadType` | `deployment` \| `statefulset` \| `cronjob` \| `job` \| `proxy` ; doit avoir une entrée `resources[].id` identique |
| `parameters.openAPIV3Schema` | valeurs fixées par le dev, figées dans la ComponentRelease |
| `environmentConfigs.openAPIV3Schema` | surcharges par environnement via ReleaseBinding |
| `allowedTraits[]` | `{kind, name}` des traits permis |
| `allowedWorkflows[]` | workflows de build permis (vide = aucun) |
| `resources[]` | `id`, `template`, `includeWhen` (CEL), `forEach`+`var` |
| `preRenderValidations` / `postRenderValidations` | règles CEL avant rendu / sur le rendu final après traits |
`ClusterComponentType` : pas de `metadata.namespace`. Un Component le référence avec `componentType: {kind: ClusterComponentType, name: deployment/service}` (le `kind` par défaut est `ComponentType` : toujours le poser).
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clustercomponenttype/

## Trait / ClusterTrait
- `parameters`, `environmentConfigs` (clé = `instanceName` dans `ReleaseBinding.traitEnvironmentConfigs`).
- `creates[]` : nouvelles ressources (PVC, ConfigMap, règles d'alerte).
- `patches[]` : opérations JSON Patch sur les ressources du type (`target.kind/group/version`, chemins avec filtre `containers[?(@.name=='main')]`).
- Un Component attache `traits: [{kind: ClusterTrait, name, instanceName, parameters}]` ; `instanceName` unique par composant, plusieurs instances possibles.
- Traits cités dans la doc : `persistent-volume`/`persistent-volume-claim`, `autoscaler`, `observability-alert-rule`, `api-management`.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/component-types/patching-syntax/

## CEL (templating)
Contexte : `metadata.*` (componentName, namespace, environmentName, labels, podSelectors), `parameters`, `environmentConfigs`, `workload` (container, endpoints, `toServicePorts()`), `configurations`, `dataplane`, `gateway.ingress.external/internal`, `environment`, `dependencies`, et dans un trait `trait.name`/`trait.instanceName`. Fonctions : `oc_omit()`, `oc_merge()`, `oc_generate_name()`, `oc_dns_label()`.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/component-types/templating-syntax/ ; https://openchoreo.dev/docs/v1.3.x/reference/cel/context-variables/ ; https://openchoreo.dev/docs/v1.3.x/reference/cel/built-in-functions/

## Validations
- Pré-rendu : cohérence des paramètres (`rule`+`message`, `${...}` interpolé dans le message).
- Post-rendu : garantit qu'aucun trait n'a défait une garantie (`target`, `rule`, `when`, `forEach` ; message non interpolé).
- Ne jamais coder un nom d'environnement en dur : la différence passe par `environmentConfigs`.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/component-types/validation-rules/

## Invariants et pièges
- Le schéma de paramètres est la seule surface développeur : tout champ requis sans `default` casse les composants existants.
- Un ClusterComponentType ne peut référencer que des ClusterTrait dans `allowedTraits` (kind explicite).
- Modifier un type produit une nouvelle ComponentRelease pour chaque composant concerné (le spec du type est embarqué dans la release).
- Défauts livrés : `deployment/service`, `deployment/web-application`, `cronjob/scheduled-task` (+ `worker` dans des exemples).

## Ce qu'un agent LLM doit savoir
- Lire le schéma avant d'écrire : MCP `get_component_type_schema`, `get_trait_schema`, ou `occ clustercomponenttype get`.
- Dans ce labo, le seul type est `service-restricted` (durci, copié du défaut) ; l'agent ne l'édite que par PR REVUE sous `platform/component-types/`.

## Écarts avec le dépôt
Aucun écart de fond : le skill `openchoreo-platform-engineer-gitops` (copier et durcir, `allowedWorkflows: []`, `postRenderValidations`, pas de nom d'env en dur) est cohérent avec la doc.
