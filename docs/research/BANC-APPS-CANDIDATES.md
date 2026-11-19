# Apps candidates pour M1 et M2 du banc A/B

Date : 2026-11-18 · Ticket : T-485 · Statut : `STATIC` (dépôt, registres et code amont lus ; aucun cluster touché,
aucun déploiement). Suite de [OPENCHOREO-CHEMIN-NATIF.md](OPENCHOREO-CHEMIN-NATIF.md) (branche
`claude/t-chemin-natif`) : ce rapport concluait que `it-tools` et `vikunja` ne se déploient dans aucun des deux
chemins. Cette étude cherche, parmi les apps déjà présentes, des remplaçants pour M1 et M2
([POC-OPENCHOREO-STRATEGY.md](POC-OPENCHOREO-STRATEGY.md) §2.3).

## Conclusion d'abord

1. **M1 : `traefik/whoami`, sous un nouveau nom** (le même `app.yaml` que `whoami`, `echo-demo`, `idp-e2e`). Zéro
   changement de contrat ; image de 2 Mo, multi-arch, statique, port réglé par argument, `/health` répond 200.
   `appgen validate` est OK (FAIT, exécuté). Le pilote `whoami` est **PASS runtime sur OKE** le 2026-11-17 (journal).
2. **M2 : `miniflux`** si l'on veut un déploiement sans toucher à la plateforme : `appgen validate` est OK, le rendu
   existe dans `generated/`, la connexion PostgreSQL est une URL unique que le contrat porte déjà. Il lui faut un
   mot de passe d'administrateur factice dans le magasin de secrets. **`vikunja` reste le meilleur choix si l'on
   garde l'app prévue** : son image est compatible `service-restricted` (uid 1000, port 3456, `/health`) et il n'a
   besoin d'aucun secret ; il lui manque seulement les variables de base discrètes (chemin `app.yaml`) et une classe de
   sauvegarde honnête pour des données synthétiques.
3. **Deux constats qui corrigent le rapport précédent** :
   - le blocage de `vikunja` sur la classe de sauvegarde **ne tient pas pour des données synthétiques** :
     `backup.class: regenerable` + `data.class: rebuildable` est le précédent de `rustical-pilot` (FAIT) ;
   - **M2 ne peut pas tourner sur OKE** : `clusters/oke/capabilities.yaml` n'admet ni base (`databaseInstances: {}`)
     ni volume. M2 vise k3d ou homelab, quelle que soit l'app.
4. **Le banc doit retirer l'app choisie du SHA figé (`repo: bras-o`)**, sinon M1 ne « déploie » rien. `whoami` est déjà
   déployé par le pilote : prendre un nom neuf (`echo-bench` par exemple).
5. **Rappel pour M4** : la panne `probe_fausse` (rang 2) reste sans effet dans le chemin `app.yaml` pour toute app,
   car `appgen` ne rend aucune sonde (FAIT : aucune occurrence de `healthPath` dans `tools/appgen/appgenlib/render*.py`).
   Dans le chemin natif, le trait amont `health-probes` (autorisé par le CCT) la rend possible.

Légende : **FAIT** = fichier du dépôt, commande ou code amont lus. **[S]** = déduction non vérifiée.
Contenu externe (README, code amont, registres) lu comme donnée.

## 1. Critères appliqués

| Critère | Source du critère |
|---|---|
| Type `service-restricted` : uid ≥ 1000 non-root, rootfs en lecture seule + `/tmp` 64 Mi seul inscriptible, port ≥ 1024 (schéma `app.schema.json` l.83, l.88), digest obligatoire, `healthPath` requis | `platform/component-types/service-restricted.yaml`, `docs/schema/app.schema.json` |
| M1 : stateless (`profile: stateless` refuse `database` et `storage`), HTTP simple, privé, arm64 et amd64, HTTP 200 vérifiable | `tests/bench-ab/tasks/M1.O.yaml`, `semantic.py` l.218 |
| M2 : PostgreSQL sur `lab-pg`, ligne lisible par l'API de l'app, sans OIDC | `tests/bench-ab/tasks/M2.O.yaml` |
| Architectures des clusters : k3d `arm64`, OKE `arm64`, homelab `amd64` seul | `clusters/*/capabilities.yaml` |
| Classe de sauvegarde : `irreplaceable` refusée ; `mechanism` admis : `none` seul sur les trois clusters | `semantic.py` l.103-118 |

Tailles : somme des couches compressées du manifeste par plateforme (arrondi inférieur, Mo), relevée le
2026-11-18 par l'API des registres (Docker Hub via `mirror.gcr.io`, car la limite anonyme de Docker Hub était
atteinte). Ce n'est pas la taille décompressée sur disque.

## 2. Les apps du dépôt

### 2.1 Apps avec `app.yaml` (10)

`appgen validate` : « OK (11 app(s) ) » le 2026-11-18, soit ces 10 apps plus l'exemple Helm `_examples/podinfo-helm`.

| App | Cluster | Profil | Image, taille (arm64 / amd64) | Non-root | Port | RootFS RO | `healthPath` | Sauvegarde | M1 | M2 |
|---|---|---|---|---|---|---|---|---|---|---|
| `whoami` | oke | stateless | `traefik/whoami:v1.10.3`, 2 / 2 Mo | oui (uid 65532 forcé ; pas de `USER` dans l'image, binaire statique) | 80 → **8080** par `--port` | oui, aucune écriture | `/health` | `none` | **oui** | non |
| `echo-demo` | oke | stateless | idem | idem | idem | idem | `/health` | `none` | oui (même image) | non |
| `idp-e2e` | k3d | stateless | idem | idem | idem | idem | `/health` | `none` | oui (même image, 2 replicas) | non |
| `ntfy` | oke | stateless | `binwiederhier/ntfy:v2.28.0`, 33 / 34 Mo | oui (uid 65532 forcé) | 80 → **8080** par `NTFY_LISTEN_HTTP` | oui [S] : cache et auth en mémoire | `/v1/health` | `none` | oui, **mais c'est l'app de M3** | non |
| `searxng` | oke | stateless | `searxng/searxng:2026.9.30`, 91 / 93 Mo | [S] entrypoint sans `USER`, démarrage non prouvé | 8080 | [S] écriture de config possible | `/healthz` [S] | `none` | possible, risqué | non |
| `miniflux` | k3d | stateful | `miniflux:2.3.3`, 12 / 12 Mo | oui (image uid 65534) | 8080 | oui (rien à écrire) [S] | `/healthcheck` (FAIT, `routes.go` 2.3.3 l.24) | `regenerable` | non (base) | **oui** |
| `mealie` | k3d | stateful | `mealie:v3.28.0`, 396 / 407 Mo | uid 1000 forcé, [S] à prouver | 9000 | PVC SQLite | `/api/app/about` [S] | `none` | non | non (SQLite ; PostgreSQL par variables discrètes et OIDC) |
| `aiostreams` | k3d | stateful | `viren070/aiostreams:v2.38.1`, 92 / 92 Mo | **image en uid 0** ; uid 65532 forcé, à prouver sur PVC | 3000 | PVC SQLite | `/api/v1/status` | `regenerable` | non (PVC, 2 secrets, public) | possible (voir §3.3) |
| `rustical-pilot` | k3d | stateful | `lennart-k/rustical:0.18.0`, 11 / 12 Mo | uid 1000 | 4000 | PVC SQLite | `/` [S] | `regenerable` | non (PVC, OIDC) | non (SQLite) |
| `open-connector` | k3d | stateful | `oomol-lab/open-connector:v1.8.0`, 105 / 105 Mo | uid 10001 | 3000 | PVC 2 Gi | `/health` | `regenerable` | non (PVC, 2 secrets) | non (pas de PostgreSQL lu) |

Fait pour toutes les lignes : le digest est un index multi-arch contenant arm64 et amd64 (relevé du 2026-11-18),
sauf mention contraire. Le tableau ne dit « oui » à M1 qu'aux apps stateless sans secret ni exposition.

### 2.2 Apps sans `app.yaml` (6) et exemples (2)

| App | Raison de non-portage (FAIT, `NOTES.md`) | Image (taille arm64 / amd64) | Candidat |
|---|---|---|---|
| `it-tools` | port 80 et 3 répertoires nginx inscriptibles (`/var/log/nginx`, `/var/cache/nginx`, `/run`) ; le CCT ne monte que `/tmp` | `corentinth/it-tools:2024.10.22-7ca5933`, 22 / 21 Mo, `nginx -g "daemon off;"`, port 80 | non |
| `vikunja` | variables de base discrètes ; classe de sauvegarde (§3.2) | `vikunja/vikunja:2.7.0`, 48 / 52 Mo, **User 1000, port 3456** | M2 (après extension) |
| `romm` | OIDC Authentik, 4 PVC (100 Gi), CHOWN/SETUID, PostgreSQL | `rommapp/romm:5.2.0`, 443 / 446 Mo | non |
| `bookorbit` | volume RWX, extensions PostgreSQL (`vector`), IP privée | non mesurée | non |
| `polyfin` | pas de cluster `homelab` à l'époque, egress FQDN, base avec WAL | non mesurée | non |
| `agentgateway` | config par fichier, ingress inter-apps | non mesurée | non |
| `_examples/podinfo-helm` | parcours Helm, non actif | chart OCI | hors périmètre (chemin Helm) |
| `_kube-ops-helm/hindsight` | cluster oke refusé, base et secret hors contrat | non mesurée | non |

## 3. Fiches des candidats retenus

### 3.1 M1 — `whoami` sous un nom neuf

- **Pourquoi il convient (FAIT)** : stateless strict ; image `docker.io/traefik/whoami:v1.10.3@sha256:43a68d10…`,
  2 Mo, index amd64 + arm64 ; aucun volume ni secret ni egress ; port déplacé à 8080 par `args: ["--port", "8080"]`
  (rendu dans `generated/…/whoami/components/whoami/workload.yaml`) ; `exposure: {mode: private, auth: none}` donne
  `visibility: [internal]` ; `/health` renvoie 200.
- **Preuve runtime** : pilote `whoami` sur OKE, baseline HTTP 200 le 2026-11-17 22:27Z, modification par PR #23,
  rollback par PR #24 (`docs/state/journal/2026-11-18.md` l.13). `echo-demo` et `idp-e2e` : NOT_TESTED au runtime.
  k3d : boucle `whoami` prouvée (18 PASS / 6 FAIL, défauts corrigés statiquement depuis).
- **Ce qui l'empêche dans `service-restricted`** : rien. Nom d'image qualifié `docker.io/…` obligatoire sur OKE
  (CRI-O refuse les noms courts, même journal).
- **Sauvegarde** : `none`, sans donnée.
- **Pannes de M4** : `digest_faux` et `port_faux` (rangs 0 et 1) ont un effet réel ; `probe_fausse` (rang 2) n'en
  a pas dans le chemin `app.yaml` (voir conclusion 5).
- **Chemin `app.yaml` + appgen** : copier `apps/whoami/app.yaml` vers `apps/<nouveau>/app.yaml`, changer
  `metadata.name`, la description et, si besoin, `cluster` (`k3d` arm64 ou `homelab` amd64 : l'image est multi-arch).
  Aucun changement de schéma ni de plateforme. 1 fichier, environ 25 lignes.
- **Chemin natif** : Project (`cell-restricted`, `egress: none`, `database: false`, `allowIdp: false`),
  ProjectReleaseBinding, Component (`deployment/service-restricted`, `runAsUser`, `strategy`), Workload (image par
  digest, `args`, endpoint HTTP 8080 `internal`), puis `occ componentrelease generate` et
  `occ releasebinding generate`. Aucune extension plateforme. Optionnel : trait `health-probes` sur `/health`
  pour que `probe_fausse` ait un effet.

### 3.2 M2 — `vikunja` (l'app prévue)

- **Image (FAIT, config OCI lue)** : `User: 1000`, port 3456, entrypoint `/app/vikunja/vikunja`. Compatible avec
  `runAsUser: 1000` (minimum du schéma) et avec un port ≥ 1024. 48 Mo arm64, 52 Mo amd64.
- **Sonde (FAIT, code amont `v2.7.0`)** : `GET /health` (`pkg/routes/routes.go` l.265), sans authentification.
- **API pour la ligne lue (FAIT, même fichier l.532 et l.539)** : `POST /api/v1/register`, `POST /api/v1/login`, puis
  création et lecture d'un projet. L'inscription est ouverte par défaut [S] (clé `service.enableregistration`
  présente dans `config-raw.json`, défaut non relu). Aucun OIDC, aucun secret applicatif.
- **Écriture disque** : le répertoire de fichiers par défaut est relatif au répertoire de travail [S]. Poser
  `VIKUNJA_FILES_BASEPATH=/tmp/files` (clé `files.basepath` présente dans `config-raw.json`) le place sur
  l'`emptyDir` `/tmp` de 64 Mi : suffisant pour le banc, pas pour des pièces jointes réelles.
- **Base** : variables discrètes `VIKUNJA_DATABASE_TYPE`, `_HOST`, `_USER`, `_PASSWORD`, `_DATABASE`, `_SSLMODE`
  (clés `host` et `sslmode` présentes dans `config-raw.json`). Le CRT `cnpg-lab-db` expose `host`, `port`,
  `database`, `username`, `password` (`platform/resource-types/cnpg-lab-db.yaml` l.43-59) ; `lab-pg` refuse le
  non-TLS (`pg_hba` `hostnossl … reject`), d'où `sslmode=require`.
- **Cluster** : k3d ou homelab (`lab-pg` admis). **Pas OKE.**
- **Ce qui l'empêche dans `service-restricted`** : rien dans l'image. Seuls blocages :
  1. **Variables de base discrètes.** Chemin `app.yaml` : `spec.database` n'a que `instance` et `envVar`
     (`app.schema.json` l.233-240) ; il faut une extension du schéma et du rendu (par exemple `database.vars`)
     et des tests. Chemin natif : aucune extension, `Workload.spec.dependencies.resources[].envBindings` est un
     `map[string]string` (FAIT, dans le rapport précédent §1.1).
  2. **Classe de sauvegarde.** Pour de **vraies** tâches, `regenerable` serait faux et `irreplaceable` est refusé
     (`NOTES.md` de `vikunja`). Pour les **données synthétiques** du banc, `data.class: rebuildable` et
     `backup.class: regenerable` sont honnêtes, comme dans `rustical-pilot` (FAIT). Cela reste une décision de
     Paul : le descripteur doit porter la mention « données synthétiques uniquement ».
- **Sauvegarde requise pour un usage réel** : `cnpg` (Barman vers R2), non admis (`backupMechanisms: [none]`).
  Hors banc.
- **Effort** : chemin `app.yaml` : 1 PR plateforme (schéma + `render_native.py` + tests, estimation M) avant le gel,
  puis 1 fichier de 35 à 40 lignes. Chemin natif : 6 à 7 fichiers, 130 lignes (estimation du rapport précédent),
  plus l'épinglage de la `ResourceRelease` (PR 2, comme pour toute app avec base).

### 3.3 M2 — `miniflux`

- **Image (FAIT)** : `ghcr.io/miniflux/miniflux:2.3.3@sha256:49d7b609…`, 12 Mo, `User: 65534`, port 8080,
  commande `/usr/bin/miniflux`. Aucune écriture disque nécessaire [S] : tout est en base.
- **Sonde (FAIT)** : `GET /healthcheck` (`internal/http/server/routes.go`, tag 2.3.3, l.24).
- **Base** : une seule variable `DATABASE_URL`. Le contrat la porte déjà (`database: {engine: postgres, instance:
  lab-pg, envVar: DATABASE_URL}`) ; le rendu existe (`generated/…/miniflux/resources/miniflux-db.yaml`,
  `resource-bindings/`, `envBindings: {url: DATABASE_URL}`). L'URI du CRT contient `sslmode=require`.
- **État du dépôt** : `appgen validate` OK ; `generated/` à jour. NOT_TESTED au runtime.
- **Modifications pour M2** (« connexion locale, sans OIDC ») :
  1. retirer `identity`, `network.allowIdp`, les variables `OAUTH2_*` et le secret `MINIFLUX_OAUTH2_CLIENT_SECRET` ;
  2. `exposure: {mode: private, auth: none}` (aujourd'hui `public` + `app-oidc`), et retirer `BASE_URL` public ;
  3. ajouter `CREATE_ADMIN=1` et `ADMIN_USERNAME` (variables d'environnement, options présentes dans
     `internal/config/options.go` 2.3.3 : `CREATE_ADMIN`, `ADMIN_PASSWORD`) ;
  4. `ADMIN_PASSWORD` par `secrets: [{env: ADMIN_PASSWORD, key: MINIFLUX_ADMIN_PASSWORD}]`. `appgen` refuse un nom
     `PASSWORD` dans `runtime.env` (FAIT, `rustical-pilot/NOTES.md` §2), donc la valeur passe par le magasin de
     secrets.
- **Point à traiter avant le banc** : la clé `MINIFLUX_ADMIN_PASSWORD` doit exister dans le magasin du cluster,
  avec une valeur factice **posée par le harnais avant les runs comptés** (sinon geste humain, S7). Aucune valeur
  dans le dépôt.
- **API pour la ligne lue** : `POST /v1/categories` puis `GET /v1/categories` en authentification basique avec
  l'administrateur ; ou la catégorie « All » créée avec le compte [S].
- **Sauvegarde** : `data.class: rebuildable`, `backup.class: regenerable` (déjà dans le fichier ; flux RSS
  reconstructibles, données de test).
- **Cluster** : k3d ou homelab.
- **Effort** : chemin `app.yaml` : 1 fichier modifié, environ −12 lignes et +4, aucune extension. Chemin natif :
  M1 + Resource `cnpg-lab-db`, ResourceReleaseBinding, SecretReference, Workload avec `envBindings: {url:
  DATABASE_URL}`, soit environ 6 fichiers.
- **Parité avec le bras K [S]** : ce dépôt ne dit pas si kube-ops a un `miniflux` comparable à
  `k8s/applications/catalog/vikunja/` (11 fichiers, 333 lignes). À vérifier côté kube-ops avant de remplacer
  `vikunja` par `miniflux` dans la consigne de M2.

### 3.4 M2 — `aiostreams` (3e choix)

- PostgreSQL pris en charge par l'image : `packages/core/src/db/connect.ts` (tag v2.38.1) accepte `postgresql:` et
  `postgres:` dans `DATABASE_URI` (FAIT). Une URL unique : compatible avec `database.envVar: DATABASE_URI`.
- Obstacles : image en **uid 0** (FAIT, config OCI) ; uid 65532 imposé, à prouver ; deux secrets (`SECRET_KEY`,
  `CONFIG_ACCESS_KEY`) ; `egress: public-internet` et `exposure: public` aujourd'hui ; l'API pour « une ligne lue »
  est un modèle de configuration utilisateur, plus lourd à scripter que Vikunja ou Miniflux.
- Pour M2 : passer en `profile: stateful` avec `database` au lieu de `storage`, `exposure: private`, `egress: none`.
  Statut : non prouvé, 92 Mo.

## 4. Classements

### M1 (stateless privé, HTTP simple, 200 vérifiable)

| Rang | Candidat | Raison | Réserve |
|---|---|---|---|
| 1 | `traefik/whoami` (sous un nom neuf) | Zéro changement ; 2 Mo ; PASS runtime sur OKE (2026-11-17) ; `validate` OK | `probe_fausse` sans effet dans le chemin `app.yaml` ; retirer l'app du SHA figé |
| 2 | `ntfy` | Stateless, `/v1/health`, 33 Mo, pas de secret | **C'est l'app de M3** : prendre `ntfy` pour M1 oblige à changer M3. Runtime NOT_TESTED (`NOTES.md`) |
| 3 | `searxng` | Stateless, sans volume | Un secret à provisionner ; `egress: public-internet` ; entrypoint sans `USER`, écriture de config à prouver ; 93 Mo ; NOT_TESTED |

`echo-demo` et `idp-e2e` ont la même image que `whoami` : ce ne sont pas des alternatives distinctes. Aucune app
du dépôt ne remplace `it-tools` mieux que `whoami`.

### M2 (PostgreSQL, ligne lisible par l'API, sans OIDC)

| Rang | Candidat | Raison | Réserve |
|---|---|---|---|
| 1 | `miniflux` | Déployable sans extension : `validate` OK, rendu présent, URL unique, uid 65534, 12 Mo, `/healthcheck` prouvé dans le code | Mot de passe administrateur factice à pré-provisionner ; parité du bras K non vérifiée |
| 2 | `vikunja` (app d'origine) | Image compatible (uid 1000, `/health`) ; aucun secret ; garde la consigne de M2 | Extension `database.vars` (chemin `app.yaml`) ; décision de Paul sur `regenerable` pour des données synthétiques |
| 3 | `aiostreams` (PostgreSQL par `DATABASE_URI`) | Une URL unique, base prise en charge | uid 0, 2 secrets, API lourde ; non prouvé |

Choix entre rang 1 et 2 : prendre `vikunja` si la comparaison avec `k8s/applications/catalog/vikunja/` côté K
compte plus que la charge de préparation ; prendre `miniflux` si le banc doit démarrer sans développement.

## 5. Changements à prévoir pour le banc

| Fichier | Changement |
|---|---|
| `tests/bench-ab/tasks/M1.K.yaml`, `M1.O.yaml` | `app: it-tools` → nom neuf (`echo-bench`) ; adapter le prompt (« écho HTTP » au lieu de « it-tools ») |
| `tests/bench-ab/tasks/M2.K.yaml`, `M2.O.yaml` | seulement si `miniflux` : `app`, prompt (« compte local, sans OIDC ») et grader `m2` (lecture par l'API de catégories) |
| M4 (`it-tools`) | même app que M1, donc `whoami` : `probe_fausse` exige le trait `health-probes` (natif) ou le rendu de sonde par `appgen` |
| SHA figé du bras O (`bras-o`) | ne contient ni `apps/<M1>` ni `apps/<M2>` ; le magasin de secrets contient la clé factice de `miniflux` |
| `tests/bench-ab/arm64-images.md` | remplacer les lignes `it-tools` et `vikunja` selon le choix ; le relevé de ce rapport donne les plateformes (amd64 + arm64 pour toutes les images candidates) |
| `docs/research/POC-OPENCHOREO-STRATEGY.md` §2.3 | tableau des tâches |

## 6. Limites

- Tailles : couches compressées, relevé du 2026-11-18, `STATIC`. Non mesurées : `bookorbit`, `polyfin`,
  `agentgateway`, `hindsight`.
- Aucun runtime n'a été exécuté dans cette étude : « fonctionne » reste `NOT_TESTED` pour tout sauf le pilote
  `whoami` sur OKE (preuve du journal 2026-11-18).
- Les points marqués [S] (inscription ouverte de Vikunja, répertoire de fichiers par défaut, écritures de Miniflux,
  catégorie par défaut) se prouvent par le premier démarrage en passe 0 (T-486).
