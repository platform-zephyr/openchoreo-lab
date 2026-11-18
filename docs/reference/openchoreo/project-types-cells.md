# ProjectType, ClusterProjectType et cellules

## À quoi ça sert
Donner un « foyer » à l'infrastructure partagée d'un projet par environnement : le namespace de cellule et ses garde-fous (default-deny réseau, ResourceQuota, RBAC, ImagePullSecrets). Avant v1.3, ces objets devaient vivre dans le template d'un composant.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/project-types/

## Champs clés
- `parameters`, `environmentConfigs` (schémas OpenAPI v3), `validations` (CEL, tout doit passer), `resources[]` (templates).
- Mandat : une entrée `v1/Namespace` dont `metadata.name` est `${metadata.namespace}` ; vérifiée sur le rendu. Absente ou masquée par `includeWhen` : binding `Synced=False`, raison `NamespaceMissing`, rien d'appliqué.
- Livré : ClusterProjectType `default` (namespace seul). Projets créés via API/UI sans type : `default`.
- Project : `spec.type` immuable. ProjectRelease `<project>-<hash>` coupé à chaque changement du type ou des paramètres.
- ProjectReleaseBinding : `owner.projectName`, `environment` (immuables), `projectRelease` (vide = amorcé une fois par le contrôleur avec la dernière release), `environmentConfigs` validées contre le schéma inclus dans la release épinglée.
- Conditions : `Synced`, `NamespaceReady`, `ResourcesReady`, `Ready`. `status.namespace` donne `dp-{ns}-{project}-{env}-{hash}`.
Sources : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clusterprojecttype/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/platform/projectreleasebinding/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/deploying-applications/project-releases/

## Promotion et retour arrière
Même geste que pour les composants : avancer/reculer `spec.projectRelease` (patch, PR Git, `occ project deploy --to <env>`, UI). Les composants et resources d'un environnement attendent la convergence du ProjectReleaseBinding.
`--set cle=valeur` fusionne dans `environmentConfigs`.

## Exemple minimal (ClusterProjectType)
```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterProjectType
metadata: {name: standard-project}
spec:
  parameters:
    openAPIV3Schema: {type: object, properties: {tier: {type: string, default: standard}}}
  environmentConfigs:
    openAPIV3Schema: {type: object, properties: {cpuQuota: {type: string, default: "4"}}}
  resources:
    - id: cell-namespace
      template:
        apiVersion: v1
        kind: Namespace
        metadata: {name: "${metadata.namespace}", labels: "${metadata.labels}"}
```
Le Project l'utilise avec `spec.type: {kind: ClusterProjectType, name: standard-project}` ; la valeur `cpuQuota` se règle dans le ProjectReleaseBinding de chaque environnement.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/project-types/

## Trafic entre cellules (rappel runtime)
Intra-cellule libre ; vers l'extérieur via passerelle d'egress ; entre projets via `dependencies.endpoints` en visibilité `namespace`. Le labo réduit encore : egress par liste blanche (FQDN L7 sous Cilium, CIDR L3/L4) déclarée dans `app.yaml`.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/runtime-model/

## Invariants et pièges
- Une édition du ProjectType n'affecte jamais les releases existantes ; elle coupe une nouvelle release à promouvoir.
- Les NetworkPolicy par composant générées par les ComponentTypes s'ajoutent à celles du ProjectType.
- Valeur rejetée par le schéma : visible dans les conditions du binding, jamais appliquée.

## Ce qu'un agent LLM doit savoir
Dans le labo, `cell-restricted` porte PSA, default-deny, quota, LimitRange et les paramètres `egress`, `database`, `allowIdp`, `egressFQDNs/CIDRs/Apps`. Ne jamais l'éditer pour faire passer un test (AGENTS.md : pas de contournement PSA/NP).

## Écarts avec le dépôt
Aucun. Noter que `ProjectReleaseBinding.spec.projectRelease` est le seul champ amorcé par un contrôleur : d'où `ignoreDifferences` côté Argo (APP-CONTRACT §0.4), conforme à la doc (« manifests qui omettent `projectRelease` ne se disputent pas avec l'amorçage en server-side apply »).
