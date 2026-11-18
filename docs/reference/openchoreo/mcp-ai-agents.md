# MCP et agents IA

## À quoi ça sert
OpenChoreo expose deux serveurs MCP (control plane et observability plane) pour que des assistants (Claude Code, Codex, Cursor, Gemini CLI, OpenCode, VS Code/Copilot) découvrent et opèrent la plateforme sous les mêmes contrôles d'accès que les humains. Il embarque aussi trois agents internes.
Sources : https://openchoreo.dev/docs/v1.3.x/ai/overview/ ; https://openchoreo.dev/docs/v1.3.x/reference/mcp-servers/

## Serveur MCP du control plane (HTTP, chemin `/mcp` de l'API)
Sept toolsets, tous actifs par défaut : `namespace`, `project`, `component`, `resource`, `deployment`, `build`, `pe`. Réglage : `--set-json 'openchoreoApi.config.mcp.toolsets=["namespace","project","component"]'`.
| Toolset | Lecture | Écriture |
|---|---|---|
| namespace | `list_namespaces`, `list/get_secret_reference` | `create_namespace` |
| project | `list_projects` | `create/update/delete_project` |
| component | `list/get_component`, `list/get_workload`, `get_*_schema`, `list/get_component_type`, `list/get_trait` | `create/patch/delete_component`, `create/update/delete_workload` |
| resource | `list/get_resource`, `list/get_resource_type(_schema)` | `create/update/delete_resource` |
| deployment | `list/get_release_binding`, `list/get_resource_release_binding`, `list/get_deployment_pipeline`, `list_environments` | `create/update/delete_release_binding` (`release_state: Active\|Undeploy`), `*_resource_release_binding`, `delete_component_release`, `delete_resource_release` |
| build | `list/get_workflow_run`, `get_workflow_run_status/logs/events`, `list/get_workflow` | `trigger_workflow_run`, `create_workflow_run` |
| pe | `list_dataplanes`, `list_workflowplanes`, `list_observability_planes`, `get_resource_tree`, `get_resource_events`, `get_resource_logs`, `list_authz_actions`, `evaluate_authz`, schémas de création | CRUD `component_type`, `trait`, `resource_type`, `workflow`, `authz_role(_binding)`, `secret_reference`, `environment`, `deployment_pipeline`, `create_component_release` |
Les outils plateforme prennent `scope: "cluster"` pour les ressources Cluster*. Il n'y a pas de mode « lecture seule » global : la lecture seule s'obtient par l'autorisation (voir `authz-identity.md`) et par le choix des toolsets.
Source : https://openchoreo.dev/docs/v1.3.x/reference/mcp-servers/

## Serveur MCP d'observabilité (Observer)
`query_component_logs`, `query_workflow_logs`, `query_http_metrics`, `query_resource_metrics`, `query_traces`, `query_trace_spans`, `get_span_details`, `query_alerts`, `query_incidents`, `query_costs`, `query_recommendations`, `query_dora_metrics`, `query_dora_deployments`, `query_audit_logs`, `query_platform_logs`. Tous en lecture. Utiliser d'abord les listes du control plane pour obtenir les noms de ressources.

## Connexion et authentification
OAuth2/OIDC : navigateur (client public PKCE `user_mcp_client`) ou `client_credentials` (client confidentiel de service) avec en-tête `Authorization: Bearer`. Avec un IdP externe, créer des clients dédiés. Piège connu : Claude Code récent refuse d'envoyer le jeton à un endpoint HTTP non-localhost ; un IdP en HTTP simple casse la connexion (contournement local seulement).
Sources : https://openchoreo.dev/docs/v1.3.x/ai/mcp-servers/ ; https://openchoreo.dev/docs/v1.3.x/ai/mcp-prompt-scenarios/

## Agents embarqués (observability plane / control plane)
- SRE Agent : RCA sur alerte (`triggerAiRca`), rapports ; clé LLM `RCA_LLM_API_KEY` dans le Secret `rca-agent-secret` ; fournisseur documenté : OpenAI.
- FinOps Agent : recommandations de dimensionnement (module OpenCost).
- Portal Assistant : chat Backstage en lecture seule par contrat, appelle les deux MCP.
Sources : https://openchoreo.dev/docs/v1.3.x/ai/sre-agent/ ; https://openchoreo.dev/docs/v1.3.x/ai/finops-agent/ ; https://openchoreo.dev/docs/v1.3.x/ai/portal-assistant/

## Invariants et pièges
- Chaque appel MCP est autorisé comme une requête API et audité (`surface: mcp`).
- Les outils `update_*` sont « remplacement complet » : un agent peut écraser des champs.
- Les écritures MCP contournent Git : INTERDITES ici (AGENTS.md). Elles ne servent qu'au diagnostic en lecture.

## Ce qu'un agent LLM doit savoir
Configurer le MCP avec un client dédié lecture seule (rôle `*:view`), ou ne charger que les toolsets nécessaires ; utiliser `get_resource_tree`, `get_resource_events`, `get_release_binding` et `query_*` pour les preuves runtime datées ; `evaluate_authz` permet de tester ce qu'une identité peut faire avant d'agir.

## Écarts avec le dépôt
Cohérent avec « pas de MCP en écriture ». Le dépôt note que le MCP OKE répond 401 sans jeton et que `openchoreo-agent-reader` n'est pas créé (docs/IDP-USABLE T2) : la doc confirme que le client doit exister dans l'IdP avec audience/claims acceptés par l'API.
