# Contrat multi-Data Plane (OKE + Talos)

Statut : **PROPOSÉ** (2026-11-17). Rien n'est déployé sur Talos ; aucun accès Talos n'est demandé.
Sources : docs OpenChoreo v1.3.x `platform-engineer-guide/multi-cluster-connectivity.mdx` (abrégé MCC), code `openchoreo` v1.3.3.

## 1. Conclusion

- **Un `ClusterDataPlane` par cluster** (`oke`, `talos`), chacun avec son `planeID`, sa CA d'agent et ses Environments.
- L'agent de chaque Data Plane **ouvre la connexion en sortie** vers le cluster-gateway du CP sur OKE (WebSocket, mTLS de bout en bout). Le CP n'a **aucun kubeconfig** des Data Planes, et il n'existe pas de cluster-admin partagé.
- Pour Talos, il faut un chemin **L3/L4 sans terminaison TLS** du homelab vers le cluster-gateway d'OKE. Recommandation : **NetBird** (déjà prévu pour l'accès admin, kube-ops `netbird-router`). Une route HTTP Cloudflare Tunnel **ne convient pas**, car le TLS est terminé au bord et le certificat client de l'agent est perdu.
- Si la connexion est perdue, les workloads continuent de tourner ; seuls les changements, les journaux et l'`exec` sont suspendus. Pour révoquer un Data Plane, on change ou on retire la CA d'agent dans le CR.
- Reste à prouver : le chemin NetBird, le SAN du cluster-gateway, la résolution de `secretStoreRef` côté Data Plane, et le comportement nocturne (homelab éteint).

## 2. Contrat

| Règle | Contenu | Source |
|---|---|---|
| 1 cluster = 1 `ClusterDataPlane` | `metadata.name` = nom du cluster (`oke`, `talos`) ; `spec.planeID` identique et **unique**. Le gateway regroupe les CA par (type, planeID) : deux clusters ne partagent **jamais** un planeID | `plane_client_ca.go` `getAllPlaneClientCAs(planeType, planeID)` l.238 |
| Cluster-scoped | `ClusterDataPlane` (labo mono-locataire) ; `DataPlane` namespacé seulement pour isoler des équipes | MCC l.275-277 |
| Identité Kubernetes séparée | chaque agent tourne sous **son** SA local (`openchoreo-data-plane:cluster-agent-dataplane`), avec le RBAC réduit de `platform/cluster-agent/` appliqué **dans ce cluster**. Le CP ne détient aucun credential Kubernetes d'un Data Plane | `docs/CLUSTER-AGENT-RBAC.md` |
| Break-glass séparé | OKE : session Bastion + kubeconfig temporaire ; Talos : talosconfig/kubeconfig du homelab. Jamais partagé avec le CP ni entre clusters | kube-ops `oracle-a1/README.md` |
| mTLS serveur | l'agent fait confiance à la CA `cluster-gateway-ca` du CP (ConfigMap dans le Data Plane, lue depuis le **Secret**, pas depuis la ConfigMap du CP) | MCC l.160-181 |
| mTLS client | `clusterAgent.tls.generateCerts=true`, `caSecretName=""` : CA auto-signée **locale** au Data Plane, dont seul le `ca.crt` est copié dans `spec.clusterAgent.clientCA` (jamais `tls.crt`, jamais de clé privée) | MCC l.209-260 ; `platform/install/manifests/30-clusterdataplane.yaml.tmpl` |
| API interne isolée | le port `:8444` (proxy, exec, logs) a sa propre CA ; un certificat d'agent n'y donne aucun accès. **Seul** `cluster-gateway-external:8443` est exposé | MCC l.26-29, l.112-117 |
| Capacités déclarées | `clusters/<cluster>/capabilities.yaml` (lu par `appgen`) ; ce qui n'y figure pas est refusé | `docs/schema/capabilities.schema.json` |
| Environnements distincts | un Environment pointe vers **un** Data Plane (`spec.dataPlaneRef`) : `production` (OKE, aujourd'hui) ; `talos-production` (à créer). Pas de promotion OKE ↔ Talos par défaut (pipelines distincts) | `40-openchoreo-env.yaml` ; `environment_types.go` |
| Secrets | `secretStoreRef.name` est un **nom** injecté dans le rendu (`data.SecretStore`) ; les `ExternalSecret` rendus dans le Data Plane visent donc un `ClusterSecretStore` de ce nom, qui doit **exister dans chaque cluster** (ESO installé par cluster, avec un jeton ou un rôle propre) | `internal/pipeline/component/context/component.go` l.175-176 ; `secret-management.mdx` l.36-38 |

**Écart documentaire à prouver** : MCC l.53-55 affirme que `secretStoreRef` « est résolu sur le cluster du Control Plane ». Le code ne fait que passer le nom au template. Test : rendre une app avec secret sur le Data Plane Talos et vérifier où l'ExternalSecret est créé.

## 3. Capacités par cluster (`clusters/<cluster>/capabilities.yaml`)

| Champ (existant ou **proposé**) | OKE | Talos (proposé) |
|---|---|---|
| `metadata.name` | `oke` | `talos` (**le schéma est à étendre** : enum `[k3d, oke]`) |
| `cilium` | `true` (chaining, #1620) | `true` (Cilium du homelab) [à vérifier] |
| `storageClasses` / profils | `ephemeral` ; `fast-rwo` → `oci-bv` (50 Go min.) **seulement selon TARGET D1** ; pas de `bulk-rwo` | `fast-rwo`, `bulk-rwo` (OpenEBS LVM, `docs/storage/STORAGE-RECOMMENDATION.md`) |
| `databaseInstances` | aucune base applicative (voie A) | `lab-pg` (CNPG, sauvegarde barman R2) |
| `secretStore` | `lab-store` (Doppler), plus OpenBao | store propre au cluster, **même nom logique** si les rendus doivent rester portables |
| `identityProviders` | `authentik` (aujourd'hui `thunderid` : à corriger, `docs/IDENTITY.md` §1) | `authentik` |
| **proposé** `dataPlane` | `{name: oke, planeID: oke}` | `{name: talos, planeID: talos}` |
| **proposé** `gateway` | `{listeners: [19080, 19443], service: ClusterIP, publicExposure: cloudflared}` | idem, exposition par le cloudflared du homelab |
| **proposé** `policy` | `[psa, vap]` (+ `kyverno` en voie B) | `[psa, vap, kyverno]` |
| **proposé** `availability` | `always` | `scheduled` (éteint la nuit) : `appgen` refuse sur Talos une app `availability: always` |
| **proposé** `profiles` | `stateless` (+ `sqlite` si un volume est accordé) | `stateless`, `postgres`, `sqlite`, `bulk` |

Ces champs restent des **changements proposés** (schéma et `appgen`, hors de ce flux).

## 4. Chemin réseau Talos → Control Plane (aucun port entrant au homelab)

| Option | mTLS de bout en bout | Port entrant | Verdict |
|---|---|---|---|
| **NetBird** : routeur NetBird sur OKE qui annonce **seulement** le service `cluster-gateway-external:8443` ; pair NetBird au homelab ; ACL limitée au groupe des agents | oui (L3) | aucun (tout sort du homelab) | **recommandée** ; réutilise PLT-256 |
| Cloudflare Tunnel, nom d'hôte public HTTP | **non** : TLS terminé chez Cloudflare, le certificat client n'atteint pas le gateway | aucun | **rejetée** |
| Cloudflare Tunnel, réseau privé (WARP Connector au homelab ou `cloudflared access tcp` en sidecar) | oui (TCP) | aucun | repli ; plus de pièces mobiles, Access service token à gérer |
| LoadBalancer OCI / NodePort public | oui | — | **interdit** (quota LB 0, VAP anti-LoadBalancer) |
| `clusterGateway.tlsRoute` (passthrough kgateway) | oui | exige une entrée publique | sans objet sans LB |

Exigences côté CP (changement proposé dans les values du CP, au moment du raccordement de Talos, pas avant) :

- `clusterGateway.tls.dnsNames` doit contenir le nom joint par l'agent : un nom DNS NetBird, et **pas une IP**, car une IP SAN exige un patch hors Helm (MCC l.87-108).
- `clusterGateway.service.type` reste `ClusterIP`.
- Le cluster-gateway est **mono-réplica** (HA en pré-version, MCC l.32-34) : si le nœud OKE tombe, aucun Data Plane n'est pilotable, mais les workloads continuent de tourner.

## 5. Perte de connexion, révocation, rotation

| Situation | Comportement (1.3.3) | Source | Exigence du labo |
|---|---|---|---|
| Talos éteint la nuit | `status.agentConnection.connected=false`, message « No agents connected » ; les rendus en attente sont réessayés ; rien n'est supprimé côté Talos | `controller/clusterdataplane/controller.go` l.242 ; `dataplane_types.go` l.131-143 | les checks golden-path distinguent « Git/Argo OK, Data Plane hors ligne » d'une panne ; aucune alerte de nuit |
| Reconnexion | l'agent réessaie après `ReconnectDelay`, avec une gigue ≤ 750 ms | `cluster-agent/agent.go` l.28-31, l.192-201 | mesurer le délai de reprise au rallumage |
| Révocation | modifier `clientCA` → le gateway revalide et **coupe** les agents dont le certificat n'est plus signé ; supprimer le CR → plus d'autorisation | `cluster-gateway/plane_api.go` l.95-130 | procédure : PR qui change la CA, puis `connected=false` vérifié |
| Rotation du certificat d'agent | émis par le cert-manager **du Data Plane** (CA locale) ; changer de CA impose de mettre à jour `clientCA` | MCC l.237-260 | à tester sur k3d avant Talos |
| CP indisponible | les Data Planes continuent de servir ; aucun déploiement, ni journaux, ni `exec` | architecture | les apps Talos ne dépendent pas du CP pour **tourner** ; elles dépendent d'Authentik (OKE) pour l'OIDC |

## 6. Ce que le CP sur OKE implique pour Talos

- Talos ne reçoit jamais de connexion entrante du CP : tout passe par le tunnel ouvert par l'agent.
- Talos dépend d'OKE pour : **les changements** (CP), **l'identité** (Authentik) et le **catalogue** (portail). Il n'en dépend pas pour exécuter ses workloads, ni pour ses secrets, une fois les `Secret` matérialisés.
- Prérequis sur Talos (MCC l.42-49) : Gateway API CRD, cert-manager, ESO et kgateway, chacun installé par **l'Argo du homelab** (kube-ops), pas par OpenChoreo.
- Les cellules `dp-*` sur Talos héritent des mêmes CPT et VAP qu'OKE, plus Kyverno (matrice `docs/KYVERNO-POLICY-CONTRACT.md` quand elle existera).

## 7. Reste à prouver (dans l'ordre, après `whoami` sur OKE)

1. k3d : deux clusters k3d (CP + 1 Data Plane distant), enregistrement mTLS, révocation par changement de CA, coupure et reprise.
2. Emplacement réel de l'`ExternalSecret` rendu avec `secretStoreRef` (§2).
3. Chemin NetBird → `cluster-gateway-external` (SAN DNS, ACL, passage du mTLS).
4. Talos : Data Plane sans charge, `connected=true`, puis extinction nocturne simulée : aucun effet sur OKE.
5. Une app `talos-production` de bout en bout par GitOps, puis rollback.
