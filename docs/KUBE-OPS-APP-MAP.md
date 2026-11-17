# Cartographie kube-ops vers golden paths OpenChoreo

Date : 2026-11-17. Lecture seule sur kube-ops. Aucun checkout, kubectl ni secret lu. Seule action : `git fetch origin` (refs distantes).

**Référence : kube-ops `origin/main` @ `ef50472bc427bbb5fb342cebf2f4db408157f5b3`** (commit du 2026-11-17, `feat(platform): contrat app-status.v1`). Le fetch a aussi mis à jour `origin/feat/oke-baseline-cilium-chaining` : hors périmètre.

Légende : **[C]@ef50472** = lu dans origin/main (chemin cité). **[S]** = supposé ou non vérifié dans ce passage. Les noms de secrets sont des clés Doppler ou des noms de `secretKey`, jamais des valeurs.

---

## 1. Conclusions

1. **35 entrées à classer** : 33 applications produit, 1 Job utilitaire (`media-layout-job`), 1 composant d'accès OKE (`netbird-router`). Exclus : `cloudflared` et `agent-operator` (infra et RBAC, pas des apps), `hermes-personal` (ApplicationSet à `elements: []`, 0 tenant [C] `k8s/optional/hermes-personal/applicationset.yaml`). `hindsight` (homelab et OKE) compte pour une app.
2. **Deux archétypes suffisent pour 27 apps sur 35** : (1) **HTTP natif** (A+B+C fusionnés : 1 port HTTP, 0-1 PVC RWO, 0-1 PostgreSQL, OIDC optionnel) = **14 apps** ; (2) **chart Helm référencé** pour les stacks multi-composants et les charts officiels = **13 apps** (E 9 + H 3 + mqtt). Un troisième archétype « worker/CronJob/TCP » (D) n'est pas nécessaire si mqtt passe par chart et si les CronJobs deviennent un champ `jobs[]`.
3. **7 apps non éligibles en l'état** (F) : privilèges root, `hostNetwork`, `NET_ADMIN`, `hostPath`, gVisor. Elles restent sur GitOps kube-ops, ou demandent une exception explicite et approuvée.
4. **Le schéma v2alpha1 ne couvre pas kube-ops tel qu'il est.** Quatre blocages : (a) `database.instance` n'accepte que `lab-pg`, alors que la règle kube-ops est pg-shared (`D-2026-11-13-02`, [C] via R1 §2) ; (b) `identity.oidc.provider` n'accepte que `thunderid`, alors que kube-ops utilise Authentik et ses groupes (`friends`, [C] `k8s/infrastructure/auth/authentik/extra/blueprints/groups.yaml`) ; (c) `network.egress` est binaire (`none`/`public-internet`), alors que kube-ops fait du FQDN allowlist ; (d) un seul port, un seul workload Deployment, pas de CronJob, pas de multi-PVC.
5. **Équivalence de sécurité : seuls 2 écarts bloquants.** Le cell-restricted du contrat est *plus strict* que kube-ops sur PSA, securityContext et automount du token. Il est *moins fin* sur l'egress (FQDN), donc à étendre avant migration. Sur OKE, le CNI est `FLANNEL_OVERLAY` qui **n'applique pas les NetworkPolicy** (contrat §0.6 citant `k8s/clusters/oracle-a1/README.md`@ef50472 [C]). Aucune app OKE ne doit être migrée avant le gate Cilium.
6. **Ordre recommandé** : it-tools, searxng, idp-e2e (validation du pipeline) → mealie, rustical-pilot, open-connector, vikunja (HTTP+PVC/PG) → agentgateway, ntfy → polyfin, aiostreams, romm, bookorbit (après extension FQDN et RWX) → le reste (E) via chart.

---

## 2. Fiches techniques

Chemins relatifs à `k8s/`. « Ext » = HTTPRoute `external` (Cloudflare public), « int » = `internal`. PSA = label `pod-security.kubernetes.io/enforce` présent sur le namespace (`k8s/CLAUDE.md`, décompte R1 §3.3 : 16 dossiers sur 29 avec label, 13 sans [C]).

| ID | App | Cat. / cluster | Image (épinglage) | Workload | Ports | Stockage | BD | OIDC | Exposition | Egress / ingress NP | securityContext réel | Particularités |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| K01 | idp-e2e (whoami) | apps-generated / homelab | `traefik/whoami:v1.10.3@sha256` [C] | Deployment, replicas 2 [C] `apps-generated/idp-e2e/app.yaml:12` | 80 [S] | aucun | aucune | non | int ? [S] | ingress only [S] | restricted [S] | Format v1 `platform.smadja.dev/v1 Application` (R1 §2) |
| K02 | it-tools | tools / homelab | `corentinth/it-tools:2024.10.22-7ca5933` **tag seul** [C] | Deployment | 80 [C] | aucun | aucune | non | int [C] | ingress only [S] | drop ALL [S, ligne 44] | probe 1 fichier [C] |
| K03 | searxng | catalog / homelab | `searxng/searxng:2026.9.30-a9d990033` **tag seul** [C] | Deployment | 8080 [C] | aucun | aucune | non | int [C] | ingress entities host/remote/ingress [C] | drop ALL [C] | 1 ExternalSecret config [C], sans probe [C] |
| K04 | mealie | catalog / homelab | `ghcr.io/mealie-recipes/mealie:v3.28.0` **tag seul** [C] | Deployment | 9000 [C] | PVC 5 Gi longhorn-fast [C] | SQLite [S] | **oui** [C] (`APP_MEALIE_OIDC_CLIENT_SECRET`) | ext+int [C] | ingress only [C] | drop ALL [C] | sans probe [C] |
| K05 | vikunja | catalog / homelab | `vikunja/vikunja:2.7.0` **tag seul** [C] | Deployment | 3456 [C] | PVC 2 Gi fast [C] | **CNPG** 1 inst. + ScheduledBackup dim. 06:30 + ObjectStore R2 [C] | oui [C] (7 occurrences) | ext+int [C] | ingress only [C] | drop ALL [C] | sans probe [C] |
| K06 | ntfy | catalog / homelab | `binwiederhier/ntfy:v2.28.0` **tag seul** [C] | Deployment, `strategy: Recreate` [C] | 8080 [C] | PVC 1 Gi fast, `Prune=false` [C] | SQLite/auth.db [C] | non [S] | ext+int [C] | ingress entities [C] | runAsUser 65532, drop ALL [C] | **initContainer** `bootstrap-admin` qui lance `ntfy serve` puis écrit `auth.db` [C] |
| K07 | paperless | catalog / homelab | `paperless-ngx:3.2.1` **tag seul** [C] | Deployment + Valkey (`valkey:9-alpine`, tag) [C] | 8000 [C] | PVC 5 Gi + 20 Gi fast [C] | **CNPG** + ScheduledBackup hebdo + ObjectStore R2 [C] | [S] | int [C] | restic : egress `*.eu.r2.cloudflarestorage.com` [C] | drop ALL [C] | 2 CronJobs restic (21:30 et dim. 11:30) + restic 0.19.1 [C] |
| K08 | sure | catalog / homelab | `ghcr.io/we-promise/sure:0.7.5-hotfix.1` **tag seul** [C] | 2 Deployments (web + worker) [C] + Redis Deployment (`valkey:9-alpine`) [C] | 3000 http, 6379 [C] | PVC 5 Gi fast [C] | **CNPG** + ScheduledBackup + R2 [C] | oui [C] (19 occ.) | int [C] | ingress [C] | drop ALL [C] | fichier `backup-gap-remediation-20261019.yaml` [C] |
| K09 | stirling-pdf | catalog / homelab | `stirlingtools/stirling-pdf:3.0.0` **tag seul** [C] | Deployment | 8080 [C] | PVC 2 Gi fast [C] | aucune | non | int [C] | ingress [C] | **runAsUser 0**, drop ALL, add CHOWN [C] | initContainer busybox:1.37 [C] |
| K10 | romm | games / homelab | `ghcr.io/rommapp/romm:5.2.0` **tag seul** [C] | Deployment | 8080 [C] | **4 PVC** : 100 Gi bulk, 20 Gi bulk, 20 Gi fast, 2 Gi fast [C] | **CNPG** + ScheduledBackup 03:20 + R2 [C] | oui [C] (20 occ.) | ext+int [C] | egress FQDN `hasheous.org`, `*.hasheous.org`, `*.igdb.com`, R2 [C] | drop ALL [S] | sonde 1 fichier [C] |
| K11 | bookorbit | media / homelab | `ghcr.io/bookorbit/bookorbit:3.6.0@sha256` [C] | Deployment | 3000 [C] | PVC 10 Gi fast + **media-share** RWX monté `/data` [C] | **CNPG** + ScheduledBackup dim. 07:00 + R2 [C] | oui [C] (14 occ.) + blueprint Authentik `friends` [C] | int [C] | egress FQDN `auth.smadja.dev` + `toCIDR` [C] ; ingress entities [C] | drop ALL [C] | README : media-share partagé avec Polyfin [C] |
| K12 | polyfin | media / homelab (+ `optional/polyfin-nebula`) | `ghcr.io/moodiness/polyfin:0.61.1@sha256` [C] | Deployment | 8096 [C] | PVC 20 Gi fast [C] | **CNPG** + ScheduledBackup 06:30 + R2 [C] | oui [C] (9 occ.) | int [C] | **egress FQDN ≥ 10 hôtes** (addons, tidal, eclipsemusic, githubusercontent…) + CIDR `10.0.20.192/32` [C] | capabilities (détail [S]) | pas de media-share ici [C] |
| K13 | aiostreams | media / homelab | `ghcr.io/viren070/aiostreams:v2.37.0@sha256` [C] | Deployment | 3000 [C] | PVC 4 Gi fast [C] | SQLite [S] | OIDC **dormant** (patch + ExternalSecret `.dormant.yaml`) [C] | int + route `family` ext+int [C] | **egress FQDN très long** (≥ 30 hôtes, torbox, strem.io, …) + CIDR LAN [C] | capabilities drop [C] | OKE : overlay `clusters/oracle-a1/media` hors racine [C] |
| K14 | immich | media / homelab | server `immich-server:v3.1.0` **StatefulSet** 100 Gi bulk [C] ; ML `immich-machine-learning:v3.1.0` [C] ; Redis PVC 1 Gi [C] | StatefulSet + Deployment | 2283, 8081, 8082 ; ML 3003 [C] | 100 Gi bulk + Redis | **CNPG 17.7** (`cnpg postgresql:17.7`) + ScheduledBackup 03:00 + R2 [C] | 1 occ. [C] | ext+int [C] | restic : R2 [C] | `readOnlyRootFilesystem: false` [C] | **restic en CronJob** ×2 [C] |
| K15 | media-layout-job | media / homelab | `busybox:1.36.1` [C] | Job [C] | — | **media-share** RW [C] | — | — | — | — | non vérifié [S] | mute la bibliothèque média : hors archétype |
| K16 | invoice-ninja | business / homelab | `invoiceninja-debian:5.13.43@sha256`, `nginx-unprivileged:1.29.4@sha256`, `mysql:8.4.11`, `redis:8.2-alpine3.22`, `invoice-ninja-mcp:<sha>` [C] | Deployments (fpm 9000, http 8080, mcp 8539, redis 6379) + StatefulSet MySQL [C] | voir colonne | 3 PVC bulk 1 à 5 Gi + MySQL 10 Gi bulk [C] | **MySQL** interne (pas CNPG) + CronJob `backup-logical` 04:15 [C] | oui [C] (8 occ.) | ext+int sur domaine `gestion.lechaplais.com` [C] | NP mcp séparée [C] | drop ALL [C] | 4 probes [C] |
| K17 | pinepods | web / homelab | `pinepods:0.9.0` **tag seul** [C] | Deployment + initContainer + Valkey [C] | 8040, 6379 [C] | PVC 30 Gi + 3 Gi, `velero exclude` [C] | **CNPG** + ScheduledBackup + R2 [C] | oui [C] (15 occ.) | ext+int [C] | [S] | **main container runAsUser 0, runAsNonRoot false, rootfs RW, caps ALL** [C] ; init idem [C] | `fsGroup 911` [C] |
| K18 | trilium | web / homelab | `trilium:sha-621f1ff` **tag sha, sans digest** [C] | Deployment + initContainer `chown-data` root [C] | 8080 [C] | PVC 5 Gi fast [C] | SQLite [S] | non [S] | ext+int [C] | ingress [C] | **runAsUser 0, allowPrivilegeEscalation true, rootfs RW** [C] | init chown root [C] |
| K19 | mqtt (Mosquitto) | automation / homelab | `eclipse-mosquitto:2.0` tag, 2 occurrences [C] | StatefulSet [C] | **1883 TCP** (non HTTP) [C] | PVC 1 Gi fast [C] | aucune | non | aucune route [C] | [S] | non vérifié [S] | initContainers [C] |
| K20 | hassio (Home Assistant + ha-mcp) | automation / homelab | `home-assistant:2026.6.0` tag [C] ; `ha-mcp:latest@sha256` [C] ; busybox 1.38 (init) [C] | StatefulSet + Deployment [C] | 8123, 8086, 8124 [C] | PVC 5 Gi fast [C] | aucune | 7 occ. [C] | int [C] | [S] | **`hostNetwork: true`, `NET_ADMIN`, `NET_RAW`, `NET_BROADCAST`** [C] | **PolicyException Kyverno** [C] `automation/hassio/policy-exception.yaml` |
| K21 | open-connector | platform / homelab | `ghcr.io/oomol-lab/open-connector@sha256` [C] | Deployment | 3000 [C] | PVC 2 Gi bulk [C] | aucune | 1 occ. [C] | aucune route [C] | ingress host [C] | drop [S] | — |
| K22 | agentgateway | platform / homelab | `cr.agentgateway.dev/agentgateway@sha256` [C] | Deployment | 4000 (llm) [C] | PVC 1 Gi fast [C] | aucune | 1 occ. [C] | aucune route [C] | egress FQDN `api.minimax.io` [C] | drop ALL [C] | 2 ExternalSecrets [C] |
| K23 | factory-platform | platform / homelab | app `factory-platform@sha256` [C] ; `cube@sha256` ; `cubestore@sha256` ; `factory-platform-dbt@sha256` [C] | Deployments (app, cube, cubestore) + 2 CronJobs (collector toutes les 30 min, dbt 5/35) [C] | 4000, 3030, 8080 [C] | PVC cubestore 2 Gi bulk [C] | **2 CNPG** (`database.yaml`, `database-pg2.yaml`) + ObjectStores [C] | 0 occ. [C] | [S] | egress FQDN `api.github.com`, `fsn1.your-objectstorage.com` [C] | drop ALL (cube, cubestore) [C] | 5 ExternalSecrets [C] |
| K24 | mastra-factory | platform / homelab | `mastra-factory@sha256` [C] | Deployment, `replicas: 1` (comment : verrou sandbox non qualifié) [C] | 4111 [C] | — | **CNPG** + ScheduledBackup dim. 03:15 + R2 [C] | 40 occ. dont OIDC dormant [C] | int + webhook ext [C] | egress FQDN github, linear, auth.smadja.dev, objectstorage ; **toEntities kube-apiserver** [C] | drop ALL [C] | 7 ExternalSecrets [C] |
| K25 | mastra-sandbox | platform / homelab | `mastra-sandboxd@sha256` dans `SandboxTemplate` [C] | SandboxTemplate + SandboxWarmPool (replicas 0) [C] | rest 8080, grpc 9090 [C] | PVC `longhorn-workspace` 2 Gi par claim [C] | aucune | — | — | `matchPattern "*"` + FQDN github/npm [C] | **`runtimeClassName: gvisor`** [C] | RBAC + CRD Agent Sandbox [C] |
| K26 | matrix (Synapse + MAS) | platform / homelab | images [S] ; chart Helm via `values.yaml` [S] | Helm [S] | 8008, 8080 [S] | media-pvc 10 Gi fast [C] | **2 CNPG** (`database-mas`, `database-synapse`) + 2 ObjectStores + 2 ScheduledBackups [C] | 23 occ. [C] | 4 hôtes ext+int (`matrix`, `chat`, `account`, apex) [C] | kube-apiserver entity + CIDR `10.0.20.192/32` [C] | [S] | — |
| K27 | rustical-pilot | platform / homelab | Deployment patché depuis `optional/rustical` [C] | Deployment | [S] | PVC bulk 1 Gi [C] | [S] SQLite | 3 occ. + blueprint staged [C] | [S] | [S] | [S] | — |
| K28 | fleet (+ MySQL + Valkey) | optional, importé par `platform` / homelab | `fleetdm/fleet:v4.94.1@sha256` ; `mysql:8.4.11@sha256` ; `valkey:8.1.11@sha256` [C] | Deployment + StatefulSet MySQL + Deployment Valkey + initContainer [C] | 8080, 3306, 6379 [C] | 2 × PVC 10 Gi fast [C] | **MySQL interne** [C] | 1 occ. [C] | int [C] ; route ext **staged** [C] | egress `toEntities world` [C] | — | ExternalSecret 2 [C] |
| K29 | sparkyfitness | optional, importé par `platform` / homelab | chart upstream `CodeWithCJ/SparkyFitness` tag `v1.11.0`, `helm/chart` [C] | Argo Application Helm [C] | — | — | **CNPG** `database.yaml` + backup R2 [C] | 9 occ. + blueprint **staged** [C] | — | egress FQDN Garmin, USDA, OpenFoodFacts… [C] | upstream [S] | `Prune=false` [C] |
| K30 | librechat | optional `personal-ai-2026`, importé par `ai` / homelab | chart `ghcr.io/librechat-ai/librechat-chart:3.0.0` [C] | Argo Application Helm [C] | — | — | [S] | 8 occ. [C] | route **dormant** [C] | egress `auth.smadja.dev` + CIDR `10.0.20.192/32` [C] | drop ALL (values) [C] | — |
| K31 | hindsight (homelab) + hindsight (OKE overlay) | `optional/personal-ai-2026` importé par `ai` ; `clusters/oracle-a1/hindsight` actif sur OKE | chart `ghcr.io/vectorize-io/charts:hindsight 1.2.1` [C] | Helm (homelab) ; Helm inflaté par kustomize (OKE) [C] | API 8888 (`/health/live`) [C] | — | **CNPG** 1 inst. + ScheduledBackup 03:40 + objectstores R2 (OKE) [C] | — | — | R2 + CIDR [C] | — | 3 ExternalSecrets OKE [C] |
| K32 | gpt-researcher | ai / homelab | `gpt-researcher:3.4.3-37d220a`, `gptr-nextjs:3.4.3-5fa0882`, `caddy:2.11.3-alpine` (tags sans digest) [C] | 3 Deployments + 1 Rollout + Job busybox [C] | 8000, 3000 [C] | 3 PVC 10/10/5 Gi fast [C] | aucune | — | int [C] | FQDN `api.tavily.com`, `api.smith.langchain.com` [C] | **ws-rewriter : `runAsUser 0`, `allowPrivilegeEscalation true`, rootfs RW** [C] | doublon Rollout/Deployment [C] |
| K33 | karakeep | ai / homelab | `karakeep:0.32.0` (StatefulSet web) ; `karakeep-chrome:release` (tag mutable) ; `meilisearch:v1.46.0` [C] | StatefulSet web + Deployment Chrome + StatefulSet Meilisearch [C] | 3000 [C] | 2 × PVC 5 Gi fast [C] | SQLite/Meili [S] | 2 occ. [C] | ext+int [C] | ingress entities [C] | **allowPrivilegeEscalation true** (web) [C] | Chrome sans `--no-sandbox` [S] |
| K34 | opencode | ai / homelab | `opencode-manager:0.13.0`, `helm:3.18.6`, `kustomize:v5.7.1`, `playwright:v1.60.0` [C] | Deployment + initContainers [C] | 5003 [C] | 2 PVC 10/5 Gi fast [C] | — | — | int [C] | [S] | **runAsUser 0, CHOWN/SETUID/SETGID**, **PolicyException Kyverno** [C] | a un Playwright et un helm dans le pod [C] |
| K35 | netbird-router (OKE) | clusters/oracle-a1 / OKE | `netbirdio/netbird:0.83.0` [C] | Deployment [C] | — | `hostPath /var/lib/netbird-router` [C] | — | — | — | — | **NET_ADMIN, SYS_RESOURCE, SYS_ADMIN, allowPrivilegeEscalation true** [C] | accès admin API OKE (PLT-256) [C] |

Cas exclus du décompte : `cloudflared` (OKE, tunnel, token ESO, drop ALL [C]) = infra ; `agent-operator` (RBAC et SA [C]) = identité ; `optional/personal-ai-2026/openclaw` = **non importé** par `ai/kustomization.yaml` [C], donc inactif.

**Totaux [C] (`git grep` origin/main)** : 1 023 fichiers sous `k8s/`. ExternalSecrets par app : 1 à 7. CNPG `Cluster` hors charts : 22 (R1 D1). `image:` sans `@sha256` : 63 lignes (R1 S6). Exceptions Kyverno : 2 (`ai/opencode`, `automation/hassio`). GPU ou `/dev` : 0 occurrence. Probes : absentes sur ~10 apps.

---

## 3. Archétypes et classification

Lettres de l'énoncé, puis le regroupement minimal retenu.

| ID | App | Archétype | Verdict | Raison principale |
|---|---|---|---|---|
| K01 | idp-e2e | A | Migrable sans perte | HTTP seul |
| K02 | it-tools | A | Migrable sans perte (digest à épingler) | HTTP seul |
| K03 | searxng | A | Migrable sans perte (digest à épingler) | HTTP, sans PVC |
| K04 | mealie | C | Migrable sans perte | HTTP + PVC + OIDC |
| K05 | vikunja | B (+PVC) | Migrable avec compensation (E1, E2) | HTTP + CNPG + PVC + OIDC Authentik, non exprimables aujourd'hui |
| K06 | ntfy | C | À compenser | initContainer qui démarre le serveur |
| K07 | paperless | E | À compenser | CNPG + cache + 2 CronJobs restic |
| K08 | sure | E | À compenser | web + worker + cache + CNPG |
| K09 | stirling-pdf | F | Non éligible sans exception | root + CHOWN |
| K10 | romm | B | À compenser | 4 PVC dont 100 Gi, egress FQDN |
| K11 | bookorbit | B | À compenser | media-share RWX monté |
| K12 | polyfin | B | À compenser | egress FQDN ≥ 10 + CIDR LAN |
| K13 | aiostreams | C | À compenser | egress FQDN très long, OIDC dormant |
| K14 | immich | E | À compenser | StatefulSet + ML + Redis + CNPG + restic |
| K15 | media-layout-job | — | Non éligible | Job sur media-share RW, mutation de bibliothèque |
| K16 | invoice-ninja | E | À compenser (ou Helm) | MySQL hors `lab-pg` |
| K17 | pinepods | F | Non éligible sans exception | root et rootfs RW |
| K18 | trilium | F | Non éligible sans exception | root, privilege escalation |
| K19 | mqtt | D | Migrable via chart | TCP 1883, non HTTP |
| K20 | hassio | F | Non éligible | hostNetwork, NET_ADMIN, PolicyException |
| K21 | open-connector | C | Migrable sans perte | HTTP + PVC bulk |
| K22 | agentgateway | C | À compenser (1 FQDN) | egress FQDN |
| K23 | factory-platform | E | À compenser | 2 CNPG, cube, cubestore, 2 CronJobs |
| K24 | mastra-factory | B | À compenser | toEntities kube-apiserver, dépend du sandbox |
| K25 | mastra-sandbox | F | Non éligible | gVisor, RBAC, CRD |
| K26 | matrix | E | Helm (chart) | 2 CNPG, Synapse + MAS |
| K27 | rustical-pilot | C | Migrable sans perte (à vérifier) | HTTP + PVC |
| K28 | fleet | E | Helm (chart) | MySQL interne, StatefulSet |
| K29 | sparkyfitness | H | Helm | chart upstream |
| K30 | librechat | H | Helm | chart upstream |
| K31 | hindsight | H | Helm | chart upstream, CNPG |
| K32 | gpt-researcher | E | Non éligible partiel | ws-rewriter root, multi-workload |
| K33 | karakeep | E | À compenser | 3 workloads, privilege escalation |
| K34 | opencode | F | Non éligible | root, exception, Playwright |
| K35 | netbird-router | F | Non éligible | NET_ADMIN, hostPath, accès API OKE |

### Archétypes

**A+B+C fusionnés : « HTTP natif »** (14 apps : K01, K02, K03, K04, K05, K13, K11, K12, K10, K21, K22, K27, K06, K24). Un port HTTP, 0 à 1 PVC RWO, 0 à 1 PostgreSQL, OIDC optionnel, sans workload annexe. Le schéma v2alpha1 l'exprime sans extension pour K01, K02, K03 et K21 seulement. K04, K27 et les apps à OIDC Authentik demandent E2 ; les apps PostgreSQL demandent E1.

**H + E : « chart Helm référencé »** (13 apps : K07, K08, K14, K16, K23, K26, K28, K29, K30, K31, K32, K33, K19). Le parcours Helm du contrat (§2.4) existe, mais il faut un chart par app. Pour les apps à manifests faits main (K07, K08, K14, K23, K33), c'est un coût de packaging, à arbitrer.

**D : « Job/CronJob/TCP »** : n'a plus d'archétype propre. K19 passe par chart, les CronJobs deviennent un champ `jobs[]`. K15 est exclue.

**F : « non éligible »** (7 apps : K09, K15, K17, K18, K20, K25, K34, K35). Garder sur GitOps kube-ops, ou ouvrir une exception nominative (voir §4.4).

### Couverture

| Regroupement | Apps | Part |
|---|---|---|
| Archétype natif HTTP (A+B+C) | 14 | 40 % |
| Chart Helm (E+H+mqtt) | 13 | 37 % |
| Non éligible (F et Job) | 8 | 23 % |

Un seul archétype natif suffit pour 14 apps. Il faut une extension de schéma pour passer de 14 à 27.

---

## 4. Extensions de schéma et équivalence de sécurité

### 4.1 Ce que `app.schema.json` v2alpha1 exprime déjà [C]

`metadata` (name, owner, description, lifecycle), `spec.source.image` (digest recommandé), `spec.cluster` (`k3d` | `oke`), `environments`, `profile` (`stateless` | `stateful`), `runtime` (un port, `healthPath`, `size` small|medium, `replicas`, `runAsUser` ≥ 1000, `command`, `args`, `env`), `storage` (un PVC `block-rwo`), `database` (postgres, `lab-pg` uniquement), `secrets[]`, `identity.oidc` (`thunderid` uniquement), `exposure` (private|public, host unique, auth), `network.egress` (`none`|`public-internet`), `backup.class` (none|regenerable|irreplaceable), `observability.metrics`, `update.strategy`.

### 4.2 Extensions indispensables (par ordre de bloquage)

| # | Champ à ajouter | Débloque | Pourquoi (preuve kube-ops) |
|---|---|---|---|
| E1 | `database.instance` : accepter `pg-shared` (et `pg-shared-oke`), multi-DB, `engine: mysql` | K05, K10, K11, K12, K17, K24, K07, K08, K14, K23, K26 | `D-2026-11-13-02` impose pg-shared pour toute nouvelle base [C] R1 §5 P1 |
| E2 | `identity.oidc.provider` : `authentik`, + `allowedGroups[]`, `redirectPaths[]`, `groupsClaim` | K04, K05, K08, K10, K11, K12, K17, K24 | Authentik est l'IdP de kube-ops, groupe `friends` [C] |
| E3 | `network.egress[]` déclaratif : `{fqdn, ports}`, `{fqdnPattern, ports}`, `{cidr, ports}`, `{entity}` ; `public-internet` reste la valeur de compat | K10, K12, K13, K22, K24, K23, K33 | kube-ops fait du FQDN allowlist avec RFC1918 exclu [C] `media/aiostreams/networkpolicy.yaml` |
| E4 | `network.ingress[]` : `{fromEntities}`, `{fromApp, ports}` | K19, K24, K26, K05 | `fromEntities: [host, remote-node, ingress]` standard kube-ops [C] |
| E5 | `runtime.ports[]` : nom, port, protocole TCP/UDP, visibilité | K19 (1883), K20, K28 (3 ports), K31 | Ports multiples [C] |
| E6 | `workloads[]` ou `components[]` : Deployment, StatefulSet, sidecar, init | K07, K08, K14, K16, K23, K33 | StatefulSet dans 6 apps [C] |
| E7 | `jobs[]` : CronJob/Job, schedule, image, mounts, timezone, concurrency | K07, K14, K16, K23, K15 | 9 CronJobs [C] |
| E8 | `storage[]` multi-volumes : `profile` (`block-rwo`, `rwx-shared`, `bulk`), `readOnly`, `velero.exclude`, taille hors `Gi` 4 chiffres | K10 (4 PVC), K11 (RWX), K14, K23 | `media-share` RWX [C] ; `velero.io/exclude-from-backup` [C] |
| E9 | `backup.mechanism[]` : `cnpg-r2`, `restic-r2`, `velero`, `none` | K07, K14, K16, K17 | 2 restic, 22 CNPG [C] |
| E10 | `runtime.probes` (liveness, readiness, startup) | toutes | Probes absentes sur ~10 apps [C] |
| E11 | `runtime.quota` ou `size: large` borné | K14, K10, K08 | quota cell par défaut 300 m CPU / 512 Mi [C] `cell-restricted` (contrat §7.2) |
| E12 | `security.exceptions[]` : `{rule, reason, expiresAt, approver}`, refus par défaut, rendu en PolicyException | K09, K17, K18, K20, K32, K34 | 2 PolicyException existantes [C] |
| E13 | `runtime.securityContext` : `readOnlyRootFilesystem`, `writablePaths[]`, `fsGroup` | K14, K18, K32 | rootfs RW [C] |
| E14 | `runtime.initContainers[]` (chown, migration, bootstrap) | K06, K09, K17, K18, K20, K19 | initContainers [C] |
| E15 | `exposure.hosts[]` + `visibility: internal|external|both` | K03, K05, K08, K24, K26, K31, K33 | gateways `internal` et `external`, et apex `smadja.dev` [C] |
| E16 | `runtime.hostAliases[]` ou `egress` LAN (CIDR) | K12, K13, K30, K26 | `10.0.20.192/32` [C] |

### 4.3 Rendu de l'egress déclaratif (proposition)

```yaml
network:
  egress:
    - {fqdn: api.minimax.io, ports: [443]}            # K22
    - {fqdnPattern: "*.eu.r2.cloudflarestorage.com", ports: [443]}   # backups
    - {cidr: 10.0.20.192/32, ports: [{port: 443}]}     # LAN
    - {entity: kube-apiserver}                         # K24
  ingress:
    - {fromEntities: [ingress]}
```

Rendu : CiliumNetworkPolicy (`toFQDNs`, `toCIDR`, `toEntities`). Sur un cluster sans Cilium, **refus** (pas de NetworkPolicy standard qui ne sait pas faire le FQDN). OKE est dans ce cas (`FLANNEL_OVERLAY`, contrat §0.6 [C]).

### 4.4 Équivalence de sécurité

| Contrôle kube-ops [C] | Cell-restricted OpenChoreo [C contrat §7] | Équivalent ? |
|---|---|---|
| CNP Cilium par app, FQDN | default-deny + allow-DNS + `egress: none|public-internet` | **Non** avant E3. `public-internet` élargit tout l'internet public |
| PSA `enforce` : 16 dossiers sur 29 (R1) | `restricted` forcé par le namespace | **Mieux** (gain sur 13 dossiers sans label) |
| securityContext : non-root, drop ALL, rootfs RO | CCT `service-restricted` le force, en plus une VAP `postRenderValidations` | Équivalent, et plus strict |
| Kyverno `Audit` (5 règles, R1 S2) | Pas d'équivalent, mais `postRenderValidations` bloque | **Mieux** (refus effectif, pas audit) |
| ExternalSecret par app, Doppler | SecretReference + ESO | Équivalent |
| Backup CNPG R2, Velero, restic | `backup.class` seulement | **Perte** : pas de mécanisme par volume (E9) |
| Token automount | `automountServiceAccountToken: false` | Mieux |
| Exceptions : PolicyException nominative | Pas de mécanisme | **Perte** à compenser par E12 |
| Image par digest | Imposé | Mieux (63 lignes `image:` sans digest aujourd'hui, R1 S6) |

**Conclusion sécurité.** Migrer sans E3 (egress FQDN) élargit l'egress de K10, K12, K13, K22, K24 ; sans E12, il faut retirer les privilèges (K09, K17, K18, K20, K32, K34) avant tout. Les autres écarts sont des gains.

---

## 5. Table de migrabilité

| Catégorie | Apps | Condition |
|---|---|---|
| **Migrables sans perte de sécurité** (schéma v2alpha1 actuel, ou digest seul) | K01 idp-e2e, K02 it-tools, K03 searxng, K21 open-connector | Épingler le digest (K02, K03). Aucune extension |
| **Migrables après E2 seul** (OIDC Authentik) | K04 mealie, K27 rustical-pilot (à vérifier) | Extension E2 |
| **Migrables avec compensation** | K05 vikunja (E1, E2), K06 ntfy (E14), K10 romm (E3, E8), K11 bookorbit (E8 RWX, E1, E2), K12 polyfin (E3, E16), K13 aiostreams (E3, E16), K22 agentgateway (E3), K24 mastra-factory (E3, E4), K07 paperless (E6, E7, E9), K08 sure (E6), K14 immich (E6, E7, E8, E9), K16 invoice-ninja (E1 mysql, E6, E7), K23 factory-platform (E6, E7, E1), K33 karakeep (E6, E13), K32 gpt-researcher (sans partie root), K26 matrix (chart), K28 fleet (chart), K29 sparkyfitness (chart), K30 librechat (chart), K31 hindsight (chart), K19 mqtt (chart) | Listé par app |
| **Non éligibles** (privilèges, hôte, gVisor, mutation de média) | K09 stirling-pdf (root), K17 pinepods (root), K18 trilium (root), K20 hassio (hostNetwork, NET_ADMIN), K34 opencode (root, exception), K35 netbird-router (NET_ADMIN, hostPath), K25 mastra-sandbox (gVisor, RBAC), K15 media-layout-job (RW sur media-share) | Rester sur kube-ops, ou exception E12 approuvée |

**Pas de GPU ni de `/dev` dans le dépôt** [C] : pas d'extension GPU nécessaire.

---

## 6. Ordre de portage recommandé (valeur et facilité)

1. **K02 it-tools, K03 searxng** : HTTP pur, zéro extension. Valide le pipeline `appgen`.
2. **K01 idp-e2e** : déjà au format contrat, sert de témoin.
3. **K04 mealie, K21 open-connector, K27 rustical-pilot** : HTTP + PVC, OIDC pour mealie.
4. **K05 vikunja** : CNPG, à dépendre de E1 (pg-shared).
5. **K22 agentgateway, K06 ntfy** : une extension chacune (E3 simple, E14).
6. **K12 polyfin, K13 aiostreams, K10 romm** : egress FQDN longs. Ce sont les apps à forte valeur, à porter après E3 et E8.
7. **K11 bookorbit** : après E8 (RWX media-share).
8. **K24 mastra-factory, K07 paperless, K08 sure, K33 karakeep** : après E6, E7, E9.
9. **K14 immich, K23 factory-platform, K16 invoice-ninja, K26 matrix** : stacks lourdes, chart Helm ou composition multi-composants.
10. **Hors portage** : F (7 apps). Revoir après retrait des privilèges.

**Prérequis avant toute migration OKE** : gate Cilium (contrat §0), car le CNI OKE n'applique pas les NetworkPolicy [C].

---

## 7. Points à valider

- **[S]** Ports et drop ALL de K01, K19, K21, K22, K27 : non relus.
- **[S]** K26 matrix : chart non identifié (valeurs `values.yaml` seulement).
- **[S]** K27 rustical-pilot : Deployment patché depuis `optional/rustical`, non relu.
- **[S]** K33 karakeep Chrome : `--no-sandbox` et capabilities non relus.
- **[S]** Sélecteur `apps-generated` : seul `idp-e2e` est listé [C] R1 §3.1.
- **[C] à noter** : `hindsight` homelab (chart 1.2.1) et OKE (overlay kustomize) sont **deux déploiements** d'un même produit. À confirmer avant de les fusionner en une app.
