# Secrets (SecretReference + External Secrets Operator)

## À quoi ça sert
Ne jamais mettre de valeur secrète dans Git : les workloads référencent une `SecretReference` qui décrit comment ESO synchronise un secret du store externe vers un Secret Kubernetes du data plane.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/secret-management/

## Objets
- `SecretReference` (namespace-scopé) : `targetPlane {kind: WorkflowPlane|ClusterWorkflowPlane|DataPlane|ClusterDataPlane, name}`, `template {type: Opaque|kubernetes.io/dockerconfigjson|..., metadata}`, `data[]` (clé -> référence distante `remoteRef`), `refreshInterval` (défaut `1h`).
- Le (Cluster)DataPlane porte `secretStoreRef.name` (ClusterSecretStore ESO). Pour changer de backend : remplacer le ClusterSecretStore (`default`) ; toutes les plans le référencent.
- Un Workload consomme via `env[].valueFrom.secretKeyRef {name: <SecretReference>, key}` ou `files[].valueFrom`. Une `ReleaseBinding.workloadOverrides` peut aussi référencer un secret.
Sources : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/secretreference/ ; https://openchoreo.dev/docs/v1.3.x/developer-guide/workload/overview/

## Installation
ESO est un prérequis autonome (chart `external-secrets` 2.0.1 dans la doc) à installer dans chaque cluster où des secrets sont synchronisés. Backends : Vault, AWS/GCP/Azure, OpenBao (mode dev local), etc. Secrets internes plateforme listés : `backstage-backend-secret`, `thunder-client-secret`, `cluster-gateway-ca`, `cluster-agent-tls`, `registry-credentials`.

## API de gestion des secrets (désactivée par défaut)
`features.secretManagement.enabled=true` (chart control-plane) ajoute `occ secret create|get|list|update|delete` et l'onglet Backstage Settings > Secrets. Les valeurs transitent par le control plane pour être écrites dans le store du plan cible ; seule la SecretReference y est stockée. Sinon : appliquer soi-même SecretReference + ExternalSecret.
MCP : lecture `list_secret_references`/`get_secret_reference` (développeurs) ; création/édition réservées au toolset PE.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/secret-management/#managing-secrets-through-the-ui-and-cli

## Invariants et pièges
- Les sorties de ResourceType sensibles sont des `secretKeyRef` : la référence seule transite.
- Les clés de store sont libres ; le labo impose un préfixe `<NOM>_` vérifié en CI.
- ESO doit exister avant le `ClusterSecretStore` (sinon CRD absente).
- Les secrets de CI (git, registre) ont une catégorie dédiée (`--category git-credentials`) et visent le plan de workflow.

## Ce qu'un agent LLM doit savoir
Ne jamais lire ni écrire une valeur. Dans `app.yaml`, `secrets[] {env, key, property}` ne contient que des noms ; `appgen` produit la SecretReference. Garder `features.secretManagement` désactivé : activer l'API ferait passer des valeurs par le plan de contrôle et par des sorties d'agent (contraire à AGENTS.md).

## Écarts avec le dépôt
- Cohérent : le labo utilise ESO + SecretReference (APP-CONTRACT §1 `secrets[]`), valeurs hors Git.
- À trancher : où vit le ClusterSecretStore sur OKE (Doppler/Vault/OCI Vault) et pour le data plane homelab ; la doc ne couvre que « un store `default` par cluster ».

## Exemple : SecretReference (forme de la doc)
```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: SecretReference
metadata: {name: ma-app-secrets, namespace: default}
spec:
  targetPlane: {kind: ClusterDataPlane, name: oke-prod}
  template: {type: Opaque}
  refreshInterval: 1h
  data:
    - secretKey: DB_PASSWORD        # clé dans le Secret Kubernetes
      remoteRef: {key: ma-app/db, property: password}   # chemin dans le store (aucune valeur ici)
```
Le champ exact de `remoteRef` se vérifie dans la page de référence. Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/secretreference/
