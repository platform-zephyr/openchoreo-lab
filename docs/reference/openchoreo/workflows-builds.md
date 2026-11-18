# Workflows et builds (Argo Workflows, workflow plane)

## À quoi ça sert
Exécuter builds et automatisations dans un plan dédié. Un `Workflow` est un gabarit (schéma de paramètres + modèle Argo avec expressions CEL) ; un `WorkflowRun` en est une exécution. Les builds de composants sont des Workflows « component » ; il n'existe pas de CRD séparée.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/workflows/overview/

## Objets
- `Workflow` / `ClusterWorkflow` : `parameters.openAPIV3Schema` (surface développeur), `runTemplate` (Argo Workflow inline composant des `ClusterWorkflowTemplate` par `templateRef`), `resources[]` (ex. ExternalSecret créé à côté), `externalRefs[]` (SecretReference résolue : `${externalRefs['id'].spec...}`), `ttlAfterCompletion`. Contexte CEL : `metadata.workflowRunName`, `metadata.namespaceName`, `parameters.*`.
- Moteur : Argo Workflows uniquement. WorkflowPlane/ClusterWorkflowPlane connecté par la même WebSocket mTLS.
- Workflow « component » : label `openchoreo.dev/workflow-type: "component"`, listé dans `ComponentType.allowedWorkflows`, référencé par `Component.spec.workflow`. Extensions de schéma `x-openchoreo-component-parameter-repository-url|branch|commit|app-path|secret-ref` pour l'auto-build et l'UI.
- `WorkflowRun` : impératif ; conditions `WorkflowRunning/Completed/Succeeded/Failed`, statut des tâches. À ne pas mettre dans un dépôt GitOps (créer par webhook, UI, `occ`).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/workflows/ci-governance/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/application/workflowrun/

## Chaînes de build disponibles
- Build natif : Docker (Podman), Google Cloud Buildpacks, React/nginx ; le dernier maillon crée le Workload (descripteur `workload.yaml` dans `appPath`). `autoBuild: true` + webhook Git (secret de webhook côté plateforme).
- Build-and-release GitOps (`docker-gitops-release`, `google-cloud-buildpacks-gitops-release`, `react-gitops-release`) : construit l'image, pousse au registre, clone le dépôt GitOps, génère Workload + ComponentRelease + ReleaseBinding avec `occ` (mode file-system) et ouvre une PR `release/<composant>-<horodatage>`.
- `bulk-gitops-release` : génère les ReleaseBindings d'un lot de composants vers un environnement et ouvre une PR.
- CI externe : n'importe quel CI appelle `POST /api/v1/namespaces/{ns}/workloads` avec un jeton OAuth (client_credentials) ; exemples Jenkins et GitHub Actions.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/automations/build-and-release-workflows/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/workflows/external-ci/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/workflows/ci/auto-build/

## Invariants et pièges
- Un workflow qui n'est pas dans `allowedWorkflows` n'est pas utilisable par le composant.
- Les paramètres du dépôt, du registre et du dépôt GitOps sont fixés par l'ingénieur plateforme dans le `runTemplate`, pas par le développeur.
- Dépôt privé : secret git (`occ secret create ... --category git-credentials`, plan de workflow) ; nécessite la gestion de secrets activée ou ESO manuel.
- Le plan de workflow n'a besoin que de sorties réseau (registre, control plane).
- Logs d'un run terminé : `get_workflow_run_logs` MCP est live seulement ; archives via `query_workflow_logs` (observability).

## Ce qu'un agent LLM doit savoir
Le labo n'utilise pas le build depuis les sources (`allowedWorkflows: []`, images par digest). Si un jour l'agent doit builder, la voie alignée avec le labo est `*-gitops-release` : le build propose une PR, Git reste maître. `trigger_workflow_run` (MCP) est une écriture : MANDAT.

## Écarts avec le dépôt
- Les skills retirent « workflows » et « build depuis la source » du périmètre ; la doc offre pourtant un flux PR natif. Voir CONSOLIDATION (question ouverte).
- Le labo exige un digest : les workflows de build produisent des tags ; il faudrait épingler le digest en sortie de build.

## Exemple : composant avec workflow de build (forme de la doc)
```yaml
spec:
  componentType: {kind: ClusterComponentType, name: deployment/service}
  autoBuild: true
  workflow:
    kind: ClusterWorkflow
    name: dockerfile-builder
    parameters:
      repository:
        url: https://github.com/<org>/<repo>
        revision: {branch: main}
        appPath: /
      docker: {context: ".", filePath: "./Dockerfile"}
```
Source : https://openchoreo.dev/docs/v1.3.x/developer-guide/workflows/ci/overview/
