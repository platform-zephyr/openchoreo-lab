# GitOps avec OpenChoreo

## À quoi ça sert
OpenChoreo est « GitOps-natif » : tous les objets (plateforme et applicatifs) sont des CRD déclaratives qu'un agent de sync (Flux dans la doc, Argo CD dans ce labo) applique depuis Git. Les contrôleurs OpenChoreo ne dépendent pas de l'ordre d'application et dérivent les objets *Release/RenderedRelease.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/overview/

## Principes et organisation recommandés
- Quatre principes OpenGitOps (déclaratif, versionné et immuable, tiré automatiquement, réconcilié en continu).
- Cluster-scopé sous `platform-shared/` (CCT, CPT, ClusterTrait, ClusterWorkflow, ClusterDataPlane, ClusterAuthzRole...) ; par namespace sous `namespaces/<ns>/platform/` (environments, deployment-pipelines, secret-references...) ; applicatif sous `namespaces/<ns>/projects/<p>/{project.yaml, release-bindings/, components/<c>/{component.yaml, workload.yaml, releases/, release-bindings/}}`.
- Mono-dépôt (petites équipes) ou multi-dépôts (plateforme séparée des apps). Synchroniser `platform-shared/` avant le reste (`dependsOn` Flux, sync waves Argo).
- PR pour tout changement, CODEOWNERS sur `platform-shared/`, branches protégées, pas de secrets en clair.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/overview/

## Déploiement par releases
Promotion = committer/éditer le binding de l'environnement cible ; retour arrière = repointer sur une release antérieure. `occ` génère `workload`, `componentrelease`, `releasebinding` (file-system). Flux : `GitRepository` + `Kustomization` (`prune`, `targetNamespace`).
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/using-flux-cd/

## Automatisations livrées
Workflows `*-gitops-release` (build + PR) et `bulk-gitops-release` (promotion groupée par PR). Voir `workflows-builds.md`.

## Surveillance
Santé via les conditions des bindings (`Ready`, `Deployed`, `Synced`) ; surveiller l'outil de sync pour la dérive.

## Invariants et pièges
- Les objets impératifs (WorkflowRun) n'ont pas leur place dans Git.
- `ProjectReleaseBinding.projectRelease` omis : amorcé une fois par le contrôleur sans conflit en server-side apply.
- `ReleaseBinding` avec `autoDeploy` actif : conflit avec l'outil de sync.
- Conserver les releases (pas de prune) ; elles sont immuables et servent de retour arrière.
- Ne pas écrire dans le cluster pour un changement durable : la dérive se corrige par PR.

## Ce qu'un agent LLM doit savoir
Dans ce labo : `apps/<nom>/app.yaml` -> `generated/` (tools/appgen) -> Argo CD (ApplicationSet `lab-o`, Applications `lab-o-<app>`) ; `platform/` -> Argo (`lab-platform`, wave 0) ; CRD (`lab-crds`). Les skills `add-app`, `fix-app`, `promote-or-rollback` portent le geste ; la doc OpenChoreo ne dit rien d'Argo CD.

## Écarts avec le dépôt
- Arborescence : le dépôt n'utilise pas `namespaces/<ns>/projects/...` mais `generated/` produit par appgen ; équivalent fonctionnel.
- La doc suppose Flux ; le labo a choisi Argo (Prune=false/Delete=false sur releases et Resources, `ignoreDifferences` sur `projectRelease`) : réglages propres à Argo non documentés par OpenChoreo.
- Doc : les ReleaseBindings se génèrent par `occ` ; labo : appgen les appelle puis ajoute les garde-fous.

## Exemple : Kustomization Flux (doc) -> équivalent Argo
La doc synchronise `platform-shared` (sans `targetNamespace`) puis `namespaces/default/platform` (`dependsOn: platform-shared`, `prune: true`, `targetNamespace: default`). Avec Argo CD : deux Applications, sync waves (cluster-scopé en wave 0), `ServerSideApply`, `Prune=false` sur les releases. Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/using-flux-cd/
