---
owner: paul
updated: 2026-11-19
review_days: 30
---
# Démo native OpenChoreo : objets, exposition, écarts avec `app.yaml`

Date : 2026-11-19 · Ticket : T-498 · Statut : `STATIC` (doc et code amont lus ; aucun cluster touché ; rien déployé).
Suite de [OPENCHOREO-FIDELITE-ECARTS.md](OPENCHOREO-FIDELITE-ECARTS.md) (§E3, §E8) et
[OPENCHOREO-CHEMIN-NATIF.md](OPENCHOREO-CHEMIN-NATIF.md). Légende : **[L]** lu le 2026-11-19 ; **[D]** déduit ; **[H]** hypothèse.

Sources (contenu externe traité comme donnée) : `openchoreo/openchoreo` tag `v1.3.3` et `main` `774cc5d` (1.4.0-m.2),
Apache-2.0 [L] ; `openchoreo-playground/microservices-demo` `9a583e5`, Apache-2.0 (fork de Google) [L] ;
[catalogue d'exemples](https://openchoreo.dev/docs/getting-started/examples-catalog/) v1.3.x (aucune licence affichée,
« all rights reserved » : citer, ne pas copier) [L]. Console de démo en lecture seule : **non lue**. Elle répond 403 avec un
défi Cloudflare anti-robot ; je ne l'ai pas contourné et je ne me suis pas connecté.

## Conclusion d'abord

1. La démo amont (`samples/gcp-microservices-demo`, identique en v1.3.3 et sur `main`) utilise **6 kinds écrits à la
   main** : Project, ProjectReleaseBinding, Component, Workload, Resource, ResourceReleaseBinding. Les releases viennent
   des contrôleurs (`autoDeploy: true`). Aucun Trait, aucune SecretReference, aucun digest, aucune ressource CPU/RAM écrite.
2. Le découpage est **1 application = 1 Project ; 1 microservice = 1 Component + 1 Workload ; 1 dépendance de données =
   1 Resource**. Les liens passent par `Workload.spec.dependencies` (endpoints et resources) avec `envBindings`. Notre
   `app.yaml` reproduit ce modèle (`workloads[]`, `network.egress: [{app}]`, `database`) : la façade est fidèle.
3. L'IdP intégré (**ThunderID**, chart séparé `thunderid` 1.0.1, SQLite, 1 pod) **n'est pas obligatoire** : la doc v1.3.x
   dit qu'on peut le désinstaller après avoir configuré un IdP OIDC externe (`security.oidc.*`) [L]. OpenChoreo
   fonctionne donc **avec Authentik seul ou avec ThunderID seul** ; il n'a pas besoin d'Authentik.
4. **Rien de la démo ne passe tel quel sur OKE** : 11 pods pour 1 seul pod libre (32/33), et images Google `amd64` seules
   sur un cluster `arm64` (A1) [L]. Le homelab x86_64 est la seule cible réaliste.
5. Nos ajouts sont surtout **justifiés** (digest, egress, PSA, classe de donnée). Trois sont **à simplifier** :
   génération maison des releases, `profile`, `delivery` calculé (§3).

## 1. Objets natifs et découpage de la démo

| Objet | Nombre | Rôle dans la démo [L] |
|---|---|---|
| Project `gcp-microservice-demo` | 1 | Type `ClusterProjectType/default`, `deploymentPipelineRef: default` |
| ProjectReleaseBinding | 3 | Un par environnement (`development`, `staging`, `production`) ; possède la cellule (namespace) ; `projectRelease` semé par le contrôleur |
| Component | 10 | `deployment/service` (9, gRPC) ou `deployment/web-application` (frontend) ; `autoDeploy: true` |
| Workload | 10 | Image (tag, sans digest), endpoints, `dependencies.endpoints` (8 pour le frontend), `env` en clair |
| Resource `redis` + ResourceReleaseBinding | 1 + 1 | `ClusterResourceType/valkey` (StatefulSet 1 réplica, en mémoire) ; injecte `REDIS_ADDR` par `secretKeyRef` |
| Environment, DeploymentPipeline, types, traits | — | Prérequis de `samples/getting-started/all.yaml` (3 env., 4 CCT, 3 CRT, 5 traits) |
| SecretReference, Trait | 0 | Absents. La SecretReference apparaît dans `from-image/go-greeter-service` (jeton GitHub via ESO) |

Étapes manuelles : épingler `ResourceReleaseBinding.spec.resourceRelease` par `kubectl patch` ou
`occ resource promote` ; activer les traces par `kubectl patch workload` [L]. Le fork du « playground » ajoute
`insights-api` et `business-portal` (questions fixes, réponses composées par les outils MCP de l'observer, trait
`ai-mcp-federation`). Les manifests OpenChoreo de cette vitrine **ne sont pas** dans le dépôt [L]. Son README montre un
réglage natif utile : `ReleaseBinding.spec.workloadOverrides.container.env` pour une variable par environnement [L].

## 2. Exposition et authentification

- **Console** (Backstage) : client OIDC dédié ; un seul endpoint de la démo est `external` (frontend), servi par la
  passerelle du data plane (`*.openchoreoapis.<domaine>`) [L].
- **MCP** : `…/mcp` sur l'API du control plane et sur l'observer. OAuth 2.0 : client public PKCE (`user_mcp_client`) ou
  client confidentiel `client_credentials` (`service_mcp_client`), jeton 1 h [L]. Nous retirons déjà la liaison admin
  `mcp-tryout-client-binding` (`platform/install/values/openchoreo-control-plane.yaml`).
- **IdP** : ThunderID par défaut, « pour le développement et le test » selon la doc [L]. IdP externe = valeurs
  `security.oidc.{issuer,wellKnownEndpoint,jwksUrl,authorizationUrl,tokenUrl}` et `security.jwt.audience` (CP et
  observer), puis un client par consommateur : Backstage, `occ`, agent SRE, publication de Workload, observer [L].
  Notre brouillon `platform/identity/openchoreo-oidc-values.yaml` suit exactement ce chemin (Authentik, jamais appliqué).

## 3. Écarts entre `apps/<nom>/app.yaml` + `tools/appgen` et la démo

| Ce que nous ajoutons | Natif équivalent | Avis |
|---|---|---|
| Image avec `@sha256:` obligatoire | Tag libre | **Justifié** (chaîne d'approvisionnement) |
| CCT `service-restricted`, CPT `cell-restricted` (PSA restricted, default-deny, quota) | `service`, `default` | **Justifié** ; extension prévue par l'amont |
| `network.egress` (FQDN, CIDR, app) | Aucune politique réseau | **Justifié** ; `{app}` = `dependencies.endpoints` natif |
| `data.class`, `backup.*`, `securityExceptions[]` | Absents | **Justifié** (ADR-0008, PSA) |
| `runtime.size` small/medium | `environmentConfigs.resources` du CCT | **Justifié** (budget) ; garder la table dans le CCT |
| ComponentRelease, ReleaseBinding et pins générés par `appgen`, `autoDeploy: false` | Contrôleur (`autoDeploy`) ou `occ … --mode file-system` | **À simplifier** : déléguer à `occ` (déjà ALIGNER en §E3) |
| `profile` stateless/stateful | Déduit de `dependencies` et des traits | **À simplifier** : dériver, ne plus écrire |
| `delivery` calculé et vérifié | Absent | **À simplifier** : sortie d'`appgen`, pas un champ d'entrée |
| `cluster`, `capabilities.yaml` | DataPlane / Environment | Justifié tant qu'il y a 2 cibles (k3d, OKE, homelab) |
| `observability.metrics` (annotations) | Observability plane (non installé) | Justifié par le budget ; à revoir si l'observer arrive |
| `workloadOverrides` par environnement | Natif | **Manque chez nous** : exposer, ne pas réinventer |

## 4. Ce qu'on pourrait déployer tel quel (estimation, rien déployé)

| Candidat | Pods | CPU requis | RAM requise | OKE (1 pod libre, arm64) | Homelab x86_64 |
|---|---|---|---|---|---|
| Démo complète, env. `development` seul | 11 (10 + valkey) | ≈ 1,0 vCPU | ≈ 2,6 Gi (10 × 256 Mi + 128 Mi) | **Non** (pods, arch) | Oui [H], si on applique `all.yaml` ou ses types |
| Même démo sur 3 env. | 33 | ≈ 3 vCPU | ≈ 7,9 Gi | Non | Coûteux ; inutile |
| `from-image/go-greeter-service` | 1 | 0,1 vCPU | 256 Mi | Image multi-arch ; **mais** tag `latest`, secret GitHub, CCT `deployment/service` absent : refusé par nos règles | Oui après adaptation |

Chiffres = défauts du CCT `service` v1.3.3 (requests = limits = 100m / 256 Mi, 1 réplica) [L] ; la consommation réelle
n'est pas mesurée [H]. Sur OKE, la seule voie est de **remplacer** un pod existant, pas d'en ajouter.

## 5. Questions à Paul (recommandation en tête)

1. **Cible de la démo** : déployer la démo GCP sur le **homelab** seulement (recommandé), jamais sur OKE ?
   Lien : [gcp-microservices-demo](https://github.com/openchoreo/openchoreo/tree/release-v1.3/samples/gcp-microservices-demo).
2. **Types amont** : appliquer `all.yaml` (types non durcis) dans un projet isolé du homelab, ou porter la démo en
   10 `app.yaml` sur nos types durcis ? Recommandation : porter en `app.yaml` (preuve que la façade couvre un cas réel ;
   mesure le coût de la sécurité).
3. **IdP** : MISSION et ADR-0007 disent « Authentik, pas de ThunderID ». ThunderID reste épinglé dans
   `platform/install/versions.env`. Le garder seulement pour k3d/CI et le retirer d'OKE et du homelab (T-074) ?
   Recommandation : oui. Lien : [configuration de l'identité](https://openchoreo.dev/docs/platform-engineer-guide/identity-configuration/).
4. **Releases** : accepter que `appgen` délègue la génération des releases à `occ … --mode file-system` (moins de code) ?
   Recommandation : oui, après la porte ADR-0020.
5. **Console de démo** : elle est protégée par un défi Cloudflare. Voulez-vous la regarder vous-même et coller ce que
   montre « Delivery insights » ? Elle dépend de l'observability plane, que nous n'installons pas (budget).
