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
Vérifié en ligne le 2026-11-18 contre https://openchoreo.dev/docs/ai/overview/ (v1.3.x) : **trois agents intégrés documentés** (section « Built-in Agents » : FinOps Agent, SRE Agent, Portal Assistant). **Aucun « architect agent » n'est documenté dans OpenChoreo** (pages overview, sre-agent, finops-agent, portal-assistant, mcp-servers, page produit « Agentic Developer Platform », sitemap du site : aucune occurrence). L'*Architect Agent* existe dans **WSO2 Choreo** (le produit SaaS, journal des changements du 2025-09-30 : il vérifie la conformité des API d'un projet aux règles de conception et de sécurité, https://wso2.com/choreo/changelog/architect-agent/) ; un article de presse (SD Times) attribue des agents « SRE, coût et architecture » à OpenChoreo 1.0, non confirmé par la documentation officielle : ne pas le compter. Le site mentionne aussi, côté écosystème, `agent-sandbox`, `agentgateway`, `wso2-agent-manager` (https://openchoreo.dev/ecosystem/…) : ce sont des modules, pas des agents intégrés.
- **SRE Agent** : RCA (analyse de cause racine) sur alerte (`triggerAiRca`), rapports de causes probables. Prérequis : observability plane avec au moins un module de **logs**, clé LLM, alertes avec `triggerAiRca` (« activer l'RCA automatique seulement pour les alertes critiques »). Secret `rca-agent-secret` (`RCA_LLM_API_KEY`, `OAUTH_CLIENT_SECRET` si IdP externe) dans `openchoreo-observability-plane`. Helm : `rca.enabled=true`, `rca.llm.modelName` ; **`rca.llm.baseUrl` (URL compatible OpenAI) permet de passer par le module `ai-gateway-agentgateway`**, la clé fournisseur étant alors gérée au gateway (valeurs de chart `release-v1.3`) ; `rca.llm.auth` (`api_key` par défaut, `azure` possible). Modèles documentés : série OpenAI GPT (gpt-5, 5.4, 5.6, 6-astra…), « autres fournisseurs bientôt ». Authentification `client_credentials` (rôle `rca-agent` à lier par `bootstrap.mappings`), stockage SQLite sur volume ou PostgreSQL. La page produit ajoute des actions de remédiation « avec approbation humaine ».
- **FinOps Agent** : rapports d'optimisation de coût et recommandations de dimensionnement ; prérequis : module de **métriques** + un module FinOps (ex. OpenCost), clé LLM OpenAI. Secret `finops-agent` (`LLM_API_KEY`). Helm : `finOpsAgent.enabled`, `finOpsAgent.llmName`, `finOpsAgent.remediationEnabled` ; rôle `finops-agent`. **Pas de `baseUrl` trouvé dans les valeurs de chart pour cet agent** : le routage par gateway n'est documenté que pour le SRE Agent et le Portal Assistant.
- **Portal Assistant** : chat Backstage **en lecture seule par contrat** (list, get, query ; les demandes d'écriture sont refusées), appelle les deux MCP et, si `portalAssistant.config.rcaAgentApiUrl` est renseigné, l'agent SRE. Déployé dans le control plane (`portalAssistant.enabled`, `portalAssistant.llm.secretName`, `portalAssistant.llm.modelName` au format LangChain `fournisseur:modèle`, **`portalAssistant.llm.baseUrl` optionnel**) ; fonction Backstage `backstage.features.assistant.enabled` (désactivée par défaut). Clé `PORTAL_ASSISTANT_LLM_API_KEY`.
- Ressources du SRE Agent (valeurs de chart) : requêtes 100m de CPU et 1 Gi de mémoire, limites 250m et 1,5 Gi.
Sources : https://openchoreo.dev/docs/v1.3.x/ai/overview/ ; https://openchoreo.dev/docs/v1.3.x/ai/sre-agent/ ; https://openchoreo.dev/docs/v1.3.x/ai/finops-agent/ ; https://openchoreo.dev/docs/v1.3.x/ai/portal-assistant/ ; https://openchoreo.dev/explore/agentic-developer-platform/ ; valeurs de chart : https://raw.githubusercontent.com/openchoreo/openchoreo/release-v1.3/install/helm/openchoreo-observability-plane/values.yaml et .../openchoreo-control-plane/values.yaml

## Invariants et pièges
- Chaque appel MCP est autorisé comme une requête API et audité (`surface: mcp`).
- Les outils `update_*` sont « remplacement complet » : un agent peut écraser des champs.
- Les écritures MCP contournent Git : INTERDITES ici (AGENTS.md). Elles ne servent qu'au diagnostic en lecture.

## Ce qu'un agent LLM doit savoir
Configurer le MCP avec un client dédié lecture seule (rôle `*:view`), ou ne charger que les toolsets nécessaires ; utiliser `get_resource_tree`, `get_resource_events`, `get_release_binding` et `query_*` pour les preuves runtime datées ; `evaluate_authz` permet de tester ce qu'une identité peut faire avant d'agir.

## Vérification du 2026-11-18
La liste des sept toolsets et celle des 14 outils `query_*` de l'Observer correspondent à https://openchoreo.dev/docs/reference/mcp-servers/ (pas d'écart relevé) ; le piège Claude Code / IdP en HTTP et le client `user_mcp_client` (PKCE) sont confirmés par https://openchoreo.dev/docs/ai/mcp-servers/. Les noms d'outils sont abrégés ici (`list/get_x`) : se référer à la page de référence pour les noms exacts.

## Écarts avec le dépôt
Cohérent avec « pas de MCP en écriture ». Le dépôt note que le MCP OKE répond 401 sans jeton et que `openchoreo-agent-reader` n'est pas créé (docs/IDP-USABLE T2) : la doc confirme que le client doit exister dans l'IdP avec audience/claims acceptés par l'API.
