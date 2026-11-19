---
owner: paul
updated: 2026-11-19
review_days: 30
---
# OpenChoreo 1.3.3 en usage normal : fonctionnement, déploiement sur OKE, test de Paul

Date : 2026-11-19 · Ticket : T-520 · Niveau : `STATIC` (doc et code amont lus ; aucun cluster touché).
Légende : **[L]** lu le 2026-11-19 ; **[D]** déduit ; **[H]** hypothèse. Les pages openchoreo.dev sans numéro de
version sont la version v1.3.x (version affichée par défaut le 2026-11-19) [L]. Code : tag `v1.3.3` (`5336791`).
Notes liées, à ne pas refaire : [DEMO-NATIVE](OPENCHOREO-DEMO-NATIVE.md), [CHEMIN-NATIF](OPENCHOREO-CHEMIN-NATIF.md),
[FIDELITE-JOURNAL](FIDELITE-JOURNAL.md), [POC-STRATEGY](POC-OPENCHOREO-STRATEGY.md).

## Conclusion d'abord

1. L'usage normal est simple : le développeur écrit un Component et un Workload (portail, `occ` ou YAML). Le
   contrôleur crée la release. Le développeur clique « Promote » ou tape `occ component deploy --to <env>` [L][dp].
2. Le portail, `occ` et le MCP **écrivent directement** par l'API du control plane. Aucun ne crée de PR [L][tpl][svc].
   Seuls les workflows GitOps amont (build-and-release, bulk-promote) ouvrent une PR [L][rel][bulk].
3. Le test de Paul est **BLOQUÉ** par deux prérequis absents sur OKE : le portail (étape 6b non faite) et un IdP
   avec des clients OIDC (aucun client Authentik n'existe) [L](../PORTAL.md)[L](../IDENTITY.md).
4. Notre `install.sh` suit l'ordre amont pour 9 étapes sur 14. Les étapes 0, 1, 10 et 11 sont des ajouts du labo ;
   l'étape 12 n'a aucun effet.
5. Six simplifications sont proposées (§4). Rien n'est exécuté. Paul décide après son test.

## 1. Fonctionnement normal

### 1.1 Plans [L][arch]

| Plan | Contenu | Obligatoire | Chez nous (OKE) |
|---|---|---|---|
| Control | API (`openchoreo-api`), contrôleurs, cluster-gateway, portail Backstage (même chart) [L][install] | Oui | Installé, portail absent |
| Data | Cluster-agent, passerelle des apps, namespaces `dp-*` [L][install] | Oui | Installé |
| Workflow (build) | Argo Workflows, templates de build [L][install] | Non [L][install] | Absent |
| Observabilité | OpenSearch, Prometheus, observer et son MCP [L][install] | Non [L][install] | Absent |

Sur un seul cluster, les plans sont séparés par namespace et parlent par ClusterIP. Chaque agent ouvre une
connexion sortante vers le cluster-gateway [L][topo]. L'amont cite 4 CPU et 8 Go pour un essai [L][topo].

### 1.2 Objets

- Développeur : Project, Component, Workload, Resource ; releases immuables (ComponentRelease, ProjectRelease,
  ResourceRelease) ; liaisons par environnement (ReleaseBinding et variantes) [L][abs].
- Plateforme : Environment, DeploymentPipeline, (Cluster)ComponentType, Trait, (Cluster)ProjectType,
  (Cluster)ResourceType, Workflow, ClusterDataPlane [L][abs][topo].
- Chaîne : Component → ComponentRelease → ReleaseBinding → Deployment, Service, HTTPRoute [L][dep].

### 1.3 Parcours développeur

| Canal | Lecture | Écriture | Effet |
|---|---|---|---|
| Portail | Catalogue, onglet Deploy, « View K8s Artifacts » (arbre, événements) [L][logs] | Templates (actions `openchoreo:*`), Promote, Undeploy [L][tpl][dp] | API directe, au nom de l'utilisateur [L][tpl] |
| `occ` | `get`, `list`, `component logs` (exige l'observabilité [L][logsgo]) | `apply -f`, `component deploy [--to env] [--release r]` [L][occcmd] | API directe [L][gitops] ; `--mode file-system` écrit des fichiers [L][rel] |
| MCP CP | `list_*`, `get_*` | `create_*`, `update_*`, `patch_component`, `delete_*`, `trigger_workflow_run` [L][mcpref] | API directe (`k8sClient.Create`) [L][svc] |
| MCP observer | 15 outils de requête [L][mcpref] | Aucun | Lecture seule |

- Templates : l'amont livre des templates pour Project, Namespace, Environment, pipeline et types. Il ne cite pas
  de template de Component par défaut [L][tpl]. Un golden path = un `template.yaml` écrit à la main [L][tpl].
- MCP : 7 toolsets (`namespace`, `project`, `component`, `resource`, `deployment`, `build`, `pe`). `?toolsets=` filtre
  la liste, pas les appels ; l'authz de l'API reste le vrai contrôle [L][mcpref]. Les outils de diagnostic
  `get_resource_tree`, `get_resource_events`, `get_resource_logs` sont dans `pe` [L][reg].
- GitOps recommandé : Flux CD, dépôt `platform-shared/` + `namespaces/<ns>/`, PR obligatoires, CODEOWNERS sur la
  partie plateforme. Promouvoir = changer la ReleaseBinding dans Git [L][gitops][flux]. Argo CD n'est pas cité [L][flux].
  `occ project deploy` écrit dans l'API : en GitOps, il faut committer le résultat [L][gitops].

### 1.4 Parcours plateforme

Installer les plans (§2). Appliquer environnements, pipeline et types (`samples/getting-started/all.yaml`) [L][all].
Écrire les ComponentTypes, Traits et templates. Lier les rôles d'authz [L][install][tpl].

### 1.5 Identité recommandée

ThunderID est l'IdP par défaut, « pour le développement et le test » [L][idp]. En production, l'amont recommande un
IdP OIDC externe (`security.oidc.*`). Il faut un client par consommateur : portail, `occ`, agent SRE, publication de
Workload, observer [L][idp]. Le MCP utilise `user_mcp_client` (PKCE) ou `service_mcp_client` [L][mcp]. On peut
désinstaller ThunderID après la bascule [L][idp]. MISSION impose Authentik, sans ThunderID [L](../../missions/MISSION.md).

## 2. Déploiement recommandé sur un cluster OKE, et écart avec `tools/oke/install.sh`

Ordre amont [L][install] : Gateway API CRD v1.5.1 → cert-manager v1.19.4 → ESO 2.0.1 → kgateway v2.3.11 → OpenBao +
ClusterSecretStore `default` → CA et ClusterIssuer → CP 1.3.3 (puis certificat, ThunderID 1.0.1, `backstage-secrets`,
upgrade TLS) → `all.yaml` → DP 1.3.3 + `ClusterDataPlane default` → (option) workflow → (option) observabilité.
Valeurs minimales : domaine de base, TLS de la passerelle, URL OIDC, secret du portail [L][install]. L'amont ne
parle pas d'OKE [L][install] ; il exige Kubernetes 1.34+ [L][install] (version OKE à vérifier [H]).

| Étape `install.sh` | Contenu | Verdict |
|---|---|---|
| 0 | Cilium, VAP et CCNP de base | **Ajouté** (socle cluster, hors OpenChoreo) |
| 1 | Namespaces, quotas, NetworkPolicy | **Ajouté** (l'amont crée les namespaces par Helm) |
| 2, 3, 5 | Gateway API CRD, cert-manager, kgateway | **Natif** (mêmes versions) [L](../../platform/install/versions.env) |
| 4 | ESO + store `lab-store` | **Natif** (ESO) ; store différent d'OpenBao |
| 6, 6b | CP sans portail, puis portail | **Natif** (chart) ; découpage en 2 étapes ajouté |
| 7 | VAP du labo, TLS, DP | **Natif** (DP) + VAP **ajoutées** |
| 8 | ClusterDataPlane mTLS | **Natif** |
| 9 | Environnements, pipeline, types durcis | **Natif** (équivalent d'`all.yaml`) |
| 10 | CNPG + `lab-pg` | **Ajouté** (non fait sur OKE) |
| 11 | Argo CD + AppProjects | **Ajouté** (l'amont documente Flux) |
| 12 | Aucun effet | **Supprimable** |

Absent chez nous : OpenBao, ThunderID, plans workflow et observabilité [L](../../tools/oke/install.sh). Le security
bundle reste obligatoire (`docs/SECURITY-BUNDLE.md`) [L].

## 3. Test d'usage pour Paul (30 à 45 min)

### 3.1 Prérequis exacts (avant la séance ; aucun n'est fait par ce ticket)

- [ ] P1. Portail installé : `install.sh --step 6b --apply`, puis `verify.sh --step 6b` PASS [L](../PORTAL.md).
- [ ] P2. IdP prêt : clients portail (2), `occ` et MCP créés dans Authentik ; ou décision S4 (§4) [D].
- [ ] P3. Paul est dans le groupe IdP lié à `lab-developer` ou `lab-platform-admin`
      [L](../../platform/authz/bindings-humans.yaml) ; les droits exacts de ces rôles sont à vérifier [H].
- [ ] P4. Sur le Mac : `oci`, `kubectl`, `helm`, `occ` 1.3.3 [L][cli], Claude Code.
- [ ] P5. Image de test : celle de `apps/whoami/app.yaml` (multi-arch, épinglée par digest) [L]. Le type
      `service-restricted` refuse une image sans digest [L](../../platform/component-types/service-restricted.yaml).
- [ ] P6. Accord de Paul : les écritures du test passent par l'API, hors PR (exception à AGENTS.md, test jetable).

### 3.2 Déroulé

| # | Min | Action | Résultat attendu |
|---|---|---|---|
| 1 | 5 | `tools/oke/open-oke-access.sh open 3600` ; `export KUBECONFIG=…` ; `kubectl config current-context` | Contexte OKE |
| 2 | 2 | `kubectl -n openchoreo-control-plane port-forward svc/backstage 7007:7007` et `svc/openchoreo-api 8080:8080` | Deux tunnels |
| 3 | 3 | Ouvrir `http://localhost:7007`, se connecter | Catalogue avec `whoami` |
| 4 | 5 | Créer le projet `lab-test-paul` par le template Project | Project visible |
| 5 | 7 | `occ component scaffold` (type `service-restricted`), compléter, `occ apply -f` ; ou template | Component + Workload |
| 6 | 5 | Onglet Deploy : déployer sur `development` | Ready, release nommée |
| 7 | 5 | Cliquer Promote (ou `occ component deploy <c> --to production`) | Ready en production |
| 8 | 5 | `claude mcp add --transport http --client-id <client MCP> --callback-port 8075 openchoreo-cp http://localhost:8080/mcp` [L][mcp] ; demander « liste les composants et leur état » | Réponse cohérente |
| 9 | 5 | Casser : patcher le Workload avec un digest inexistant | ImagePullBackOff |
| 10 | 5 | Diagnostiquer : « View K8s Artifacts », puis MCP `get_release_binding` | Cause trouvée |
| 11 | 3 | Réparer : redéployer la release précédente (`occ component deploy <c> --release <r>`) [L][logs] | Ready |
| 12 | 2 | Supprimer le projet de test ; `open-oke-access.sh close` | Rien ne reste |

### 3.3 Points à noter pendant le test

- Le MCP OAuth publie peut-être l'URL publique de l'API, pas `localhost` [H] : noter l'erreur exacte.
- `get_resource_events` et `get_resource_logs` manquent : notre CP retire le toolset `pe` [L](../../platform/install/values/openchoreo-control-plane.yaml)[reg].
- `occ component logs` échoue sans plan d'observabilité [L][logsgo] : c'est attendu.
- Pour chaque étape : PASS, FAIL ou BLOCKED, heure (Z), et une phrase « simple ou pénible ».

## 4. Simplifications proposées (à décider après le test ; rien n'est exécuté)

| # | Sujet | Proposition | Gain | Risque |
|---|---|---|---|---|
| S1 | Façade `appgen` (2 313 lignes) | Garder `app.yaml` pour la PR ; déléguer les releases à `autoDeploy` ou `occ --mode file-system` [L][rel] | Moins de code | Perte de contrôle du digest si le type ne le vérifie plus [D] |
| S2 | `argo_guard*` (730 lignes) | Si GitOps passe à Flux (amont) ou à un seul AppProject : le retirer ; sinon le garder | Moins de règles maison | Revue des règles A1-A3 à refaire [D] |
| S3 | `install.sh` | Retirer l'étape 12 ; fusionner 6 et 6b ; sortir 0, 10, 11 en « socle » | Script plus court | Aucun pour 12 [D] |
| S4 | Identité | (a) Authentik seul, conforme à MISSION (recommandé) ; (b) ThunderID pour le test seulement | (b) débloque P2 vite | (b) contredit MISSION et ADR-0007 |
| S5 | MCP | Activer `pe` ; l'authz bloque les écritures | Diagnostic par Claude | Surface d'outils plus grande [D] |
| S6 | Observabilité | Rester sans (budget) ; diagnostiquer par le portail | Aucun pod en plus | Pas de logs `occ`, pas d'observer MCP |

[arch]: https://openchoreo.dev/docs/overview/architecture/
[topo]: https://openchoreo.dev/docs/platform-engineer-guide/deployment-topology/
[install]: https://openchoreo.dev/docs/getting-started/try-it-out/on-your-environment/
[abs]: https://openchoreo.dev/docs/concepts/developer-abstractions/
[dep]: https://openchoreo.dev/docs/getting-started/deploy-and-explore/
[tpl]: https://openchoreo.dev/docs/platform-engineer-guide/backstage-scaffolder-templates/
[cli]: https://openchoreo.dev/docs/getting-started/cli-installation/
[dp]: https://openchoreo.dev/docs/developer-guide/deploying-applications/deploy-and-promote/
[logs]: https://openchoreo.dev/docs/developer-guide/deploying-applications/logs-and-troubleshooting/
[mcp]: https://openchoreo.dev/docs/ai/mcp-servers/
[mcpref]: https://openchoreo.dev/docs/reference/mcp-servers/
[gitops]: https://openchoreo.dev/docs/platform-engineer-guide/gitops/overview/
[flux]: https://openchoreo.dev/docs/platform-engineer-guide/gitops/using-flux-cd/
[rel]: https://openchoreo.dev/docs/platform-engineer-guide/gitops/automations/build-and-release-workflows/
[bulk]: https://openchoreo.dev/docs/platform-engineer-guide/gitops/automations/bulk-promote/
[idp]: https://openchoreo.dev/docs/platform-engineer-guide/identity-configuration/
[reg]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/pkg/mcp/tools/register.go#L104-L207
[svc]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/openchoreo-api/services/component/service.go#L87
[logsgo]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/component/logs.go#L49-L52
[occcmd]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/component/cmd.go#L182
[all]: https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/all.yaml
