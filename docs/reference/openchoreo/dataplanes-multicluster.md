# DataPlanes et multi-cluster

## À quoi ça sert
Brancher un ou plusieurs clusters (OKE, homelab) sur un seul control plane. Chaque Environment pointe vers un (Cluster)DataPlane ; un agent dans le cluster distant ouvre une connexion WebSocket mTLS sortante vers la cluster-gateway du control plane.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/multi-cluster-connectivity/

## Objets
- `ClusterDataPlane` (cluster-scopé) / `DataPlane` (namespace) : `planeID` (doit égaler la valeur Helm `clusterAgent.planeId` ; défaut = nom du CR ; plusieurs CR peuvent partager un `planeID`), `clusterAgent.clientCA` (CA du certificat client de l'agent, `value` ou `secretKeyRef`), `gateway.ingress|egress.external|internal` (Gateway Kubernetes : `name`, `namespace`, listeners avec `host`, `port`), `secretStoreRef.name` (ClusterSecretStore ESO), `observabilityPlaneRef` (un ClusterDataPlane ne peut viser qu'un ClusterObservabilityPlane ; défaut : celui nommé `default`).
- Même famille pour `WorkflowPlane` et `ObservabilityPlane` (versions Cluster*).
Sources : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clusterdataplane/ ; https://openchoreo.dev/docs/v1.3.x/reference/api/platform/dataplane/

## Procédure d'enrôlement d'un data plane distant
1. Prérequis sur le cluster distant : Gateway API CRDs, cert-manager, External Secrets Operator, kgateway (data plane) ; Kubernetes 1.34+.
2. Control plane : ajouter le DNS (ou l'IP via `ipAddresses`, patch manuel du Certificate) de la gateway aux SAN (`clusterGateway.tls.dnsNames`), exposer `cluster-gateway-external` (LoadBalancer, ou TLSRoute en passthrough via kgateway avec `clusterGateway.tlsRoute`).
3. Extraire la CA du Secret `cluster-gateway-ca` (pas du ConfigMap) ; la copier dans un ConfigMap `cluster-gateway-ca` du cluster distant.
4. `helm upgrade --install openchoreo-data-plane` avec `clusterAgent.enabled=true`, `clusterAgent.serverUrl=wss://<hôte>/ws`, `clusterAgent.tls.generateCerts=true`, `serverCAConfigMap`, `caSecretName=""` (certificat client auto-signé).
5. Extraire `ca.crt` du Secret `cluster-agent-tls` distant (pas `tls.crt`) et la mettre dans `clusterAgent.clientCA` du (Cluster)DataPlane créé sur le control plane.
6. Créer/ajuster un Environment avec `dataPlaneRef`. Vérifier le log agent « connected to control plane ».
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/multi-cluster-connectivity/

## Invariants et pièges
- Le sens de connexion est agent -> control plane : aucun port entrant requis côté data plane pour l'API ; en revanche le trafic applicatif entre dans le data plane par sa gateway (port 443, domaine wildcard, certificat wildcard).
- `serverUrl` doit correspondre à un SAN du certificat de la gateway, sinon erreur TLS.
- L'API interne `:8444` de la gateway (mTLS interne activé par défaut) n'est jamais exposée par `cluster-gateway-external`.
- Une seule réplique de cluster-gateway par défaut ; le « gateway mesh » (HA) est une fonction pré-release, désactivée par défaut.
- Le cluster-agent a une ClusterRole limitée aux CRD OpenChoreo ; ajouter des droits pour tout CRD tiers (`cluster-agent-rbac`). Les kinds nommés dans les « resource tree rules » doivent être lisibles par l'agent.
- Gateways : un LoadBalancer par plan exposé en 443 (ou ports personnalisés si une seule IP).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/cluster-gateway-ha/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/cluster-agent-rbac/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/deployment-topology/

## Topologies décrites
Un seul cluster ; plans combinés ; clusters entièrement séparés (non recommandé en local). Plusieurs data planes dans un même namespace OpenChoreo sont prévus (chacun relié à un ou plusieurs Environments).

## Ce qu'un agent LLM doit savoir
Lecture seule : `list_dataplanes`, `get_dataplane` (santé, capacité), `occ clusterdataplane list/get`. L'enrôlement d'un cluster est un acte MANDAT (humain, Helm + secrets/CA) hors périmètre agent.

## Écarts avec le dépôt
- Déjà traité dans `docs/architecture/MULTI-DATAPLANE.md` (non modifié) : Cloudflare Tunnel HTTP rejeté (le TLS terminé chez Cloudflare empêche le certificat client d'atteindre la gateway), NetBird recommandé vers `cluster-gateway-external:8443`, un ClusterDataPlane et un `planeID` par cluster. La doc 1.3.x ne mentionne aucun de ces choix : ils sont compatibles avec elle.
- Divergence interne de la doc (« `secretStoreRef` résolu sur le control plane » dans la page multi-cluster, contre « ClusterSecretStore dans le data plane » dans la référence CRD) : déjà relevée par MULTI-DATAPLANE.md (le code passe seulement le nom au template) ; à prouver en runtime.
- Le dépôt mentionne le homelab comme « Talos » ; la doc n'impose aucun OS.

## Exemple : DataPlane enregistré (forme de la doc)
```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterDataPlane
metadata: {name: homelab}
spec:
  planeID: homelab
  clusterAgent: {clientCA: {value: "<PEM de ca.crt du Secret cluster-agent-tls>"}}
  gateway:
    ingress:
      external: {name: default-gateway, namespace: openchoreo-system, https: {host: apps.example.org, port: 443}}
  secretStoreRef: {name: default}
```
Source : https://openchoreo.dev/docs/v1.3.x/reference/api/platform/clusterdataplane/
