# Authentik : étude de migration vers une identité cloud (homelab → OKE `oracle-a1`)

**Statut : ÉTUDE, rien n'est déployé ni migré.** Date : 2026-11-17. Aucun accès cluster utilisé ; sources lues sur `origin/main` de kube-ops (KO) et homelab-infra (HI), et dans ce dépôt (OCL). Compléments : [RUNBOOK-CUTOVER.md](RUNBOOK-CUTOVER.md), [DEPENDENCIES.md](DEPENDENCIES.md).

Notation des sources : `[KO:chemin:ligne]`, `[HI:chemin:ligne]`, `[OCL:chemin:ligne]`, `[DOC:url]`. `[E]` = estimation de cette étude, non mesurée.

## 0. Conclusion

| Question | Réponse |
|---|---|
| Faisable sans changer les applications ? | **Oui.** Une restauration physique de la base (réplica CNPG depuis R2, puis promotion) conserve l'issuer `https://auth.smadja.dev`, les endpoints, la clé de signature et son `kid` (en base), les utilisateurs, la MFA et les sessions (même `AUTHENTIK_SECRET_KEY`). La bascule est un changement de cible du CNAME `auth`, qui est proxifié : l'IP publique reste celle de Cloudflare. |
| Chemin recommandé | Le chemin déjà acté (D-2026-11-15-11) : **CNPG dédié sur OKE, réplica depuis `authentik-r2-store`, promotion au LSN final, CNAME `auth` vers le tunnel `oracle-a1`**. Clé de signature **préservée**, sans rotation pendant la bascule. Bootstrap manuel sans Argo ni OpenChoreo. |
| Blocage n°1 : stockage | Il reste **un seul emplacement de 50 Go** (150/200 Go occupés : boot + 2 volumes `csi-…` non attachés) [OCL:docs/storage/OKE-AUDIT-2026-11-17.md:48]. `lab-pg` (étape 10 du pilote) le réclame aussi [OCL:docs/PHASE-B.md:21]. Proposition : **Authentik prend cet emplacement**, `lab-pg` va sur le Data Plane Talos ou attend que Paul ait identifié et libéré les volumes `csi-…`. |
| Blocage n°2 : capacité | Elle tient au repos (≈ 62 % CPU en requests [E], sous le seuil de 70 %). La marge disparaît pendant un rollout (≈ 67 %) et pendant une répétition sur OKE (≈ 78 %, au-dessus du seuil). Les IP de pods (~31 au plus) sont aussi tendues. |
| Blocage n°3 : preuve | Aucune restauration hors Oracle n'est prouvée (`NOT_TESTED`) [HI:docs/architecture/oke-target-architecture.md:228]. Elle est **obligatoire avant la bascule** (D-2026-11-11-17, D-2026-11-15-11). |
| Risques principaux de la bascule | (1) Un Authentik homelab relancé par Argo, ou des pods homelab qui gardent des `hostAliases` vers `192.0.2.192` : **split-brain**. (2) L'outpost proxy géré redéployé sur OKE, sans route vers le LAN. (3) Des écritures perdues au retour arrière. (4) La désinstallation de la pile du labo qui supprimerait les CRD d'ESO, donc les Secrets d'Authentik. |
| Fenêtre estimée | **20 à 40 min** de coupure du login [E] ; le plan l'estimait à 15-30 min, sans mesure [HI:docs/architecture/oke-migration-plan.md:9]. Retour arrière : environ 10 min [E]. |

## 1. Conserver le domaine et l'issuer

| Élément | Où il est défini | Conservé si… |
|---|---|---|
| Domaine `auth.smadja.dev` | `base_url` [KO:k8s/infrastructure/auth/authentik/values.yaml:136] ; CNAME explicite proxifié vers le tunnel homelab [HI:terraform/cloudflare/modules/tunnel/main.tf:119-127] | même `base_url` sur OKE ; le CNAME change seulement de tunnel |
| `iss` | par provider (`per_provider`, ex. `…/application/o/argocd/`) [KO:k8s/infrastructure/controllers/argocd/values.yaml:85] ; global prévu pour OpenChoreo [OCL:platform/identity/openchoreo-oidc-values.yaml:16] | calculé depuis le host de la requête et le slug, et les slugs sont en base : **identique** si le `Host` vu par Authentik reste `auth.smadja.dev` et le schéma `https` (à prouver, T-P4) |
| Endpoints authorize/token/userinfo/JWKS | globaux, sous `/application/o/` [OCL:docs/IDENTITY.md:144] | identiques (mêmes slugs) |
| `kid` | colonne `kid` du modèle `CertificateKeyPair`, « générée depuis la clé privée », clé PEM stockée **en clair en base** [DOC:https://github.com/goauthentik/authentik/blob/main/authentik/crypto/models.py] | identique via une restauration physique ; **changé** par une réinstallation neuve |
| Clé utilisée | « authentik Self-signed Certificate » pour 22 `signing_key` sur 29 entrées [KO:k8s/infrastructure/auth/authentik/extra/blueprints/*] | créée par Authentik à sa première installation, absente de Git : elle n'existe que dans la base |

Conséquence : **une réinstallation neuve suivie d'une application des blueprints n'est PAS une migration.** Elle changerait le `kid`, les secrets générés par Authentik (clients OpenChoreo [OCL:docs/IDENTITY.md:91]), la MFA et les mots de passe.

## 2. Ce qui est transféré, et par quel canal

| Donnée | Canal | Remarque |
|---|---|---|
| 43 blueprints (flows, groupes, providers, applications) | Git, ConfigMap `authentik-blueprints` [KO:k8s/infrastructure/auth/authentik/extra/kustomization.yml:23-68] | rejoués au démarrage ; ils retrouvent l'état restauré (mises à jour partielles) |
| Utilisateurs, groupes réels, MFA (TOTP/WebAuthn), mots de passe, consentements, jetons, refresh tokens, sessions, clés et certificats, secrets générés, outposts | **base PostgreSQL** (`authentik-postgresql-restored`, 1,2 Go de données + 4,5 Go de WAL) [HI:docs/architecture/oke-migration-plan.md:9] | réplica physique, donc copie exacte |
| Médias (icônes, fonds) | `emptyDir` 2 Gi [KO:…/values.yaml:214-221] | déjà perdus à chaque redémarrage : rien à copier, à vérifier (T-P7) |
| Secrets d'environnement (`APP_AUTHENTIK_*`, clients `APP_*_OAUTH_*`) | Doppler `cluster/prd`, via ESO [KO:…/extra/secrets.yml:16-40] | déjà lisibles par l'ESO d'OKE [HI:docs/architecture/oke-migration-plan.md:39] |
| Redis | `redis.enabled: true` avec persistance 1 Gi [KO:…/values.yaml:363-374] | aucune donnée à migrer. À vérifier : la version 2026.8 a-t-elle encore besoin de Redis ? La doc de configuration ne cite que PostgreSQL [DOC:https://docs.goauthentik.io/install-config/configuration/]. Si non, retirer le pod (1 IP de moins). |

## 3. Clés de signature : préserver ou faire tourner

| Option | Effet sur les jetons existants | Effet sur les applications | Verdict |
|---|---|---|---|
| **A. Préserver** (même clé, restaurée avec la base) | jetons d'accès, ID tokens et refresh tokens restent valides de part et d'autre de la bascule | aucun : JWKS et `kid` inchangés | **Recommandé** |
| B. Rotation pendant la bascule | Le JWKS d'un provider publie **une seule** clé de signature (plus une clé de chiffrement éventuelle) [DOC:https://github.com/goauthentik/authentik/blob/main/authentik/providers/oauth2/views/jwks.py]. Il n'existe donc **pas de JWKS natif à deux clés** : tout jeton signé avec l'ancienne clé est rejeté dès que le RP rafraîchit son JWKS. | reconnexion forcée ; OpenChoreo relit le JWKS sur un `kid` inconnu [OCL:docs/IDENTITY.md:100] ; les caches des autres RP (Argo, Grafana, apiserver Talos, Cloudflare Access) ne sont pas maîtrisés | **Rejeté** : deux changements à risque dans la même fenêtre |
| C. Rotation plus tard, hors bascule | idem B, provider par provider (`signing_key` par PR), avec une fenêtre courte (jetons d'accès de 15 min) | une PR kube-ops par lot de providers | possible plus tard, sujet séparé |

Point de sécurité : **la sauvegarde R2 contient la clé privée de signature en clair.** Le jeton écrivain R2 couvre tout le bucket `homelab-backup-cnpg` [HI:docs/decisions.md:1019]. Quiconque lit l'archive peut forger des jetons pour toutes les applications. C'est un risque déjà présent aujourd'hui, à rappeler à Paul.

## 4. PostgreSQL, stockage et `SECRET_KEY`

| Sujet | Aujourd'hui (homelab) | Cible OKE | Écart ou action |
|---|---|---|---|
| Cluster | CNPG `authentik-postgresql-restored`, 1 instance, PG 17.7 [KO:…/database.yaml:1-8] | CNPG dédié dans `auth`, même image (multi-arch épinglée par digest [KO:docs/operations/pg-shared-oke-backup-drill.md:13]) | dédié imposé (D-2026-11-15-11 [HI:docs/decisions.md:587] ; classe identité, D-2026-11-16-09 [HI:docs/decisions.md:1006]) |
| Volumes | `storage` 40 Gi + `walStorage` 30 Gi sur Longhorn [KO:…/database.yaml:21-26] | **un seul** volume `oci-bv` de 50 Go, sans `walStorage` (2 volumes coûteraient 100 Go) | données + WAL ≈ 6 Go : il y a de la place |
| Classe de stockage | — | `oci-bv` est en `Delete` [OCL:docs/storage/OKE-AUDIT-2026-11-17.md:7] | prévoir une classe `Retain` pour la base d'identité (changement cluster-wide : accord de Paul) |
| Archive | `authentik-r2-store` → `s3://homelab-backup-cnpg/authentik`, rétention 14 j [KO:…/database-r2.yaml:38-76] | **nouveau préfixe** (ex. `oracle-a1/authentik/`) après la promotion : barman refuse une archive non vide [KO:docs/operations/pg-shared-oke-backup-drill.md:17] | le réplica **lit** l'ancien préfixe et le promu **écrit** dans le nouveau |
| Base backup | **hebdomadaire**, dimanche 02:00 [KO:…/database-scheduled-backup.yaml:7] | quotidien | Si le homelab est éteint à 02:00, la sauvegarde a lieu au mieux en retard (comportement non vérifié). Une restauration rejoue jusqu'à 7 jours de WAL, donc le RTO augmente. Lancer un `Backup` à la demande avant la répétition et avant la bascule. |
| RPO | `archive_timeout` 15 min [KO:…/database.yaml:48-55] | idem | L'objectif de D-2026-11-16-07 (RPO ≤ 5 min [HI:docs/decisions.md:930]) n'est **pas tenu**, écart déjà connu [HI:docs/decisions.md:1016-1018]. À la bascule elle-même, RPO = 0 grâce au LSN final. |
| `AUTHENTIK_SECRET_KEY` | Doppler `APP_AUTHENTIK_SECRET_KEY` [KO:…/extra/secrets.yml:19-21] | **même valeur** | La doc dit : signature des cookies ; « Changing this will invalidate active sessions » [DOC:https://docs.goauthentik.io/install-config/configuration/]. La doc ne dit pas qu'elle chiffre des colonnes (les clés de signature sont en clair, §1). On garde quand même la même valeur, ce qui ne coûte rien. **Ne pas la régénérer.** |
| Restauration hors Oracle | — | homelab Talos, identité R2 en lecture seule `R2_CNPG_RESTORE_RO_*` [KO:docs/operations/pg-shared-oke-backup-drill.md:17] | procédure existante (étapes 1-8), à adapter à Authentik (RUNBOOK §P2) |

## 5. Identifiants de bootstrap

| Identifiant | Où il vit | Rôle après une restauration |
|---|---|---|
| `AUTHENTIK_BOOTSTRAP_PASSWORD` / `_TOKEN` | Doppler `APP_AUTHENTIK_BOOTSTRAP_*` [KO:…/extra/secrets.yml:32-37] | « Only read on the first startup » [DOC:https://docs.goauthentik.io/install-config/automated-install/] : **ignorés** sur une base restaurée. Ils ne servent qu'au chemin de reconstruction à vide (base perdue). |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | Doppler `APP_AUTHENTIK_ADMIN_EMAIL` | idem |
| Compte `akadmin` et son jeton API | **en base** | Si le mot de passe ou le jeton a changé depuis l'installation, la copie Doppler est périmée. À vérifier par nom, sans valeur (T-P8). |
| Jeton Doppler d'ESO (OKE) | Secret posé à la main au bootstrap (geste de Paul, comme le bootstrap Argo [HI:docs/architecture/oke-target-architecture.md:207]) | seul geste humain inévitable (un `kubectl apply` par Paul) ; jeton par domaine `auth` recommandé (PLT-258) |
| OpenBao | non installé, et son hébergement sain n'existe pas [OCL:docs/storage/OPENBAO-DOPPLER-ESO.md:1-30] | **exclu du chemin d'Authentik** : sinon dépendance circulaire (DEPENDENCIES §3) |

Sans geste humain là où c'est possible : les blueprints restent en Git, les secrets restent dans Doppler (lus par ESO), et aucun secret n'est saisi dans l'UI. Seuls restent humains : le jeton ESO initial, l'accord MANDAT (stockage, exposition) et la preuve USER (Maureen se connecte) [HI:docs/decisions.md:599].

## 6. DNS, TLS, exposition et connectivité

| Sujet | Cible |
|---|---|
| Exposition | tunnel Cloudflare `oracle-a1` (déjà modélisé, interrupteurs `enable_oracle_a1_*`) [HI:terraform/cloudflare/oracle-a1.tf:17-60] : ajouter une règle `auth.smadja.dev → http://authentik-server.auth.svc.cluster.local:80`. **Aucun LoadBalancer OCI** (VAP `deny-loadbalancer-service` [KO:k8s/clusters/oracle-a1/guardrails/deny-loadbalancer-service.yaml]). |
| DNS | Changer `content` de `cloudflare_dns_record.auth_smadja_dev` vers `<id oracle-a1>.cfargotunnel.com` [HI:terraform/cloudflare/modules/tunnel/main.tf:119-127]. Comme l'enregistrement est proxifié, les clients voient toujours des IP Cloudflare : pas d'attente de TTL. Retour arrière : remettre l'ancien contenu, ou supprimer l'enregistrement (le joker `*.smadja.dev` revient au homelab). |
| TLS | terminé à la bordure Cloudflare (certificat universel) ; tunnel chiffré ; HTTP en clair dans le cluster jusqu'au Service. Authentik doit voir `https` : en-têtes `X-Forwarded-*` de cloudflared et `trusted_proxy_cidrs` [KO:…/values.yaml:141] (le CIDR des pods VCN-native fait partie de `10.0.0.0/8`) : à prouver (T-P4). |
| Pas de Cloudflare Access devant `auth` | sinon dépendance circulaire [HI:docs/architecture/oke-target-architecture.md:119] |
| Depuis OKE (CP OpenChoreo, Backstage, apps du DP OKE) | URL publique `https://auth.smadja.dev` (épingle à cheveux OKE → Cloudflare → tunnel → OKE), egress par FQDN [OCL:platform/identity/network-policy-api-idp.yaml:26-29]. Ne pas court-circuiter par le Service interne : l'`iss` et le certificat doivent rester ceux du nom public. |
| Depuis le homelab (DP Talos, Argo, Grafana, apiserver) | URL publique. Retirer les `hostAliases` vers `192.0.2.192` et l'entrée DNS split LAN (ExternalDNS privé à partir de la route `internal` [KO:k8s/infrastructure/auth/authentik/httproute.yaml:7-13]), puis élargir l'egress des politiques qui ciblent `192.0.2.192/32` (inventaire : DEPENDENCIES §2). |
| Limite de débit | règle `auth.smadja.dev` à 60 req/60 s par IP [HI:terraform/cloudflare/README.md:176], derrière `enable_rate_limit` (état non vérifié). Tout OKE sort par une seule IP NAT : agents, API et Backstage partageraient ce quota. À vérifier avant la bascule (T-P10). |

## 7. Restauration hors Oracle (exigée avant la bascule)

| Mesure | Définition | Cible |
|---|---|---|
| RTO de restauration | création du `Cluster` de restauration jusqu'à `Ready`, puis jusqu'au premier login réussi | ≤ 30 min [HI:docs/decisions.md:930] |
| RPO | dernier commit témoin, comparé au dernier WAL archivé qui le contient | ≤ 15 min (réglage actuel) ; 5 min = objectif non prouvé |
| Empreintes | nombre d'utilisateurs, de groupes, de providers et d'appareils MFA ; `kid` de chaque `CertificateKeyPair` ; md5 trié des `client_id` ; `server_version` | identiques entre la source et la restauration |

Le drill a deux sens, détaillés dans RUNBOOK §P2 : (a) archive du homelab → instance jetable (répétition M11) ; (b) **archive écrite par OKE → restauration sur le homelab**. Le sens (b) prouve le chemin de retour pour le jour où Oracle suspend le compte [HI:docs/architecture/oke-migration-plan.md:22]. On ne bascule pas sans le sens (b).

## 8. Bascule, vérification et retour arrière

Voir [RUNBOOK-CUTOVER.md](RUNBOOK-CUTOVER.md) : prérequis go/no-go, étapes chronométrées, vérifications (login réel, client_credentials, groupes, outposts, OIDC d'Argo, de Talos, de Grafana et de Cloudflare Access), retour arrière et liste des écritures perdues.

## 9. Dépendances circulaires

Voir [DEPENDENCIES.md](DEPENDENCIES.md) §3 et §4. Règle : **stockage → CNPG (opérateur et plugin barman) → ESO et jeton Doppler → Secrets → PostgreSQL → Authentik → tunnel et DNS → ensuite seulement Argo et OpenChoreo.** Authentik et ses prérequis ne doivent pas appartenir à la pile du labo (`lab-*`, `openchoreo-*`) : sa désinstallation supprime des CRD [OCL:STATE.md:48], et des ExternalSecrets en `creationPolicy: Owner` [KO:…/extra/secrets.yml:15] emporteraient les Secrets d'Authentik.

## 10. Capacité et stockage

### 10.1 Requests sur le nœud (allocatable 1830m / 8650 Mi [OCL:docs/PHASE-B.md:100])

| Poste | CPU | Mémoire | Source |
|---|---|---|---|
| Mesuré après les étapes 1-5 du labo | 385m | 1038 Mi | [OCL:docs/PHASE-B.md:100] |
| OpenChoreo avec portail + Argo CD | 135m | 1104 Mi | [OCL:docs/PHASE-B.md:92-95] |
| Authentik server (aucune request aujourd'hui ; usage 584 Mi) | 100m | 640 Mi | [KO:…/values.yaml:189-232] ; usage [HI:docs/architecture/oke-migration-plan.md:9] ; [E] |
| Authentik worker (request existante ; usage 280 Mi) | 100m | 512 Mi | [KO:…/values.yaml:268-271] |
| PostgreSQL (usage 215 Mi) + sidecar barman | 250m | 640 Mi | [KO:…/database.yaml:27-30], [KO:…/database-r2.yaml:60-62] |
| Opérateur CNPG + plugin barman + cloudflared | 60m | 192 Mi | [E] |
| **Total au repos** | **≈ 1030m (56 %)** à **1130m (62 %)** | **≈ 4,1 Gi (48 %)** | [E] |
| Rollout d'Authentik (un server de plus) | +100m → ≈ 67 % | +640 Mi | [E] ; le seuil est à 70 % (D-2026-11-15-05) |
| Répétition sur OKE (2e cluster PG + 2e Authentik) | ≈ 78 % | ≈ 63 % | **au-dessus du seuil** : arrêter le portail et les apps du DP pendant la répétition, ou la faire sur le homelab |
| IP de pods | 16 (labo) + 6 à 7 (Authentik, CNPG, cloudflared, Redis ?) ≈ 22-23 sur ~31 | | [OCL:docs/PHASE-B.md:104] ; [E], à mesurer |

Leviers : partager **un seul** cert-manager, ESO et opérateur CNPG entre kube-ops et le labo, au lieu de deux piles ; retirer Redis s'il est inutile ; Argo en mode core [OCL:docs/PHASE-B.md:103].

### 10.2 Stockage (quota 200 Go)

| Option | Effet | Verdict |
|---|---|---|
| S1. Authentik prend le dernier emplacement de 50 Go ; `lab-pg` (archétype B) va sur le DP Talos ou attend | aucune suppression ; le pilote garde son cycle stateless | **Recommandé** |
| S2. Libérer les 2 volumes `csi-…` (100 Go) | Authentik et `lab-pg` coexistent | seulement après une identification certaine (ci-dessous) **et** un MANDAT de Paul |
| S3. Authentik dans `lab-pg` ou `pg-shared` | — | **Refusé** : CNPG dédié acté (D-2026-11-15-11), classe identité (D-2026-11-16-09) |
| S4. `local-path` sur le disque de boot | perdu au remplacement du nœud, ≈ 28 Go partagés [OCL:docs/storage/OKE-AUDIT-2026-11-17.md:49] | **Refusé** |

**Les 2 volumes `csi-…` de 50 Go** (créés le 2026-11-15 à 21:27 et 21:45 UTC, `AVAILABLE`, non attachés) [OCL:docs/storage/OKE-AUDIT-2026-11-17.md:34-35] : **ne jamais les supposer libres, ne jamais les supprimer.** Les sources se contredisent déjà : l'ADR les classe parmi les « Ressources détruites » [HI:docs/architecture/oke-target-architecture.md:44], mais aussi parmi les volumes « conservés » [HI:…:18, 174]. Et `hindsight-db` a pu contenir de vraies données restaurées. Méthode d'identification, **en lecture seule, non exécutée** :

1. `oci bv volume get --volume-id <ocid>` : `display-name`, `time-created`, `freeform-tags` et `defined-tags` (dont `Oracle-Tags.CreatedBy` si la tenancy l'active).
2. `oci compute volume-attachment list --volume-id <ocid>` (avec le compartiment) : attachements `DETACHED` restants, instance d'origine (ancien nœud, boot `oke-chi4…` `TERMINATED`).
3. Audit OCI de 2026-11-15 21:20 à 21:50Z : événements `CreateVolume` et `AttachVolume`, avec principal et ressource.
4. Grafana Cloud (Alloy et kube-state-metrics avaient le label `cluster` [HI:docs/architecture/oke-target-architecture.md:196]) : `kube_persistentvolume_info` et `kube_persistentvolume_claim_ref` pour le PV `csi-…`. Ils donnent le namespace et le PVC. **La rétention des métriques est limitée : à faire vite.**
5. Historique Git (kube-ops, 15/11 vers 21:20Z) : activations de `pg-shared` et `hindsight-db` (PLT-303, PLT-190).

Critère de certitude : deux sources indépendantes donnent le même couple namespace/PVC, **et** une sauvegarde R2 vérifiée existe pour ce contenu. Ensuite seulement : MANDAT de Paul pour supprimer. Monter le volume pour en lire le contenu est une écriture, hors de cette étude.

### 10.3 Hébergements possibles

| Option | Coût | Disponible la nuit | Indépendance | Verdict |
|---|---|---|---|---|
| H1. OKE `oracle-a1`, nœud actuel | 0 € | oui | SLA nul, compte suspendable [HI:docs/architecture/oke-migration-plan.md:22] → repli homelab depuis R2 | **Recommandé** |
| H2. 2e nœud A1 ou passage à 4 OCPU / 24 Go | 0 € si la limite Always Free le permet, sinon PAYG (prix non revérifié) | oui | même compte Oracle | rejeté par l'ADR (« hors Free Tier » [HI:…/oke-target-architecture.md:236]) ; 4/24 clos par D-2026-11-15-13 : décision de Paul |
| H3. VM Always Free AMD (1 Go) | 0 € | oui | même compte | **Trop petite** : server, worker et PG font ≈ 1,1 Go d'usage sans l'OS |
| H4. Petit VPS hors Oracle (4 Go) | ≈ 4-8 €/mois (à chiffrer), dans le budget < 20 €/mois [HI:docs/decisions.md:923] | oui | indépendant d'Oracle | repli si la capacité OKE casse. Hetzner contredit la sortie Hetzner (D-2026-11-16-07). Coût d'exploitation : un 3e site à opérer. |
| H5. Garder le homelab (statu quo) | 0 € | **non** (éteint la nuit) | — | Contraire à l'objectif. Note : D-2026-11-16-07 considère le serveur « allumé 24 h/24 » [HI:docs/decisions.md:919]. **À réconcilier par Paul.** |

## 11. Ce qui reste à prouver : tests de préparation sans risque (listés, NON exécutés)

Tous en lecture seule, ou sur une ressource jetable, sans toucher la production. Chacun produit une preuve datée sans secret.

| # | Test | Attendu | Risque |
|---|---|---|---|
| T-P1 | `docker manifest inspect ghcr.io/goauthentik/server:2026.8.3` | `linux/arm64` présent | nul |
| T-P2 | Lecture des objets R2 sous `authentik/authentik-postgresql-restored/` (identité RO) : base backups, dernier WAL | base backup < 7 j ; WAL < 15 min | nul (RO) |
| T-P3 | `GET /application/o/<slug>/jwks/` pour chaque provider, `kid` archivé | inventaire des `kid` avant la bascule | nul (public) |
| T-P4 | Répétition : discovery servie via cloudflared → Service, puis comparer `issuer` et `*_endpoint` à T-P3 | égalité stricte (schéma `https`) | jetable |
| T-P5 | `kustomize build --enable-helm` de l'overlay OKE Authentik + kubeconform + VAP en `--dry-run=server` | rendu valide, aucun LoadBalancer, PSA restricted | nul |
| T-P6 | Inventaire (Git) des consommateurs : `hostAliases`, `192.0.2.192`, `auth.smadja.dev` | liste fermée, comparée à DEPENDENCIES §2 | nul |
| T-P7 | Requête SQL en lecture sur une **restauration jetable** : fichiers référencés dans `/media` | aucun, sinon plan de copie | jetable |
| T-P8 | Noms Doppler présents (`APP_AUTHENTIK_*`, R2 RO et RW), jamais les valeurs | tous présents | nul |
| T-P9 | Lecture OCI des 2 volumes `csi-…` (§10.2, étapes 1-4) | namespace/PVC identifiés | nul (RO) |
| T-P10 | `tofu state show` du ruleset de limite de débit (plan ARC) | état `enable_rate_limit` connu | nul |
| T-P11 | Drill hors Oracle sens (a), puis (b) (RUNBOOK §P2) | empreintes égales, RTO/RPO mesurés | jetable, accord de Paul (volume et capacité) |
| T-P12 | Calcul de capacité : `verify.sh` en simulant les requests Authentik (dry-run) | < 70 % au repos, sinon leviers §10.1 | nul |
| T-P13 | `ScheduledBackup` homelab : dates des derniers `Backup` Completed | une sauvegarde par semaine au moins | nul (RO) |
| T-P14 | NetBird : son IdP de login dépend-il d'Authentik ? | non, sinon l'accès d'administration est circulaire | nul |
