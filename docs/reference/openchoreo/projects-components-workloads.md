# Project, Component, Workload (côté développeur)

## À quoi ça sert
Les trois objets que décrit une application : le Project (frontière), le Component (unité déployable + référence de type/traits/workflow) et le Workload (ce que le composant exécute et ce dont il dépend).
Source : https://openchoreo.dev/docs/v1.3.x/concepts/developer-abstractions/

## Project
- `spec.deploymentPipelineRef` (requis), `spec.type` (requis, `ClusterProjectType`, immuable), `spec.parameters`.
- Hors API/UI, un Project appliqué par `kubectl` doit poser `spec.type` explicitement.
- `occ project scaffold <nom> --clusterprojecttype <t>` génère Project + un ProjectReleaseBinding par environnement du pipeline (`--no-bindings` pour omettre).
Sources : https://openchoreo.dev/docs/v1.3.x/reference/api/application/project/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/projects-and-components/creating-a-project/

## Component
| Champ | Sens |
|---|---|
| `owner.projectName` | projet parent |
| `componentType` | `{kind, name: <workloadType>/<type>}` |
| `parameters` | valeurs du schéma du type (figées en release) |
| `traits[]` | `{kind, name, instanceName, parameters}` |
| `workflow` | `{kind: ClusterWorkflow, name, parameters}` pour build depuis les sources |
| `autoDeploy` (défaut `false`) | déploie auto à la création/nouvelle release |
| `autoBuild` | build sur push Git (webhook) |
Statut : `latestRelease {name, releaseHash}`. Annotations : `openchoreo.dev/display-name`, `openchoreo.dev/description`.
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/application/component/

## Workload (un par composant, `owner` immuable)
- `container` : `image` (requis, tag ou digest), `command`, `args`, `env[]` (`key` + exactement un de `value`/`valueFrom.secretKeyRef`), `files[]` (`key`, `mountPath`, `value`|`valueFrom`).
- `endpoints` (map nommée) : `type` HTTP|gRPC|GraphQL|Websocket|TCP|UDP, `port`, `targetPort`, `visibility[]`, `basePath`, `schema`.
- Visibilité : `project` (implicite), `namespace`, `internal`, `external` (HTTPRoute sur la gateway externe + NetworkPolicy d'ingress).
- `dependencies.endpoints[]` : `{component, name, visibility: project|namespace, project?, envBindings{address,host,port,basePath}}` ; jusqu'à 50 ; la plateforme résout l'adresse, injecte les variables et ouvre le réseau. La visibilité de la cible doit être au moins aussi large.
- `dependencies.resources[]` : `{ref, envBindings, fileBindings}` (voir `resources-resourcetypes.md`).
Sources : https://openchoreo.dev/docs/v1.3.x/developer-guide/workload/overview/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/dependencies/endpoints/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/application/workload/

## Chemins de création (équivalents)
Backstage (formulaires/scaffolder), `occ apply -f`, `occ component scaffold`, MCP `create_component`/`create_workload`, API REST. Build depuis les sources : un `workflow` crée le Workload (descripteur `workload.yaml` optionnel : endpoints, env, fichiers, dépendances). Image prête : créer le Workload directement.
Source : https://openchoreo.dev/docs/v1.3.x/developer-guide/projects-and-components/creating-a-component/

## Invariants et pièges
- Exactement un de `value`/`valueFrom` par entrée env/file.
- Dépendance inter-projets : visibilité `namespace` des deux côtés, sinon « connection refused ».
- Les valeurs sensibles passent par `secretKeyRef` (nom d'une SecretReference) : voir `secrets.md`.
- `autoDeploy: true` fait réécrire `releaseName` par le contrôleur : incompatible avec un GitOps où Git est maître.

## Ce qu'un agent LLM doit savoir
Dans ce labo l'agent n'écrit jamais ces objets : il édite `apps/<nom>/app.yaml` (contrat `v2alpha1`) et `tools/appgen` produit Project/Component/Workload (table dans le skill `openchoreo-developer-gitops`).

## Écarts avec le dépôt
- Doc : endpoint `visibility: external` = public Internet ; le labo l'expose via Cloudflare Tunnel vers kgateway ClusterIP (pas de LoadBalancer OCI) et classe l'exposition publique REVUE.
- Doc : `Workload.metadata.name` libre ; le labo impose `<n>-workload`.
