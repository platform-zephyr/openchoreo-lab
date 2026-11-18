# Portail Backstage

## À quoi ça sert
Vue humaine du catalogue, du déploiement et de l'exploitation. OpenChoreo livre un portail (fork étendu de Backstage) préconfiguré, et des plugins `@openchoreo/*` installables dans un Backstage existant.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-plugins/overview/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-configuration/

## Catalogue synchronisé (poll toutes les 30 s par défaut)
| OpenChoreo | Backstage |
|---|---|
| Namespace | Domain |
| Project | System |
| Component | Component (`spec.type` = type OpenChoreo) |
| Environment, ComponentType, Trait, Workflow, plans | kinds personnalisés / entités d'infrastructure |
| API (schéma d'endpoint) | API |
Propriété : annotation `backstage.io/owner` sur Project/Component (pas de notion native d'ownership ; chaîne : composant -> projet -> `defaultOwner`).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-plugins/catalog-sync/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-ownership/

## Fonctions
- Onglets : Overview, Definition, Cell (diagramme), Deploy (état par environnement, overrides, promotion, « View K8s Artifacts »), Build, Logs, Metrics, Alerts, Incidents, RCA, Cost.
- Actions de scaffolder OpenChoreo (créer Project, Component, Resource...) pour écrire ses propres templates ; templates par défaut livrés dans le portail, non packagés pour un Backstage externe.
- Connexion OIDC avec le jeton utilisateur transmis à l'API ; politique de permission déléguant `openchoreo.*` à l'authz OpenChoreo.
- Secrets (Settings > Secrets) si `features.secretManagement.enabled`.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-scaffolder-templates/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-plugins/entity-views/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-plugins/permission-policy/

## Invariants et pièges
- Le portail écrit dans le cluster via l'API (création de composants, promotion) : c'est un chemin hors Git qui doit rester en lecture dans ce labo ou aboutir à une PR.
- Backstage a sa propre base (section « Database Configuration » de la doc), un secret de session (`backstage-backend-secret`) et des versions compatibles à respecter (matrice de compatibilité).
- Les templates de scaffolder utilisent des décorateurs de formulaire expérimentaux (`EXPERIMENTAL_formDecorators`).
- `kind: Domain` doit être autorisé dans `catalog.rules.allow`.

## Ce qu'un agent LLM doit savoir
Le portail n'est pas une surface agent : l'agent passe par Git (PR), la CI et la lecture MCP/`kubectl`. Il peut en revanche lire le catalogue (API du catalogue) pour retrouver propriétaires et relations.

## Écarts avec le dépôt
- IDP-USABLE : le portail du labo (étape 6b) n'est pas en service ; il est en lecture du catalogue sans template de création (pas de canal de demande agent). La doc confirme que les templates de création existent mais écrivent via l'API : pour un flux « demande = PR », il faudrait un template qui ouvre une PR (action GitHub du scaffolder) et non une création directe.
- Le dépôt génère un `catalog-info.yaml` par app (APP-CONTRACT) : la doc n'en parle pas ; à confronter à la synchro native des composants.

## Exemple : fréquence de synchro (app-config.yaml)
```yaml
openchoreo:
  defaultOwner: platform-team   # défaut : openchoreo-users
  schedule: {frequency: 30, timeout: 120}   # secondes, entiers (pas de HumanDuration)
catalog:
  rules:
    - allow: [Component, System, Domain, API, Resource, Location, Group, User]
```
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/backstage-plugins/catalog-sync/
