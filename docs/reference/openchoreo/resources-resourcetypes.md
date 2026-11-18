# Resource, ResourceType, ClusterResourceType (infra managée)

## À quoi ça sert
Déclarer une dépendance d'infrastructure (base, cache, file, bucket) appartenant à un Project. Le développeur référence un ResourceType et donne des paramètres ; l'ingénieur plateforme écrit comment la provisionner et quelles sorties exposer. Nouveauté stabilisée en v1.3.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/developer-abstractions/ (section Resource)

## Objets
- `Resource` : `owner.projectName`, `type {kind: ResourceType|ClusterResourceType, name}` (immuables), `parameters`. Statut : `latestRelease {name: <resource>-<hash>, hash}`.
- `ResourceType`/`ClusterResourceType` : `parameters`, `environmentConfigs`, `resources[]` (templates data-plane : `id`, `includeWhen`, `readyWhen`), `outputs[]`, `retainPolicy` (`Delete` par défaut, ou `Retain`).
- `ResourceRelease` : snapshot immuable de Resource+type ; coupé par le contrôleur à chaque changement de l'un des deux.
- `ResourceReleaseBinding` : `owner {projectName, resourceName}`, `environment` (immuables), `resourceRelease` (non défini = binding en attente), `retainPolicy`, `resourceTypeEnvironmentConfigs`. Le contrôleur ne le crée ni ne le modifie jamais : la promotion est toujours explicite.
Statut binding : `outputs[]` résolus ; conditions `Synced`, `ResourcesReady`, `OutputsResolved`, `Ready`, `Finalizing` (raison `RetainHold` si `Retain`).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/resource-types/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/platform/resourcereleasebinding/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/application/resource/

## Sorties et consommation
Une sortie vaut `value` (littéral/CEL), `secretKeyRef {name,key}` ou `configMapKeyRef`. Seule la référence traverse le control plane ; le secret reste sur le data plane. Un composant déclare :
```yaml
dependencies:
  resources:
    - ref: ma-base
      envBindings: {host: DB_HOST, port: DB_PORT, password: DB_PASSWORD}
```
`fileBindings` monte une sortie `secretKeyRef`/`configMapKeyRef` en fichier. Le composant attend `Ready` du binding (render gate).
Source : https://openchoreo.dev/docs/v1.3.x/developer-guide/dependencies/resources/

## Suppression et rétention
Finalizer en deux phases : un Resource ne part qu'une fois ses bindings supprimés. Avec `Retain`, la suppression du binding bloque (`RetainHold`) jusqu'au passage à `Delete` ; l'état data-plane persiste.
MCP : `delete_resource_release_binding` respecte le même garde-fou.

## Invariants et pièges
- Les exemples livrés (`postgres`, `valkey`, `nats` : StatefulSet dans le cluster) ne sont pas destinés à la production ; la doc recommande des provisioners type Crossplane, ACK ou opérateurs natifs. Le labo utilise un ClusterResourceType `cnpg-lab-db` (CNPG).
- Il n'existe pas de sauvegarde/restauration native : à construire autour (voir `docs/research/CONSOLIDATION.md`).
- Valider les paramètres : un échec apparaît dans les conditions de la Resource, pas à l'`apply`.

## Ce qu'un agent LLM doit savoir
Lire les outputs déclarés (`get_resource_type`) avant d'écrire `envBindings`. Ne pas utiliser `create_resource_release_binding`/`update_resource_release_binding` (MCP) : ce serait une écriture cluster hors Git.

## Écarts avec le dépôt
- Cohérent : le skill dit « ResourceRelease jamais dans Git, pin par 2e PR (`appgen pin-resource`) » ; la doc confirme que le contrôleur ne pin jamais (binding « pending » sans `resourceRelease`).
- Le skill cite `occ resource promote` comme interdit ; aucune commande `resource*` n'apparaît dans la référence CLI v1.3.x lue (la promotion documentée = patch de `spec.resourceRelease`, ou MCP `update_resource_release_binding`). À revérifier sur le binaire 1.3.3.
