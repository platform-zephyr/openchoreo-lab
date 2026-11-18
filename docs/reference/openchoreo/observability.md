# Observabilité (observability plane)

## À quoi ça sert
Logs, métriques, traces, alertes, incidents, RCA, coûts, métriques DORA et journal d'audit des applications et de la plateforme, interrogeables par une API unique (Observer API), le portail, la CLI et le MCP d'observabilité. Plan optionnel : lean par défaut.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/observability-alerting/

## Architecture
- Collecteurs dans le data plane (logs, métriques, traces) -> stockage dans l'observability plane via des modules : logs et traces OpenSearch, métriques Prometheus (versions épinglées dans les constantes 1.3 : logs 0.7.0, tracing 0.8.0, metrics 0.8.0). Modules remplaçables (API d'adaptateur logs/métriques/traces).
- Observer API authentifiée par JWT (mêmes clients que le control plane ; `security.oidc.issuer/jwksUrl`).
- Un data plane se relie à un (Cluster)ObservabilityPlane via `observabilityPlaneRef` ; en multi-cluster, le plan distant s'enrôle comme les autres (agent + CA).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/modules/overview/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/multi-cluster-connectivity/

## Alertes, incidents, RCA
- Le trait `observability-alert-rule` crée des règles par composant ; paramètres d'environnement (`enabled`, canaux, `actions.incident.enabled`, `actions.incident.triggerAiRca`) dans `ReleaseBinding.traitEnvironmentConfigs`.
- CRD : `ObservabilityAlertRule`, `ObservabilityAlertsNotificationChannel` (e-mail, webhook ; variables `${environment}`, `${componentId}`, `${incidentEnabled}`, `${triggerAiRca}`).
- Alertes et incidents persistés (SQLite par défaut, PostgreSQL possible). L'RCA IA exige l'agent SRE et une clé LLM ; à activer seulement pour les alertes critiques (coût).
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/observability-alerting/

## Autres capacités
- Platform logs : logs de la plateforme et de tout ce que le plan collecte, adressés par coordonnées Kubernetes (cluster, namespace, pod, conteneur, labels) ; outil de l'ingénieur plateforme.
- Audit logging (beta) : qui/quoi/quelle ressource/résultat (`success|failure|denied`), canal (`rest|mcp`), catégories `management|authorization|access` ; index séparé, rétention propre ; interrogeable par `occ auditlogs` et `query_audit_logs`.
- Cost insights (OpenCost) et delivery insights/DORA (fonction « feature preview » : `observer.featurePreview.deliveryInsights.enabled`).
- Resource tree rules : règles de suivi des enfants d'un CRD dans l'arbre « View K8s Artifacts ».
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/platform-logs/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/audit-logging/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/delivery-insights/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/cost-insights/

## Invariants et pièges
- Dimensionnement : voir `install-upgrade-support.md` ; OpenSearch et un collecteur par data plane pèsent lourd sur un petit cluster.
- Les requêtes d'observabilité prennent des noms de ressources : lister d'abord via le control plane.
- Alertes dépendent d'un module logs/metrics ; sans plan, ni alertes ni RCA.
- L'audit est en beta (schéma susceptible de changer).

## Ce qu'un agent LLM doit savoir
Preuve runtime datée : `query_component_logs`, `query_http_metrics`, `query_resource_metrics`, `query_alerts` avec fenêtre horaire explicite ; `get_resource_tree` + `get_resource_events` côté control plane pour l'état du déploiement. Aucune écriture requise.

## Écarts avec le dépôt
- Le labo ne déploie pas l'observability plane (budget) ; l'observabilité OKE repose sur l'export Grafana Cloud existant (APP-CONTRACT §1 `spec.observability`). Les outils `query_*` du MCP et l'onglet Logs du portail ne fonctionnent donc pas sans ce plan.
- Conséquence : pas de RCA ni de DORA natifs ; à compenser par Grafana Cloud + preuves `golden-paths/_checks`.

## Exemple : surcharge d'alerte par environnement
```yaml
spec:                      # ReleaseBinding
  traitEnvironmentConfigs:
    high-error-rate-log-alert:      # instanceName du trait
      enabled: true
      actions:
        notifications: {channels: [devops-email-notifications]}
        incident: {enabled: true, triggerAiRca: false}
```
Sources d'alerte : `log` (motifs) et `metric` (CPU, mémoire) ; opérateurs de seuil (`gt`...). Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/observability-alerting/
