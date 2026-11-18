# Contrat applicatif : « ajouter une app = 1 à 2 fichiers »

Date : 2026-11-17, avec les corrections de Paul du même jour. OpenChoreo **v1.3.3**.

- **Phase 0 : k3d** (Mac arm64). Tout ce document s'y exécute d'abord.
- **OKE ensuite, seulement après le gate** : Cilium et baseline kube-ops #1620 en place, refus IMDS prouvé, accès opérateur ouvert.
- Pilote : whoami, Miniflux et AIOStreams. Ni Authentik ni pg-shared : l'OIDC passe par ThunderID, PostgreSQL par un CNPG **éphémère** `lab-pg`.

Schéma : [`schema/app.schema.json`](schema/app.schema.json). Base de code : [`BASE-CHOICE.md`](BASE-CHOICE.md). Niveaux de preuve : [D] doc lue, [C] code ou fichier lu (chemin dans `source-v1.3.3` sauf mention), [S] supposé, à prouver en Phase 0.

## 0. Conclusion

1. **Un seul fichier écrit par l'humain ou l'agent : `apps/<nom>/app.yaml`.** On y ajoute `values.yaml` pour le parcours Helm. Le contrat `platform.smadja.dev/v2alpha1 App` dérive du `v1` de kube-ops (digest obligatoire, table `small`/`medium`, préfixe de secrets).
2. **Deux parcours, choisis par une règle (§3) :**
   - **natif OpenChoreo** : Project, Component et Workload sur 1 ClusterComponentType durci ;
   - **Helm GitOps** : chart officiel synchronisé par Argo CD et seulement **référencé** au catalogue. OpenChoreo ne le pilote pas.

   Les 3 apps du pilote sont **natives**. Le parcours Helm est illustré (§2.4) mais n'est **pas activé**.
3. **Un générateur CI** (`tools/appgen`, §4) transforme `app.yaml` en 7 à 11 manifests au format sample-gitops. Il appelle `occ` en mode file-system pour les ComponentRelease et les ReleaseBinding. Argo CD synchronise ensuite. Personne n'écrit de manifest OpenChoreo à la main.
4. **Un objet = un contrôleur (§5).** Git et Argo possèdent tout ce qui est déclaratif. Les contrôleurs OpenChoreo possèdent les objets dérivés (`*Release` générés, RenderedRelease, objets des namespaces `dp-*`). Garde-fous : `autoDeploy: false`, `Prune=false` sur ComponentRelease, Component et Resource (annotations émises par appgen), `releases/` en ajout seul. Seule exception de champ : `ProjectReleaseBinding.spec.projectRelease`, initialisé une fois par le contrôleur [C], puis avancé par une 2ᵉ PR `pin-project`.
5. **Objets custom minimaux, vérifiés contre les CRD v1.3.3 (§7) :** 1 ClusterComponentType `service-restricted`, 1 ClusterProjectType `cell-restricted`, 1 ClusterResourceType `cnpg-lab-db`, plus 2 ValidatingAdmissionPolicies natives. Aucune CRD custom, aucun fork.
6. **Deux limites sont prouvées dans le code :**
   - Une `ResourceReleaseBinding` doit être épinglée **à la main** sur `<resource>-<hash>` : aucun seed, aucun générateur `occ` (`api/v1alpha1/resourcereleasebinding_types.go` l.29-34, `internal/controller/resourcereleasebinding/controller.go` l.113) [C]. Une base de données coûte donc **2 PR**.
   - Sur OKE, le CNI est `FLANNEL_OVERLAY`, qui **n'applique pas** les NetworkPolicy (kube-ops `k8s/clusters/oracle-a1/README.md`@ef50472) [C]. D'où le gate Cilium.

## 1. Champs du contrat

| Champ | Obligatoire | Natif : ce que ça devient | Helm |
|---|---|---|---|
| `metadata.name` / `owner` / `description` / `docs` / `lifecycle` | name, owner, description | Noms du Project, du Component et de la Resource ; annotations `openchoreo.dev/description` ; `catalog-info.yaml` | Nom de l'Application Argo et `catalog-info.yaml` |
| `spec.source.image` (`…@sha256:` obligatoire) | l'un des deux | `Workload.spec.container.image` | — |
| `spec.source.chart` {repo, name, version exacte, digest si `oci://`} | l'un des deux | — | `Application.spec.sources[0]` |
| `spec.cluster` (`k3d` \| `oke`) | oui | Overlay d'environnement (StorageClass, CIDR, hôtes) | Destination |
| `spec.environments` (`development`, `production`) | oui | Un ReleaseBinding et un ProjectReleaseBinding par environnement | Une Application par environnement |
| `spec.profile` (`stateless` \| `stateful`) | oui | stateless : ni `database` ni `storage`. stateful : au moins l'un des deux (schéma `allOf`). | Documentaire |
| `spec.runtime` {port ≥ 1024, healthPath, size, replicas ≤ 3, runAsUser, command, args, env non secrets} | natif | Workload (container, endpoint HTTP) + `environmentConfigs` du CCT (`size`, `replicas`) | Interdit : c'est le rôle de `values.yaml` |
| `spec.storage` : objet {profile `block-rwo`, mountPath, size} **ou** liste E8 (§1.1) | non | ClusterTrait `persistent-volume-claim` (upstream, plus le paramètre `dataClass` de T-025) par volume, StorageClass lue dans `clusters/<cluster>/capabilities.yaml`, `update.strategy: Recreate` imposée, quota `pvcs` de la cellule ajusté. Sur OKE : `oci-bv`, **50 Gi minimum facturés** sur un quota de 200 Go [S], jamais Longhorn. | `values.yaml` |
| `spec.database` {engine `postgres`, instance `lab-pg` \| `pg-shared`, envVar} | non | Resource du ClusterResourceType listé pour l'instance dans les capabilities du cluster + `dependencies.resources[].envBindings {url: <envVar>}`. `pg-shared` n'est admis **nulle part** aujourd'hui. | Interdit |
| `spec.secrets[]` {env, key, property} | non | `SecretReference` (store `dataplane.secretStore`, ESO) + `env[].valueFrom.secretKeyRef`. Clé préfixée `<NAME>_` (CI). **Jamais de valeur.** | ExternalSecret rendu à côté du chart (`capabilities.secretStore`) |
| `spec.identity.oidc` {provider `thunderid` \| `authentik`, issuer `https://`, clientId, clientSecretKey, allowedGroups, adminGroup} | non | Variables d'env de l'app + SecretReference du secret client. ThunderID : impose `network.allowIdp` ou `public-internet`. Authentik : impose `allowedGroups` et un egress `{fqdn: <hôte de l'issuer>, ports: [443]}`. | `values.yaml` |
| `spec.exposure` {mode `private` par défaut, host, auth} | oui | Visibilité de l'endpoint : `internal` (private) ou `external` (public). `public` exige un `host` et un `auth` différent de `none`. Sur OKE, l'accès public passe par Cloudflare Tunnel vers le Service ClusterIP de kgateway : **aucun LoadBalancer OCI**. | HTTPRoute rendu à côté |
| `spec.network` {egress `none` \| `public-internet` \| liste E3, allowIdp} | oui | Paramètres du ClusterProjectType `cell-restricted` (§1.1) | NetworkPolicy et CiliumNetworkPolicy à côté (§2.4) |
| `spec.data` {class `ephemeral`\|`rebuildable`\|`useful`\|`irreplaceable`} (T-025, ADR-0008, G8) | oui si `database` ou `storage` | Label `platform.smadja.dev/data-class` : namespace de cellule (paramètre `dataClass` du CPT), PVC (paramètre `dataClass` du ClusterTrait `persistent-volume-claim`), Resource et objets de la base (CRT `cnpg-lab-db`). `irreplaceable` est refusé par la CI comme `backup.class: irreplaceable`. | Idem |
| `spec.backup` {class, mechanism `none`\|`cnpg`\|`velero`, retention, rpo, rto} | oui | Labo : `none` ou `regenerable`. `irreplaceable` est **refusé par la CI** tant qu'aucune restauration hors Oracle n'est prouvée vers R2 (D-2026-11-14-03). `mechanism` doit figurer dans les capabilities du cluster (aujourd'hui : `none` partout). | Idem |
| `spec.workloads[]`, `spec.jobs[]`, `spec.securityExceptions[]` | non | §1.1 (E6, E7, E12) | Interdits |
| `spec.observability` {metrics {enabled, path, port}, alerts} | oui | Annotations de scrape. Sur OKE, export Grafana Cloud existant (kube-ops `oracle-a1/observability`). Pas d'observability plane OpenChoreo (budget). | Idem |
| `spec.update` {strategy, automerge `digest`\|`patch`\|`minor`} | non | Paramètre `strategy` du CCT et règles Renovate (§6) | Renovate |
| `spec.delivery` | calculé | Le générateur échoue si la valeur écrite diffère du calcul | |

### 1.1 Extensions 2026-11-17 (schéma toujours `v2alpha1`)

Tous les champs ajoutés sont **optionnels**. Aucune app existante ne change de sens : pas de `v2alpha2`, pas de migration. La politique de chaque cluster vit dans `clusters/<cluster>/capabilities.yaml` (schéma `schema/capabilities.schema.json`). Ce qui n'y figure pas est refusé. La modifier est une décision plateforme, en PR revue, jamais une PR d'app.

| Champ | Objet rendu | Primitive de sécurité | Refus (CI `appgen validate`) |
|---|---|---|---|
| `network.egress: [{fqdn\|fqdnPattern, ports}]` (E3) | Paramètre CPT `egressFQDNs` → CiliumNetworkPolicy `egress-fqdn` (règle DNS + `toFQDNs`) | Allowlist L7 DNS, default-deny conservé | Cluster sans Cilium (k3d) ; IP, `*.internal`, `*.local`, `*.svc`, `metadata.*` ; motif plus large que `*.domaine.tld` ; règle sans port |
| `network.egress: [{cidr, ports}]` (E3) | Paramètre CPT `egressCIDRs` → NetworkPolicy `egress-allowlist` (`ipBlock`, `except` calculés) | Allowlist L3/L4. Les réseaux privés, CGNAT et link-local sont exclus d'office | `0.0.0.0/0` (passer par `public-internet`), plage plus large que /8, `169.254.0.0/16` (IMDS) **toujours**, CIDR privé absent de `capabilities.privateEgressCIDRs`, adresse non canonique |
| `network.egress: [{app, workload?, envVar?}]` (E3) | `Workload.dependencies.endpoints` (visibilité `namespace`) + paramètre CPT `egressApps` → NetworkPolicy vers `openchoreo.dev/project`/`component` du même environnement. L'endpoint cible reçoit la visibilité `namespace`. | Isolation inter-cellules conservée : seul l'appelant déclaré a l'egress | App inconnue, elle-même, non native, autre cluster, absente d'un environnement |
| `network.egress: none \| public-internet` | Inchangé (alias historiques) | — | — |
| `database.instance` (E1) | Resource du `resourceType` de l'instance ; si ≠ `lab-pg`, paramètres CPT `databaseNamespace` et `databaseCluster` | Egress PG limité à l'instance | Instance absente des capabilities (`pg-shared` partout aujourd'hui) |
| `identity.oidc.provider/allowedGroups/adminGroup` (E2) | Env de l'app (`OAUTH2_CLIENT_ID` injecté), annotations catalogue `oidc-provider`, `oidc-allowed-groups` | Secret client par référence. Liaison des groupes **côté IdP** (blueprint Authentik ou ThunderID, hors générateur [S]) | IdP absent des capabilities ; authentik sans `allowedGroups` ou sans egress vers l'issuer ; `adminGroup` hors `allowedGroups` ; `OAUTH2_ADMIN_GROUP` ≠ `adminGroup` ; issuer non `https` |
| `workloads[]` {name, kind `Deployment`\|`StatefulSet`, image, runtime, database, secrets} (E6) | 1 Component, Workload, ComponentRelease et ReleaseBinding par workload (`<app>-<nom>`), CCT `worker-restricted` (sans port) ou `statefulset-restricted`. Endpoint visibilité `project`. | Même cellule, jamais exposé ; secrets et base par liste explicite | `main` réservé, doublon, secret non déclaré, secret en clair, **sidecar** (Workload v1.3.3 = 1 conteneur [C]), base absente |
| `jobs[]` {name, schedule, timeZone, image, runtime, database, secrets} (E7) | Component CCT `cronjob-restricted`, `concurrencyPolicy: Forbid`, `schedule` dans `componentTypeEnvironmentConfigs` | Même durcissement, pas de volume | Cron invalide, port, volume monté |
| `storage: [{name, profile block-rwo\|rwx-shared, mountPath, size, workload, readOnly}]` (E8) | 1 instance du trait PVC par volume (`accessMode` RWX si besoin), `persistent-volume-claim-sts` pour un StatefulSet, quota `pvcs` de la cellule | Classe imposée par cluster, RWO ⇒ 1 réplica | Profil absent du cluster (RWX sur k3d et OKE), RWO avec réplicas > 1, doublon, volume sur un job |
| `backup.mechanism` + `retention` (E9) | Annotation catalogue `platform.smadja.dev/backup`. Les objets de sauvegarde (ScheduledBackup de l'instance, Schedule Velero) restent à la plateforme. | Pas de promesse sans mécanisme admis | Mécanisme absent des capabilities, `cnpg` sans instance sauvegardée, `velero` sans volume, pas de `retention` |
| `securityExceptions[]` {rule, workload, reason ≥ 20 car., expires, approver} (E12) | `writable-rootfs` : paramètre CCT `readOnlyRootFilesystem: false` (PSA restricted conservée). `run-as-root` : CCT `deployment/service-root-exception` + paramètre CPT `podSecurity: baseline` pour **cette** cellule seulement. Annotation catalogue. | Exception nominative, motivée, datée. La PSA n'est jamais désactivée globalement. Drop ALL, seccomp et absence d'escalade restent imposés. | Expirée (date du jour), au-delà de 90 jours, workload inconnu, doublon, `run-as-root` hors Deployment avec endpoint ou avec `runAsUser` |

**Cilium absent (k3d).** Une règle FQDN est **refusée**. Avec `--allow-unenforced-fqdn` (labo seulement), elle devient un avertissement. L'aperçu `previews/…/ciliumnetworkpolicy-egress-fqdn.yaml` est alors marqué `platform.smadja.dev/enforced: "false"`, et `egressFQDNs` n'est **pas** transmis au Project. Le default-deny bloque donc ces flux : l'échec est fermé, l'app est cassée mais rien ne s'ouvre.

**AIOStreams (uid 0).** Le pilote tourne en uid 65532 imposé, sans exception. Si l'image l'exige, voici la voie d'exception :

```yaml
securityExceptions:
  - {rule: run-as-root, reason: "image upstream en uid 0, correctif demandé en amont", expires: "2027-01-31", approver: "user:default/paul"}
```

Elle n'est rendable qu'après la livraison de la CCT et du paramètre CPT par platform/ (§7.4).

## 2. Exemples

### 2.1 whoami : natif, stateless

```yaml
# apps/whoami/app.yaml
apiVersion: platform.smadja.dev/v2alpha1
kind: App
metadata:
  name: whoami
  owner: user:default/paul
  description: Echo HTTP de diagnostic
spec:
  source:
    image: traefik/whoami:v1.10.3@sha256:43a68d10b9dfcfc3ffbfe4dd42100dc9aeaf29b3a5636c856337a5940f1b4f1c  # digest repris de kube-ops idp-e2e
  cluster: k3d
  environments: [production]
  profile: stateless
  runtime: {port: 8080, args: ["--port", "8080"], healthPath: /health, size: small}
  exposure: {mode: private, auth: none}
  network: {egress: none}
  backup: {class: none}
  observability: {metrics: {enabled: false}}
```

### 2.2 Miniflux : natif + CNPG `lab-pg` + OIDC ThunderID

```yaml
# apps/miniflux/app.yaml
apiVersion: platform.smadja.dev/v2alpha1
kind: App
metadata:
  name: miniflux
  owner: user:default/paul
  description: Lecteur RSS
  docs: https://miniflux.app/docs/
spec:
  source:
    image: ghcr.io/miniflux/miniflux:2.2.14@sha256:<digest résolu par Renovate>   # placeholder : refusé par le schéma tant qu'il n'est pas épinglé
  cluster: k3d
  environments: [production]
  profile: stateful
  runtime:
    port: 8080
    healthPath: /healthcheck
    size: small
    env:
      RUN_MIGRATIONS: "1"
      BASE_URL: https://miniflux.lab.smadja.dev
      OAUTH2_PROVIDER: oidc
      OAUTH2_OIDC_DISCOVERY_ENDPOINT: https://thunder.lab.smadja.dev   # [S] issuer ThunderID joignable par le navigateur ET par le pod
      OAUTH2_REDIRECT_URL: https://miniflux.lab.smadja.dev/oauth2/oidc/callback
      OAUTH2_USER_CREATION: "1"
  database: {engine: postgres, instance: lab-pg, envVar: DATABASE_URL}
  secrets:
    - {env: OAUTH2_CLIENT_SECRET, key: MINIFLUX_OAUTH2_CLIENT_SECRET}
  identity:
    oidc: {provider: thunderid, issuer: https://thunder.lab.smadja.dev, clientId: miniflux, clientSecretKey: MINIFLUX_OAUTH2_CLIENT_SECRET, adminGroup: admin}
  exposure: {mode: public, host: miniflux.lab.smadja.dev, auth: app-oidc}
  network: {egress: public-internet}       # flux RSS sur des hôtes arbitraires (E-revue K7)
  backup: {class: regenerable}
  observability: {metrics: {enabled: true, path: /metrics}}   # METRICS_COLLECTOR=1 à ajouter
```

Le client OAuth2 `OAUTH2_CLIENT_ID=miniflux` est injecté par le générateur depuis `identity.oidc.clientId`. La clé Doppler `MINIFLUX_PG_PASSWORD` est créée une fois, hors Git (même convention que kube-ops `app-database.example.tmpl`).

### 2.3 AIOStreams : natif, SQLite sur PVC, egress contrôlé

Il passe en natif : une seule image, un seul PVC RWO, du HTTP. Aucun chart officiel n'a été trouvé [S], et le natif teste mieux le CCT.

```yaml
# apps/aiostreams/app.yaml
apiVersion: platform.smadja.dev/v2alpha1
kind: App
metadata:
  name: aiostreams
  owner: user:default/paul
  description: Agrégateur d'addons Stremio
spec:
  source:
    image: ghcr.io/viren070/aiostreams:<tag>@sha256:<digest>   # [S] dépôt d'image à confirmer ; arm64 à vérifier
  cluster: k3d
  environments: [production]
  profile: stateful
  runtime:
    port: 3000                       # [S]
    healthPath: /api/v1/status       # [S]
    size: small
    env: {DATABASE_URI: "sqlite://./data/db.sqlite", BASE_URL: https://aiostreams.lab.smadja.dev}
  storage: {profile: block-rwo, mountPath: /app/data, size: 1Gi}   # OKE : arrondi à 50 Gi facturés
  secrets:
    - {env: SECRET_KEY, key: AIOSTREAMS_SECRET_KEY}
    - {env: ADDON_PASSWORD, key: AIOSTREAMS_ADDON_PASSWORD}
  exposure: {mode: public, host: aiostreams.lab.smadja.dev, auth: app-password}   # les clients Stremio ne passent pas un login navigateur
  network: {egress: public-internet} # addons et débrideurs multiples : RFC1918, CGNAT et IMDS exclus
  backup: {class: regenerable}
  observability: {metrics: {enabled: false}}
  update: {strategy: Recreate}       # imposé par le schéma (PVC RWO)
```

### 2.4 Parcours Helm GitOps : illustratif, non activé

Ce fichier vit sous `docs/examples/`, jamais sous `apps/`. Le générateur ne lit que `apps/*/app.yaml`.

```yaml
# docs/examples/podinfo/app.yaml  (+ values.yaml : securityContext restricted, resources)
apiVersion: platform.smadja.dev/v2alpha1
kind: App
metadata: {name: podinfo, owner: user:default/paul, description: Démo du parcours Helm, lifecycle: experimental}
spec:
  source: {chart: {repo: oci://ghcr.io/stefanprodan/charts, name: podinfo, version: 6.9.2, digest: "sha256:<digest>"}}
  cluster: k3d
  environments: [production]
  profile: stateless
  exposure: {mode: private, auth: none}
  network: {egress: none}
  backup: {class: none}
  observability: {metrics: {enabled: true}}
```

Le catalogue (`catalog-info.yaml`) le marque `openchoreo.dev/managed: "false"`, avec l'owner, la doc et l'état, c'est-à-dire la santé Argo lue par `app-status`. **OpenChoreo n'en voit rien.**

Rendu par `appgen` pour chaque environnement (`generated/helm/<n>/<env>/`) :

- `application.yaml` : une Application Argo CD multi-source. Source 1 : le chart, avec `targetRevision` = version exacte et l'annotation `chart-digest`. Source 2 : `$values` (`apps/<n>/values.yaml`). Source 3 : `resources/`. L'Application n'a **pas** de finalizer `resources-finalizer` : la supprimer conserve les ressources. C'est l'équivalent de `preserveResourcesOnDeletion`, qui n'existe que sur ApplicationSet. Autres réglages : `automated.prune: false`, `selfHeal`, namespace `lab-<n>-<env>` créé avec les labels PSA `restricted` (`managedNamespaceMetadata`), `FailOnSharedResource`, `PruneLast`, `ServerSideApply`.
- `resources/` : NetworkPolicy `default-deny` et `allow-dns-and-namespace`, ResourceQuota sans LoadBalancer ni NodePort, egress (profil ou règles E3, CNP si FQDN), ExternalSecret si `secrets[]`.
- Refus : chart sans `digest` ou sans version exacte, `values.yaml` absent, `hostNetwork`/`hostPID`/`hostIPC`/`privileged`/`allowPrivilegeEscalation` à `true`, `hostPath`, Service `LoadBalancer`/`NodePort`, `runAsUser: 0`, valeur de type secret, `exposure: public` (HTTPRoute non livré), `runtime`/`workloads`/`jobs`/`securityExceptions`.
- Limites [S] : Argo ne vérifie pas le digest d'un chart. La vérification `helm pull` + sha256 est une étape CI à ajouter. Le `repoURL` OCI est rendu sans préfixe `oci://`, à confirmer avec la version d'Argo installée. L'AppProject `lab-helm` reste à créer. Une annotation `Prune=false` par ressource ne peut venir que du chart (values).

## 3. Règle de choix automatique du parcours

```
si source.chart                                   -> helm
sinon (source.image) :
  natif si TOUTES les conditions suivantes sont vraies :
    1 conteneur par workload, sans sidecar ni init applicatif (workloads[] et jobs[] = composants séparés)
    au moins 1 endpoint HTTP sur main
    port >= 1024, PSA restricted possible (non-root, pas de capabilities, rootfs RO + /tmp),
      sauf exception E12 nominative et datée
    volumes aux profils admis par le cluster, replicas = 1 si volume RWO
    base = instance admise par les capabilities du cluster (lab-pg aujourd'hui)
    ni CRD, ni opérateur, ni RBAC applicatif, ni hostNetwork
  sinon -> REFUS « utiliser un chart officiel (parcours helm) », jamais un fallback silencieux
```

Le skill `migrate-to-openchoreo` (openchoreo/skills) peut servir à établir ce verdict pour une app existante.

## 4. Générateur : de `app.yaml` aux manifests

**Choix : un script CI `tools/appgen` qui produit des manifests commités** (motif « rendered manifests »). Un ApplicationSet seul ne suffit pas : le nom d'une ComponentRelease vient d'`occ` (`internal/occ/fsmode/generator/namer.go`) [C], et Argo ne sait pas l'exécuter.

1. `appgen validate` : schéma, règle §3, préfixe `<NAME>_` des clés, `backup.class` admissible, unicité des hôtes.
2. `appgen render` écrit sous `gitops/` (disposition de sample-gitops) :

   | Fichier généré (natif) | Kind | Conditions |
   |---|---|---|
   | `namespaces/default/projects/<n>/project.yaml` | Project (`type: {kind: ClusterProjectType, name: cell-restricted}`, paramètres egress, database, allowIdp, quota) | toujours |
   | `…/project-bindings/<n>-<env>.yaml` | ProjectReleaseBinding, `projectRelease` seulement s'il est épinglé (`pins/project-releases.yaml`, A3) ; sinon initialisé une fois par le contrôleur | par environnement |
   | `…/components/<n>/component.yaml` | Component (`componentType: {kind: ClusterComponentType, name: deployment/service-restricted}`, `autoDeploy: false`, traits) | toujours |
   | `…/components/<n>/workload.yaml` | Workload (image, env, endpoints, `dependencies.resources`) | toujours |
   | `…/secret-references/<n>-*.yaml` | SecretReference | si `secrets` ou `oidc` |
   | `…/resources/<n>-db.yaml` + `…/resource-bindings/<n>-db-<env>.yaml` | Resource `cnpg-lab-db` + ResourceReleaseBinding | si `database` |
   | `…/components/<n>/releases/<n>-<hash>.yaml` | ComponentRelease (nom = hash de la spec). **Ajout seul** : les releases déjà dans `generated/` sont conservées et réécrites à l'identique (A2) | toujours |
   | `…/components/<n>/release-bindings/<n>-<env>.yaml` | ReleaseBinding (`occ releasebinding generate`), avec `componentTypeEnvironmentConfigs` {size, replicas} | par environnement |
   | `catalog/<n>/catalog-info.yaml` | Entité Backstage (owner, doc, lifecycle) | toujours |

   Extensions : un jeu Component/Workload/ComponentRelease/ReleaseBinding par entrée de `workloads[]` et de `jobs[]`. Avec des règles egress E3, `previews/<n>/<env>/` contient les NetworkPolicy et CiliumNetworkPolicy que le CPT rendra. Ce dossier n'est pas synchronisé : il sert à la revue de PR et à kubeconform. L'équivalence avec la CEL du CPT n'est pas prouvée hors cluster [S].

   Parcours Helm : `helm/<n>/<env>/application.yaml` + `resources/` (§2.4). Ils remplacent l'ancien `config.yaml` destiné à un ApplicationSet. Aucune app Helm n'est activée dans le pilote.
   Annotations Argo émises par appgen (A1) : `argocd.argoproj.io/sync-options: Prune=false` sur Component et Resource, `Prune=false,Delete=false` sur ComponentRelease.

   Refus au rendu : endpoint `internal`/`external` sans `gateway.ingress.<v>` sur l'Environment de `platform/` (G1) ; passage `RollingUpdate → Recreate` d'un Deployment déjà déployé, détecté par une release `RollingUpdate` présente dans `releases/` (A4) ; release de `releases/` dont la spec ne correspond plus à son nom (modifiée à la main).

   Quota de cellule (A7) : somme des requests **plus** le surplus d'un RollingUpdate, `ceil(replicas × 25 %)` pods (maxSurge par défaut de Kubernetes : le CCT ne le fixe pas). Recreate et CronJob : aucun surplus.
3. `appgen pin-resource <n> <env>` : 2ᵉ PR. Elle lit `Resource.status` (latest release) et écrit `spec.resourceRelease`. C'est le seul pas qui exige une lecture du cluster (§0.6). En Phase 0, la lecture `kubectl` est locale. Sur OKE, il faut l'accès opérateur du gate.
   `appgen pin-project <n> <env> <release>` : même mécanisme pour le ProjectReleaseBinding (A3). Valeur : `status.latestRelease.name` du Project, lue après le merge de la PR qui change ses paramètres.
4. CI : `appgen check --base origin/main` (pas de dérive ; chaque `releaseName` pointe un fichier de `releases/` ; aucune release supprimée d'un composant conservé ; avertissement « 2ᵉ PR pin-project » si les paramètres d'un Project existant changent sans pin). Elle refuse `autoDeploy: true`, deux bindings pour un même (composant, environnement) (issue #5371), un kind cluster-scoped hors `gitops/platform-shared/`, et une image sans digest.

Argo CD, applications fixes, écrites une fois :

- `lab-crds` (wave -1, `ServerSideApply=true`) : CRD OpenChoreo v1.3.3 versionnées dans `gitops/crds/`. Les charts CP et DP sont installés avec `skipCrds`.
- `lab-platform` (wave 0) : `platform-shared/` (CCT, CPT, CRT, ClusterTrait PVC, VAP), `namespaces/default/platform/` (Environment, DeploymentPipeline, DataPlane), `lab-pg/` (Namespace, Cluster CNPG, NetworkPolicy).
- ApplicationSet `lab-o` (wave 1, T-491) : une Application `lab-o-<app>` par dossier de `namespaces/default/projects/` (app OKE stateless ; les autres sont dans `exclude`).
- Health checks Lua des kinds OpenChoreo (ReleaseBinding, ProjectReleaseBinding, ResourceReleaseBinding, Component ; condition `Ready`) : `platform/install/argocd/health/values-openchoreo-health.yaml`, fragment de values du chart argo-cd (A5). Sans eux, Argo affiche `Healthy` sur un binding en échec.

Deux AppProjects (correction de K8 dans E-revue) :

- `lab-platform` : cluster-scoped `openchoreo.dev`, `admissionregistration`, Namespace `lab-pg`.
- `lab-o` (ex `lab-apps`) : `openchoreo.dev` namespacé, destination `default` uniquement, **jamais `dp-*`**, `orphanedResources.warn: true`.

## 5. Propriété : un objet = un contrôleur

| Objet | Unique propriétaire | Règle Argo |
|---|---|---|
| CRD, CCT, CPT, CRT, ClusterTrait, Environment, DeploymentPipeline, DataPlane, VAP | Git → Argo `lab-platform` | `prune: true`, selfHeal |
| Project, Workload, SecretReference, ReleaseBinding (`releaseName` dans Git), ResourceReleaseBinding (`resourceRelease` dans Git) | Git → Argo `lab-o-<app>` | synchro automatique sans prune, selfHeal. Retirer la **dernière** app vide l'Application : en `automated`, Argo refuse (« auto-sync will wipe out all resources », T-RETRAIT-1). Chemin retenu : avec l'ApplicationSet `lab-o` (une Application par app), le retrait d'une app supprime son Application (`preserveResourcesOnDeletion: true`, NOT_TESTED) : plus de cas « Application vide ». Pas d'app sentinelle. |
| ComponentRelease | Git (généré par appgen), immuable, **ajout seul** dans `releases/` | **`Prune=false,Delete=false`** (annotation émise par appgen) : un binding ne doit jamais pointer sur une release purgée. Garder le fichier dans Git évite l'OutOfSync permanent `requiresPruning` (T-PRUNE-STATUS). Purge = retrait du composant entier. |
| Component, Resource | Git → Argo | **`Prune=false`** (annotation émise par appgen) : leurs finalizers suppriment les releases et les objets rendus (D[C], `component/controller_finalize.go`). Au retrait d'une app, ils restent et se suppriment par geste opérateur après la PR. |
| ProjectReleaseBinding | Git ; `spec.projectRelease` absent de Git tant qu'il n'est pas épinglé | Champ initialisé une fois par le contrôleur, puis jamais avancé (`projectreleasebinding_types.go` l.31-36) [C], prouvé sur k3d (T-PIN-STALE). ServerSideApply : un champ absent de Git n'est pas comparé, **pas d'`ignoreDifferences`** (prouvé, C1). **Toute modification des paramètres du Project (quota, `pvcs`, egress, database) ou du CPT = 2 PR** : la PR 1 change `app.yaml` (nouvelle ProjectRelease, non adoptée) ; la PR 2 `appgen pin-project` écrit la pin, qu'Argo applique en SSA sans conflit (T-PIN-PRB). |
| ProjectRelease, ResourceRelease, RenderedRelease, `status` | Contrôleurs OpenChoreo | Jamais dans Git |
| Tout ce qui est dans `dp-*` (Deployment, Service, HTTPRoute, NetworkPolicy par composant, ExternalSecret, PVC) | Contrôleur OpenChoreo, appliqué par le cluster-agent | Hors AppProject. `kubectl` d'écriture interdit. |
| ExternalSecret et Job rendus par `cnpg-lab-db` dans `lab-pg` | OpenChoreo, via le cluster-agent | Seule écriture du cluster-agent hors `dp-*`, bornée par VAP-1 |
| Namespace `lab-pg`, Cluster CNPG `lab-pg`, NetworkPolicy de `lab-pg` | Git → Argo `lab-platform` | `Prune=false,Delete=false` sur le Cluster |
| Secrets cibles, Pods et PVC CNPG | ESO, opérateur CNPG | — |
| Écritures MCP et console OpenChoreo | **Aucune.** Authz : rôle agent en lecture seule (`ClusterAuthzRoleBinding effect: deny`) | Un objet hors Git est signalé orphelin |

`autoDeploy: false` partout. C'est le défaut du CRD (`component_types.go` l.51-53) [C], réaffirmé par la CI. Avec `true`, le contrôleur réécrit `releaseName`, et Argo et le contrôleur se le disputent en boucle (D[C]).

## 6. Mise à jour et rollback

- **Natif.** Renovate modifie le digest dans `app.yaml` (`automerge: digest` par défaut, jamais pour une version majeure). La CI régénère le Workload, une nouvelle ComponentRelease et le `releaseName` du binding, **dans la même PR**. Au merge, Argo synchronise et le contrôleur rend.
  - Rollback : revenir sur `apps/<n>/app.yaml` puis `appgen render` (le binding revient sur la release précédente, toujours dans `releases/`). Un `git revert` du commit entier supprimerait la nouvelle release du dépôt (A2) : `appgen check --base` le refuse ; garder `generated/…/releases/` (`git checkout HEAD -- generated/` après le revert, puis `render`).
  - Un rollback qui traverse un changement des paramètres du Project doit aussi reculer la pin (`pin-project` vers l'ancienne ProjectRelease), sinon quota et NetworkPolicy restent ceux de la nouvelle.
  - Passage stateless → stateful (`RollingUpdate → Recreate`) sur une app déployée : refusé par appgen (A4, 422 côté API). Chemin : PR de retrait + suppression opérateur du Component, puis PR de ré-ajout. Conservation du PVC au retrait : non prouvée.
  - Promotion `development` → `production` = une PR `appgen promote` qui ne change qu'une ligne.
  - Une migration de schéma n'est pas réversible. Dans le labo, on recrée la base.
- **Helm.** Renovate modifie `chart.version` et `digest`, avec `minimumReleaseAge` (convention onedr0p). Rollback = `git revert`. `prune: false` dès que l'app est stateful.

## 7. Objets custom minimaux (contenu vérifié contre les types v1.3.3)

### 7.1 ClusterComponentType `service-restricted`

Copie de `samples/getting-started/component-types/service.yaml`. Seuls les écarts sont montrés. Les entrées `service`, `httproute-internal`, `env-config`, `file-config`, `secret-env-external` et `secret-file-external` sont reprises telles quelles. Le filtre CORS `*` est retiré de `httproute-external`.

```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterComponentType
metadata:
  name: service-restricted     # Adapted from openchoreo@v1.3.3 samples/.../service.yaml (Apache-2.0)
spec:
  workloadType: deployment     # Enum ; la CEL du CRD exige une resource id=deployment (clustercomponenttype_types.go l.11) [C]
  allowedWorkflows: []         # vide = aucun workflow : images préconstruites seulement [C commentaire du type]
  allowedTraits:
    - {kind: ClusterTrait, name: persistent-volume-claim}   # trait upstream inchangé (AIOStreams)
  parameters:
    openAPIV3Schema:
      type: object
      properties:
        runAsUser: {type: integer, minimum: 1000, default: 65532}
        strategy: {type: string, enum: [RollingUpdate, Recreate], default: RollingUpdate}
        publicAuth: {type: string, enum: [none, app-oidc, app-password, cloudflare-access], default: none}
  environmentConfigs:
    openAPIV3Schema:
      type: object
      properties:
        replicas: {type: integer, minimum: 0, maximum: 3, default: 1}
        size: {type: string, enum: [small, medium], default: small}
  preRenderValidations:        # « validations » est déprécié ; les deux sont exclusifs (CEL du CRD) [C]
    - rule: "${size(workload.endpoints) > 0}"
      message: "au moins un endpoint"
    - rule: "${workload.container.image.matches('@sha256:[a-f0-9]{64}$')}"
      message: "image épinglée par digest obligatoire"
    - rule: '${workload.endpoints.exists(name, ep, "external" in ep.visibility) ? parameters.publicAuth != "none" : true}'
      message: "exposition publique sans authentification interdite"
    - rule: '${parameters.strategy == "Recreate" ? environmentConfigs.replicas <= 1 : true}'
      message: "PVC RWO : replicas <= 1"
  resources:
    - id: deployment
      template:
        apiVersion: apps/v1
        kind: Deployment
        metadata: {name: "${metadata.name}", namespace: "${metadata.namespace}", labels: "${metadata.labels}"}
        spec:
          replicas: ${environmentConfigs.replicas}
          strategy: {type: "${parameters.strategy}"}
          selector: {matchLabels: "${metadata.podSelectors}"}
          template:
            metadata: {labels: "${metadata.podSelectors}"}
            spec:
              automountServiceAccountToken: false
              securityContext:
                runAsNonRoot: true
                runAsUser: ${parameters.runAsUser}
                runAsGroup: ${parameters.runAsUser}
                fsGroup: ${parameters.runAsUser}
                seccompProfile: {type: RuntimeDefault}
              containers:
                - name: main
                  image: ${workload.container.image}
                  command: '${has(workload.container.command) ? workload.container.command : oc_omit()}'
                  args: '${has(workload.container.args) ? workload.container.args : oc_omit()}'
                  securityContext:
                    allowPrivilegeEscalation: false
                    readOnlyRootFilesystem: true
                    capabilities: {drop: [ALL]}
                  resources: '${ {"small": {"requests": {"cpu": "50m", "memory": "128Mi"}, "limits": {"cpu": "250m", "memory": "256Mi"}}, "medium": {"requests": {"cpu": "200m", "memory": "256Mi"}, "limits": {"cpu": "500m", "memory": "512Mi"}}}[environmentConfigs.size] }'
                  env: ${dependencies.toContainerEnvs()}
                  envFrom: ${configurations.toContainerEnvFrom()}
                  volumeMounts: '${configurations.toContainerVolumeMounts() + dependencies.toContainerVolumeMounts() + [{"name": "tmp", "mountPath": "/tmp"}]}'
              volumes: '${configurations.toVolumes() + dependencies.toVolumes() + [{"name": "tmp", "emptyDir": {}}]}'
    # ... service, httproute-*, env-config, file-config, secret-*-external : identiques au sample
  postRenderValidations:       # après tous les traits ; target = GVK (+ where), mustMatch=true par défaut (trait_types.go l.70-130, 244-260) [C]
    - target: {group: apps, version: v1, kind: Deployment}
      rule: >-
        ${resource.spec.template.spec.securityContext.runAsNonRoot == true &&
          resource.spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault" &&
          !(has(resource.spec.template.spec.hostNetwork) && resource.spec.template.spec.hostNetwork) &&
          resource.spec.template.spec.containers.all(c, has(c.securityContext) &&
            c.securityContext.allowPrivilegeEscalation == false &&
            c.securityContext.readOnlyRootFilesystem == true &&
            "ALL" in c.securityContext.capabilities.drop)}
      message: "securityContext restricted altéré"
    - {target: {group: rbac.authorization.k8s.io, version: v1, kind: ClusterRoleBinding, mustMatch: false}, rule: "${false}", message: "kind interdit"}
    - {target: {group: rbac.authorization.k8s.io, version: v1, kind: ClusterRole, mustMatch: false}, rule: "${false}", message: "kind interdit"}
    - {target: {group: rbac.authorization.k8s.io, version: v1, kind: RoleBinding, mustMatch: false}, rule: "${false}", message: "kind interdit"}
    - target: {group: "", version: v1, kind: Service, mustMatch: false}
      rule: '${resource.spec.type == "ClusterIP"}'
      message: "Service ClusterIP seulement (pas de LoadBalancer OCI ni de NodePort)"
```

Une liste blanche de kinds est **impossible** : `target` exige un GVK [C]. On ne peut que refuser par kind, d'où VAP-1 en complément.

### 7.2 ClusterProjectType `cell-restricted`

```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterProjectType      # resources = manifests namespacés appliqués au namespace de cellule (clusterprojecttype_types.go l.29-37) [C]
metadata: {name: cell-restricted}   # Adapted from openchoreo@v1.3.3 samples/.../cluster-project-types/default.yaml
spec:
  parameters:
    openAPIV3Schema:
      type: object
      properties:
        egress: {type: string, enum: [none, public-internet], default: none}
        database: {type: boolean, default: false}
        allowIdp: {type: boolean, default: false}
        quota:
          type: object
          default: {}
          properties:
            cpu: {type: string, default: "300m"}
            memory: {type: string, default: "512Mi"}
            pvcs: {type: string, default: "0"}
  environmentConfigs:
    openAPIV3Schema:
      type: object
      properties:
        idpNamespace: {type: string, default: thunder}   # [S] namespace de ThunderID
  resources:
    - id: cell-namespace
      template:
        apiVersion: v1
        kind: Namespace
        metadata:
          name: ${metadata.namespace}
          # constantes en 2e argument : un label d'environnement ne peut pas les écraser (C[C])
          labels: '${oc_merge(metadata.labels, {"pod-security.kubernetes.io/enforce": "restricted", "pod-security.kubernetes.io/enforce-version": "latest", "platform.smadja.dev/pg-client": parameters.database ? "true" : "false"})}'
    - id: default-deny
      template: {apiVersion: networking.k8s.io/v1, kind: NetworkPolicy, metadata: {name: default-deny, namespace: "${metadata.namespace}"}, spec: {podSelector: {}, policyTypes: [Ingress, Egress]}}
    - id: allow-dns-and-cell
      template:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata: {name: allow-dns-and-cell, namespace: "${metadata.namespace}"}
        spec:
          podSelector: {}
          policyTypes: [Ingress, Egress]
          ingress: [{from: [{podSelector: {}}]}]
          egress:
            - to: [{podSelector: {}}]
            - to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}, podSelector: {matchLabels: {k8s-app: kube-dns}}}]
              ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
    - id: egress-pg
      includeWhen: ${parameters.database}
      template:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata: {name: egress-lab-pg, namespace: "${metadata.namespace}"}
        spec:
          podSelector: {}
          policyTypes: [Egress]
          egress: [{to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: lab-pg}}, podSelector: {matchLabels: {cnpg.io/cluster: lab-pg}}}], ports: [{protocol: TCP, port: 5432}]}]
    - id: egress-idp
      includeWhen: ${parameters.allowIdp}
      template:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata: {name: egress-idp, namespace: "${metadata.namespace}"}
        spec: {podSelector: {}, policyTypes: [Egress], egress: [{to: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: "${environmentConfigs.idpNamespace}"}}}]}]}
    - id: egress-public
      includeWhen: '${parameters.egress == "public-internet"}'
      template:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata: {name: egress-public-internet, namespace: "${metadata.namespace}"}
        spec:
          podSelector: {}
          policyTypes: [Egress]
          egress:
            - to: [{ipBlock: {cidr: 0.0.0.0/0, except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16]}}]
              ports: [{protocol: TCP, port: 80}, {protocol: TCP, port: 443}]
    - id: quota
      template:
        apiVersion: v1
        kind: ResourceQuota
        metadata: {name: cell-quota, namespace: "${metadata.namespace}"}
        spec:
          hard:
            requests.cpu: ${parameters.quota.cpu}
            requests.memory: ${parameters.quota.memory}
            persistentvolumeclaims: ${parameters.quota.pvcs}
            services.loadbalancers: "0"
            services.nodeports: "0"
    - id: limits
      template:
        apiVersion: v1
        kind: LimitRange
        metadata: {name: cell-limits, namespace: "${metadata.namespace}"}
        spec: {limits: [{type: Container, default: {cpu: 250m, memory: 256Mi}, defaultRequest: {cpu: 50m, memory: 64Mi}, max: {cpu: 500m, memory: 512Mi}}]}
```

L'ingress depuis la Gateway est ouvert par les NetworkPolicy **par composant** que rend OpenChoreo (`internal/networkpolicy/networkpolicy.go` l.47-207, avec une variante Cilium) [C]. Les règles s'additionnent au default-deny. Sur OKE, le blocage IMDS cluster-wide reste à la CCNP de la baseline #1620. L'`except 169.254.0.0/16` ne couvre que les cellules.

### 7.3 ClusterResourceType `cnpg-lab-db`

Il vise l'instance CNPG éphémère `lab-pg` : base dédiée, rôle dédié, `REVOKE CONNECT FROM PUBLIC`.

Faisabilité [C] : le pipeline Resource **ne force pas** `metadata.namespace` (`internal/pipeline/resource/types.go` l.110-113). Un template peut donc viser `lab-pg`. La `Database` CNPG n'a pas de champ de grant (kube-ops `app-database.example.tmpl`, CRD vérifiée). Le rôle, la base et la révocation passent donc par un Job `psql` idempotent, qui tourne **dans `lab-pg`**. Le secret superuser ne quitte jamais ce namespace, ce qui évite le défaut du rapport B. Le mot de passe applicatif vient du store ESO (clé `<NAME>_PG_PASSWORD`) des deux côtés : pas de copie entre namespaces.

```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterResourceType
metadata: {name: cnpg-lab-db}
spec:
  retainPolicy: Retain                       # enum Delete|Retain, défaut Delete (resourcetype_types.go l.23-27) [C]
  parameters:
    openAPIV3Schema:
      type: object
      required: [database, passwordKey]
      properties:
        database: {type: string, pattern: "^[a-z][a-z0-9_]{1,30}$"}
        passwordKey: {type: string, pattern: "^[A-Z][A-Z0-9_]{2,63}_PG_PASSWORD$"}
  outputs:                                   # exactement un de value|secretKeyRef|configMapKeyRef (CEL du CRD) [C]
    - {name: host, value: "lab-pg-rw.lab-pg.svc.cluster.local"}
    - {name: port, value: "5432"}
    - {name: database, value: "${parameters.database}"}
    - {name: username, value: "${parameters.database}"}
    - {name: password, secretKeyRef: {name: "${metadata.name}-pg", key: password}}
    - {name: url, secretKeyRef: {name: "${metadata.name}-pg", key: uri}}
  resources:
    - id: role-secret                        # dans lab-pg, lu par le Job
      template:
        apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata: {name: "${metadata.name}-role", namespace: lab-pg}
        spec:
          refreshInterval: 1h
          secretStoreRef: {name: "${dataplane.secretStore}", kind: ClusterSecretStore}   # resource/types.go l.141-143 [C]
          target: {name: "${metadata.name}-role", creationPolicy: Owner}
          data: [{secretKey: password, remoteRef: {key: "${parameters.passwordKey}"}}]
    - id: init
      readyWhen: "${has(applied.init.status.succeeded) && applied.init.status.succeeded > 0}"
      template:
        apiVersion: batch/v1
        kind: Job
        metadata: {name: "${metadata.name}-pg-init", namespace: lab-pg}
        spec:
          backoffLimit: 6
          template:
            spec:
              restartPolicy: OnFailure
              automountServiceAccountToken: false
              securityContext: {runAsNonRoot: true, runAsUser: 26, seccompProfile: {type: RuntimeDefault}}   # uid 26 des images CNPG [S]
              containers:
                - name: psql
                  image: ghcr.io/cloudnative-pg/postgresql:17.7-standard-trixie@sha256:e079dae5253fa6ed26fc65fda06d515af764dbec392dd4b46b17ab11eebd8131  # même digest que pg-shared OKE
                  securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
                  env:
                    - {name: PGHOST, value: lab-pg-rw}
                    - {name: PGSSLMODE, value: require}
                    - {name: PGUSER, value: postgres}
                    - {name: PGPASSWORD, valueFrom: {secretKeyRef: {name: lab-pg-superuser, key: password}}}  # enableSuperuserAccess: true sur le Cluster lab-pg
                    - {name: APP, value: "${parameters.database}"}
                    - {name: APP_PASSWORD, valueFrom: {secretKeyRef: {name: "${metadata.name}-role", key: password}}}
                  command: [/bin/sh, -ec]
                  # Pas de ${VAR} shell : la syntaxe ${...} est réservée au moteur OpenChoreo.
                  args:
                    - |
                      psql -v ON_ERROR_STOP=1 -v app="$APP" -v pw="$APP_PASSWORD" <<'SQL'
                      SELECT format('CREATE ROLE %I LOGIN', :'app') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app')\gexec
                      ALTER ROLE :"app" WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'pw';
                      SELECT format('CREATE DATABASE %I OWNER %I', :'app', :'app') WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'app')\gexec
                      REVOKE CONNECT ON DATABASE :"app" FROM PUBLIC;
                      GRANT CONNECT ON DATABASE :"app" TO :"app";
                      SELECT 1/(CASE WHEN has_database_privilege('public', :'app', 'CONNECT') THEN 0 ELSE 1 END);
                      SQL
    - id: app-creds                          # dans le namespace de cellule, consommé par envBindings
      template:
        apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata: {name: "${metadata.name}-pg", namespace: "${metadata.namespace}"}
        spec:
          refreshInterval: 1h
          secretStoreRef: {name: "${dataplane.secretStore}", kind: ClusterSecretStore}
          target:
            name: "${metadata.name}-pg"
            creationPolicy: Owner
            template:
              data:
                password: "{{ .password }}"
                uri: "postgresql://${parameters.database}:{{ .password | urlquery }}@lab-pg-rw.lab-pg.svc.cluster.local:5432/${parameters.database}?sslmode=require"
          data: [{secretKey: password, remoteRef: {key: "${parameters.passwordKey}"}}]
```

Côté Argo, `lab-pg` contient :

- un Namespace en PSA `restricted` ;
- un Cluster CNPG `lab-pg` : `instances: 1`, 1 Gi en `local-path` sur k3d, `enableSuperuserAccess: true`, aucune sauvegarde (éphémère), `Prune=false,Delete=false` ;
- une NetworkPolicy : ingress 5432 depuis les namespaces `platform.smadja.dev/pg-client=true` et depuis `lab-pg` (Job, opérateur), egress de `lab-pg` limité au DNS et à `kube-apiserver`.

**Risque [S] à tester :** le Job est immuable. Si le CRT change, la nouvelle ResourceRelease rend un Job différent, et l'apply du cluster-agent peut échouer. Repli : suffixer le nom du Job par une version manuelle (`init-v2`).

### 7.4 Objets à livrer par platform/ pour les extensions

`appgen render` **échoue** (jamais de repli) tant que l'objet requis par une app manque, ou n'en déclare pas les paramètres. Le générateur compare les paramètres qu'il passe à `openAPIV3Schema.properties`. Propositions validées par kubeconform contre les CRD v1.3.3 (la CEL n'est pas évaluée) : `tests/appgen/fixtures/platform-ext/`.

| Objet | Requis par | Contenu |
|---|---|---|
| CPT `cell-restricted` : paramètres `egressCIDRs`, `egressFQDNs`, `egressApps`, `databaseNamespace`, `databaseCluster`, `podSecurity` + ressources `egress-allowlist` (NP) et `egress-fqdn` (CNP) | E3, E1 (`pg-shared`), E12 `run-as-root` | `cell-restricted-egress.yaml` (CEL + validations : pas de `169.254.*`, pas de `0.0.0.0/0`, rien de plus large que /8) |
| CCT `deployment/worker-restricted`, `statefulset/statefulset-restricted`, `cronjob/cronjob-restricted` | E6, E7 | Durcissement identique à `service-restricted`, adapté au workloadType |
| CCT `deployment/service-root-exception` | E12 `run-as-root` | Sans `runAsUser` ni `runAsNonRoot`, mais drop ALL, sans escalade, seccomp, automount=false |
| ClusterTrait `persistent-volume-claim-sts` | E8 sur StatefulSet | Trait PVC upstream, `patches` ciblant `apps/v1 StatefulSet` |

La postRender de `service-restricted` interdit tout `NetworkPolicy` rendu par un trait. L'egress déclaratif passe donc par le CPT, là où vit déjà `egress`, et non par un trait.

### 7.5 Deux VAP natives (hors OpenChoreo, propriété d'Argo `lab-platform`)

- **VAP-1 `cluster-agent-scope`.** Pour `system:serviceaccount:openchoreo-data-plane:cluster-agent` : refus de `clusterroles`, `clusterrolebindings` et `namespaces`, sauf les namespaces `dp-*`. Refus de toute écriture dans `lab-pg` hors `external-secrets.io/ExternalSecret` et `batch/Job`, et refus partout ailleurs. Alternative plus propre : `clusterAgent.rbac.create=false` avec une ClusterRole réduite (E-revue rang 5).
- **VAP-2 `digest-only`.** Pods des namespaces `dp-*` et `lab-pg` : chaque `image` contient `@sha256:`.

## 8. Plan de test des refus (Phase 0 k3d avec Cilium, puis à rejouer sur OKE après le gate)

Chaque test produit une sortie brute archivée dans `evidence/phase0/<n>.txt`. Le refus attendu est exact.

| # | Primitive | Action | Refus attendu |
|---|---|---|---|
| 1 | PSA (CPT) | Pod `privileged: true` / `hostPath` / `hostNetwork` créé dans une cellule `dp-*` | `violates PodSecurity "restricted:latest"` |
| 2 | postRender (CCT) | Trait namespacé de test qui retire `capabilities.drop` | Binding `Synced=False`, message « securityContext restricted altéré » |
| 3 | postRender (CCT) | Trait de test qui rend une `ClusterRoleBinding` | « kind interdit » ; et VAP-1 en seconde barrière : `kubectl --as=…cluster-agent create clusterrolebinding` → `denied` |
| 4 | preRender (CCT) | Workload avec image `:latest` sans digest | « image épinglée par digest obligatoire » ; VAP-2 sur un pod direct |
| 5 | preRender (CCT) | Endpoint `external` avec `publicAuth: none` | « exposition publique sans authentification interdite » |
| 6 | Quota (CPT) | Service `type: LoadBalancer` ou 2ᵉ PVC dans une cellule | `exceeded quota: cell-quota` (et postRender sur le Service) |
| 7 | Default-deny (CPT) | Pod whoami vers `miniflux.<dp-ns>:8080` | timeout ; DNS OK |
| 8 | Egress (CPT) | whoami vers `https://example.com` : timeout. Miniflux vers `https://example.com` : 200. Miniflux vers `169.254.169.254`, `198.51.100.1:443` : timeout | comme indiqué |
| 9 | Isolation SQL (CRT) | 2ᵉ Resource `pgcanary` dans un projet jetable. Credentials Miniflux vers la base `pgcanary` | `FATAL: permission denied for database "pgcanary"` (REVOKE CONNECT) |
| 10 | Isolation réseau PG | whoami (sans `pg-client`) vers `lab-pg-rw:5432` | timeout |
| 11 | Secret admin | `kubectl get secret lab-pg-superuser -n dp-*` (absent) ; `auth can-i get secrets -n lab-pg --as=<SA de cellule>` | `NotFound` ; `no` |
| 12 | GitOps (CI) | PR avec `autoDeploy: true`, double binding, kind cluster-scoped hors `platform-shared/`, `backup.class: irreplaceable` | CI rouge, code d'erreur `appgen` |
| 13 | Hors Git | Objet créé par MCP ou `kubectl` dans `default` | MCP : `denied` (authz en lecture seule) ; Argo : orphelin signalé |
| 14 | OIDC (ThunderID) | Utilisateur hors du groupe autorisé ; membre de `admin` | Refus à l'IdP ou dans Miniflux (`OAUTH2_USER_CREATION=1` crée tout porteur d'un token valide : le refus doit venir de l'IdP) ; admin dans Miniflux |
| 15 | IMDS (OKE seulement) | Pod de cellule et pod hors cellule vers `169.254.169.254` | timeout (CCNP de la baseline #1620) |

## 9. Contraintes et décisions respectées

- **Budget CPU de 70 % des requests (D-2026-11-15-05).** La table `small` fait 50m par app. Les 3 apps demandent 150m (plus CNPG `lab-pg` ≈ 100m [S]).
- **Exposition.** Pas de LoadBalancer OCI : quota `services.loadbalancers: "0"` et postRender ClusterIP. L'accès public passe par Cloudflare Tunnel, jamais anonymement (`auth` différent de `none`).
- **Stockage.** Pas de Longhorn sur OKE : StorageClass `oci-bv` par overlay.
- **Secrets.** ESO et Doppler : `dataplane.secretStore` = `doppler-cluster` (même nom qu'OKE) ; un store `lab` dédié est recommandé.
- **Sauvegarde.** R2 pour toute donnée `irreplaceable`, refusée tant qu'aucune restauration n'est prouvée.
- **Argo CD par cluster** (D-2026-11-15-01). Aucune donnée persistante activée sur OKE sans restauration prouvée hors Oracle (D-2026-11-14-03). D'où le CNPG éphémère et `backup.class` ≤ `regenerable`.

## 10. Points à valider sur cluster (ordre d'impact)

1. **Empreinte.** OpenChoreo par défaut pèse +650m de requests, contre un reliquat OKE d'environ 375m au seuil de 70 % (DECISION §3 : 1025m déjà réservés). Mesurer sur k3d, baisser les requests, viser ≤ 250m. Sinon, pas d'OKE.
2. **Gate OKE.** Cilium remplace flannel. Baseline #1620 active, refus IMDS (test 15), accès opérateur ouvert (nécessaire à `appgen pin-resource`).
3. **PSA de bout en bout.** whoami en uid 65532 sur le port 8080, Miniflux et AIOStreams avec `readOnlyRootFilesystem` et `/tmp` en emptyDir, Job `psql` en uid 26 [S].
4. **Boucle GitOps.** Prouvée sur k3d (docs/GITOPS-PROOF.md) : ServerSideApply sans `ignoreDifferences`. Deux PR par base (pin RRB) et par changement des paramètres du Project (pin PRB, `pin-project`). Corrections G1, A1-A7 à re-prouver sur k3d puis OKE (GITOPS-PROOF §4).
5. **Job immuable** du CRT après une modification du CRT (§7.3).
6. **ThunderID.** Issuer joignable par le navigateur **et** par le pod ; déclaration du client Miniflux dans Git (sinon geste manuel à documenter) ; namespace réel pour `idpNamespace`.
7. **Routage** `/{composant}-{endpoint}` avec `ReplacePrefixMatch` (E-revue T3). Miniflux et AIOStreams sur un hôte dédié peuvent exiger un HTTPRoute par hôte dans le CCT (décision D4).
8. **Images arm64** de Miniflux et d'AIOStreams. Dépôt, port, chemin de santé et chemin de données d'AIOStreams [S].
9. **VAP-1** compatible avec le fonctionnement normal du cluster-agent (ServiceAccounts, namespaces `dp-*`).
