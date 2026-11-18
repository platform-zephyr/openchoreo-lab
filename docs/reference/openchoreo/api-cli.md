# API REST, CLI `occ`, mode file-system

## À quoi ça sert
Les surfaces programmatiques d'OpenChoreo : l'API du control plane (utilisée par Backstage, `occ`, MCP) et la CLI `occ`, qui travaille soit contre l'API (`api-server`) soit directement sur des fichiers YAML (`file-system`, utile en GitOps).
Source : https://openchoreo.dev/docs/v1.3.x/reference/cli-reference/

## Configuration CLI
`~/.occ/config.yaml` : control planes, credentials, contextes (`namespace`, `project`, `mode: api-server|file-system`, `rootDirectoryPath`). Commandes : `occ config controlplane|credentials|context ...`.
Authentification : `occ login` (code + PKCE, interactif, client public, redirect `http://127.0.0.1:55152/auth-callback`) ou `occ login --client-credentials --client-id ... ` pour un compte de service (jetons JWT, `client_secret_post`). Avec IdP externe : `security.oidc.externalClients: [{name: cli, client_id, scopes}]`.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/cli-configuration/ ; https://openchoreo.dev/docs/v1.3.x/getting-started/cli-installation/

## Commandes (v1.3.x), regroupées
| Famille | Commandes |
|---|---|
| Ressources | `apply -f`, `namespace`, `project (list, get, delete)`, `component (list, get, delete, scaffold, deploy, logs, workflowrun)`, `workload create`, `componentrelease (generate, list, get, delete)`, `releasebinding (list, get, generate)` |
| Plateforme | `environment`, `deploymentpipeline`, `componenttype`/`clustercomponenttype`, `trait`/`clustertrait`, `workflow`/`clusterworkflow (run, logs)`, `workflowrun`, `dataplane`/`clusterdataplane`, `workflowplane`, `observabilityplane` (`logs` pour les plans), `authzrole`/`authzrolebinding` (+ Cluster*) |
| Secrets | `secret (create generic\|docker-registry\|tls, get, list, update, delete)`, `secretreference` |
| Audit | `auditlogs` (filtres acteur, ressource, résultat, période) |
| Dev local | `remote` : tunnel des dépendances d'un workload vers la machine (`--print-env`, `--no-secrets`) |
La page de référence 1.3.x ne liste PAS `project scaffold|deploy`, `projecttype`, `clusterprojecttype`, `projectrelease`, `projectreleasebinding`, `resource*` alors que d'autres pages (project-releases, gitops) les utilisent : la référence est incomplète ; lire `occ <groupe> --help` sur la version installée.
Source : https://openchoreo.dev/docs/v1.3.x/reference/cli-reference/

## Mode file-system (GitOps)
`componentrelease generate`, `releasebinding generate`, `workload create` ne fonctionnent qu'en mode file-system : ils écrivent des fichiers dans l'arborescence d'un dépôt (`--root-dir`, `--dry-run`, `--output-path`). C'est ce que `tools/appgen` appelle pour les ComponentRelease/ReleaseBinding (APP-CONTRACT §0.3).
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/gitops/automations/build-and-release-workflows/

## API REST
Points d'entrée sous `/api/v1/namespaces/{ns}/...` (ex. `POST .../workloads`), authentifiés par JWT (Bearer) ; le schéma JSON des composants/workloads est servi (`get_*_schema`). La même couche d'authz s'applique à REST, CLI, Backstage et MCP, et chaque écriture est auditée avec `surface: rest|mcp`.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/workflows/external-ci/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/audit-logging/

## Invariants et pièges
- `occ login` est interactif : à ne pas ouvrir par un agent. Compte de service sinon.
- `occ apply`, `occ component deploy`, `--set` écrivent dans le cluster : interdits à l'agent pour tout changement durable (AGENTS.md).
- `occ releasebinding generate` exige `--target-env` et `--use-pipeline`.

## Ce qu'un agent LLM doit savoir
Lecture : `occ <kind> list|get -o yaml`, utile pour des preuves. Génération hors-cluster : `--dry-run`/file-system seulement, via `appgen`.

## Écarts avec le dépôt
- Le skill interdit `occ resource promote` : absent de la référence 1.3.x lue ; vérifier sur le binaire.
- Le skill tolère `occ ... get` en lecture si une session existe ; `occ login` (jeton utilisateur) reste à éviter pour un agent (voir `authz-identity.md`).
