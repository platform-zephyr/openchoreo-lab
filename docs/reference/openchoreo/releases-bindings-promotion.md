# Releases, bindings et promotion

## À quoi ça sert
Séparer le contenu figé (release) de son placement par environnement (binding). Une même release immuable est promue dev -> prod sans dérive ; seules les surcharges d'environnement changent.
Source : https://openchoreo.dev/docs/v1.3.x/concepts/resource-relationships/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/deploying-applications/overview/

## Famille de bindings
| Release (immuable) | Binding (par env) | Surcharges |
|---|---|---|
| ComponentRelease `<comp>-<hash>` : snapshot Component+Workload+type+traits | ReleaseBinding | `componentTypeEnvironmentConfigs`, `traitEnvironmentConfigs`, `workloadOverrides` |
| ResourceRelease `<res>-<hash>` | ResourceReleaseBinding | `resourceTypeEnvironmentConfigs`, `retainPolicy` |
| ProjectRelease `<proj>-<hash>` | ProjectReleaseBinding | `environmentConfigs` |
Tous produisent un `RenderedRelease` appliqué au data plane de l'environnement.

## ReleaseBinding : champs
`owner {projectName, componentName}`, `environment`, `releaseName` (requis dans la référence CRD ; la doc de création le dit « optionnel pour auto-deploy »), `state` (`Active` | `Undeploy` : retire du data plane en gardant le binding), `workloadOverrides.container.env/files` (valeur ou `secretKeyRef`). Nom conventionnel `<composant>-<env>`. Conditions : `Ready`, `Deployed`, `Synced`.
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/releasebinding/

## ComponentRelease
Spec : `owner`, `componentType` (snapshot), `traits` (map), `componentProfile {parameters, traits}`, `workload {container, endpoints, dependencies}`. Tous les champs sont immuables. Annotation `openchoreo.dev/version` possible. Pour changer : nouvelle release (le contrôleur la coupe quand Component/Workload/type changent).
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/runtime/componentrelease/

## Déployer / promouvoir / revenir
```bash
occ component deploy <c> -n <ns> -p <proj>                 # première env, dernière release
occ component deploy <c> --release <release>               # release précise
occ component deploy <c> --to production --set spec.componentTypeEnvironmentConfigs.replicas=3
occ project deploy <p> --to staging                        # promotion du projet
```
En GitOps : promouvoir = committer le binding de l'env cible avec `releaseName` de l'env source ; revenir = repointer sur une release antérieure (conservées). `occ releasebinding generate --target-env E --use-pipeline P --all` (mode file-system) génère les bindings ; le workflow `bulk-gitops-release` fait de même et ouvre une PR.
Sources : https://openchoreo.dev/docs/v1.3.x/developer-guide/deploying-applications/deploy-and-promote/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/automations/bulk-promote/

## Invariants et pièges
- `autoDeploy: true` : le contrôleur écrit `releaseName` ; en GitOps cela crée une boucle avec l'outil de sync. Garder `false`.
- Un seul binding par (composant, environnement) (issue amont #5371 citée dans le dépôt).
- Les releases ne se suppriment que volontairement (`delete_component_release`, `delete_resource_release`) ; Argo doit être en `Prune=false`.
- `v1.4.0-m.2` (aperçu) introduit `ReleaseLine` ; non applicable à 1.3.3.

## Ce qu'un agent LLM doit savoir
Lire l'état : `get_release_binding` / `occ releasebinding list` -> conditions et `status.endpoints`. Ne pas utiliser `update_release_binding` pour un changement durable : PR sur `apps/<n>/app.yaml`, puis `appgen`.

## Écarts avec le dépôt
Cohérent avec `openchoreo-developer-gitops` (pin ResourceRelease, autoDeploy false, `ignoreDifferences` sur le seul `projectRelease`). Discordance interne de la doc sur `releaseName` obligatoire ou non : le labo le fournit toujours.
