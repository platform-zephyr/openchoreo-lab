# Autorisation (RBAC/ABAC) et identité

## À quoi ça sert
Contrôler qui peut faire quoi, où, sur les objets OpenChoreo, pour tous les clients (UI, CLI, REST, MCP). L'authentification est OAuth2/OIDC ; l'autorisation est un RBAC déclaratif avec conditions CEL (ABAC).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/authorization/overview/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/identity-configuration/

## Modèle
- Sujet : « entitlement » = couple claim:valeur du JWT (`groups:platformEngineer`, `client_id:...`, `sub:...`, `email:...`).
- Action : `ressource:verbe` (`component:create`, `releasebinding:update`, jokers `component:*`, `*`).
- Hiérarchie : Cluster > Namespace > Project > Component ; portée (`scope.namespace/project/component`) ; les droits descendent, jamais ne remontent.
- Objets : `AuthzRole`/`ClusterAuthzRole` (liste d'actions) et `AuthzRoleBinding`/`ClusterAuthzRoleBinding` (sujet + rôle + portée + `effect: allow|deny`, défaut allow, + `conditions`).
- Évaluation par valeur d'entitlement : au moins un allow et aucun deny ; résultats réunis entre valeurs. Un `deny` bat les allow du même sujet.
- Conditions CEL : attributs `resource.environment`, `resource.componentType`, `resource.resourceType`, `resource.workflow` (ex. interdire `releasebinding:*` hors `development`).
- Autorisation activable/désactivable (`security.authz.enabled`) ; désactivée = tout autorisé.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/authorization/conditions/

## Identité
- IdP par défaut : ThunderID (dev/test) ; en production, un IdP OIDC externe via `security.oidc.{issuer, wellKnownEndpoint, jwksUrl, authorizationUrl, tokenUrl}` et optionnellement `security.jwt.audience` (contrôle `aud`), à poser sur le control plane et le plan d'observabilité.
- Clients OAuth à créer : Backstage, CLI (public PKCE), SRE Agent, workload-publisher (CI), Observer, clients MCP.
- Types de sujet (`openchoreoApi.config.security.subjects` et, en miroir, `observer.security.subjectTypes`) : `user` (claim `groups`) et `service_account` (claim par défaut `client_id` en v1.3). Les deux charts doivent rester alignés.
- Outils MCP/CLI : `list_authz_actions`, `evaluate_authz` (allow/deny + chaîne de bindings), `occ authzrole...`.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/authorization/

## Invariants et pièges
- Upgrade 1.2 -> 1.3 : le claim d'entitlement des comptes de service passe de `sub` à `client_id` (ThunderID 1.0.1) ; sans copie explicite des anciennes valeurs, les bindings de comptes de service cessent de correspondre.
- Un IdP qui nomme autrement les groupes (`roles`, etc.) impose d'ajuster les types de sujet.
- Bootstrap : `authorization.bootstrap.mappings` est une liste complète ; la surcharger écrase les défauts.
- Jetons JWT (pas opaques) exigés ; audience à valider si l'IdP la fournit.
- Les droits d'un binding ne remontent pas : prévoir des rôles supplémentaires pour voir environnements et objets de niveau namespace.

## Ce qu'un agent LLM doit savoir
Concevoir une identité d'agent à moindre privilège : client `client_credentials` dédié, rôle limité à `*:view` (+ actions précises), conditions par environnement, audit via `query_audit_logs`. Tester par `evaluate_authz` avant de brancher le MCP. Pas de jeton long vécu dans le dépôt ni dans les sorties.

## Écarts avec le dépôt
- Le dépôt s'appuie sur Authentik (homelab, éteint la nuit) pour OKE : dépendance de disponibilité absente de la doc ; il faudra poser `security.oidc.*` et choisir le claim de sujet pour un client Authentik [non prouvé].
- MISSION.md : Authentik est l'unique issuer OIDC et ThunderID n'est pas utilisé (APP-CONTRACT cite encore ThunderID pour l'OIDC des apps pilotes : incohérence à lever). La doc ne couvre que ThunderID par défaut et « tout IdP OIDC » en production : il faut surcharger `security.oidc.*`, les types de sujet et le claim des comptes de service (défaut `client_id` en 1.3) pour des jetons Authentik [non prouvé].
- Voir `docs/AGENT-IDENTITY.md` et `docs/IDENTITY.md` pour le détail local ; non relus ici.

## Exemple : agent en lecture seule (schéma de la doc, valeurs fictives)
```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRole
metadata: {name: agent-reader}
spec:
  description: lecture seule pour un agent
  actions: ["component:view", "project:view", "releasebinding:view", "resourcereleasebinding:view"]
---
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRoleBinding
metadata: {name: agent-reader-binding}
spec:
  entitlement: {claim: client_id, value: <client-id-de-l-agent>}
  roleMappings:
    - roleRef: {kind: ClusterAuthzRole, name: agent-reader}
  effect: allow
```
Liste exacte des actions disponibles : MCP `list_authz_actions`. Sources : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clusterauthzrolebinding/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clusterauthzrole/
