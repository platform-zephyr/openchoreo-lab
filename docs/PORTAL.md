# Portail Backstage OpenChoreo (Phase B, étape 6b)

**Statut : NOT_TESTED sur OKE.** Values intégrées et réseau prêts ; rendu Helm 1.3.3 et PSA `restricted` vérifiés hors cluster (§5). Rien n'est déclaré fonctionnel tant que les critères du §6 n'ont pas de preuve runtime datée.

## 1. Décision

- On active le portail **intégré** au chart `openchoreo-control-plane` 1.3.3 (`backstage.enabled=true`, image `openchoreo-ui`). Pas de Backstage séparé.
- Login OIDC **Authentik** (`auth.smadja.dev`), **issuer global** `https://auth.smadja.dev/` partagé avec l'API (`docs/IDENTITY.md` §1). Deux clients distincts :
  - `openchoreo-backstage-client` : login utilisateur (`authorization_code` + refresh, confidentiel) ;
  - `openchoreo-backstage-service` : service backend du portail, synchro du catalogue (`client_credentials`), rôle `backstage-catalog-reader`.
- Base **SQLite sur emptyDir**, sans PVC.
- **Aucune exposition** : pas de HTTPRoute ni de Gateway CP. Accès par `kubectl port-forward`. Un Cloudflare Tunnel avec Access ne se fera qu'avec l'accord de Paul.
- Pas d'event-forwarder : la synchro du catalogue se fait par interrogation, toutes les 120 s.

Fichiers (source unique, passés tels quels à Helm et kubectl) :
- `platform/install/values/openchoreo-control-plane.yaml` : bloc `backstage`, `security.oidc`, sujets et liaisons de l'API ;
- `platform/install/manifests/03-idp-egress.yaml` : egress de `openchoreo-api` (JWKS) et de `backstage` (OIDC) vers `auth.smadja.dev:443`.

`platform/portal/values-backstage.yaml` n'est plus qu'un renvoi (fragment fusionné le 2026-11-17).

## 2. Coût mesuré (k3d, 2026-11-17)

| | CPU | Mémoire |
|---|---|---|
| Usage du pod `backstage` (6 relevés `kubectl top` à 10 s, 12 Components, 2 h d'âge, 0 redémarrage) | 4-9m | 259 Mi |
| Requests du chart | 200m | 256 Mi (sous l'usage) |
| **Requests retenues** | **10m** | **320 Mi** |
| Limites retenues | 1000m | 768 Mi |

- Image : index `sha256:997f6605…3f79c`. Il contient `linux/arm64` (`sha256:d8888561…1c53c`) et c'est l'imageID du pod k3d.
- La mesure k3d a été faite **avec** l'event-forwarder. Sur OKE, on reprend la mesure au repos avec `tools/oke/measure.sh`. Si l'usage dépasse la request, on remonte la request.
- Requests du namespace `openchoreo-control-plane` avec le portail : **50m / 552 Mi** (controller-manager 15m/64Mi, openchoreo-api 10m/48Mi, cluster-gateway 5m/24Mi, kgateway 10m/96Mi, backstage 10m/320Mi). Limites : 1792 Mi.
- Projection sur la pile OpenChoreo au repos : environ 0,7-0,95 Gi selon PHASE-B §4, plus environ 0,26 Gi, soit **≈ 0,96-1,21 Gi**. Le CPU reste sous 0,1 vCPU. Budget (objectif) : 1,5 Gi et 0,3 vCPU. Le portail ajoute 1 pod permanent (17 au total).
- Nœud : 1038 + 320 = 1358 Mi de requests sur 8650 Mi, soit environ 16 %. CPU : 385 + 10 = 395m sur 1830m. Seuil dur : 70 %.

Quota du namespace **appliqué dans le dépôt** (`platform/install/manifests/01-quotas.yaml`, effectif sur OKE après `install.sh --step 1 --apply`) : `requests.memory` 384 → **640 Mi**, `limits.memory` 1536 → **2304 Mi** ; `requests.cpu` (100m), `pods` (8) et LimitRange (max 1 CPU / 1 Gi) inchangés.

## 3. Points techniques établis (sources : chart 1.3.3 et docs v1.3.x)

- **Base de données.** `database.type=sqlite` (better-sqlite3) dans `/app/.config/backstage`, sur emptyDir. Le PVC n'existe que si `persistence.enabled=true`. Au redémarrage, les sessions sont perdues et le catalogue est reconstruit depuis l'API.
- **Secret `backstage-secrets`.** Clés : `backend-secret`, `client-secret` (client de login), `service-client-secret` (client de service, `backstage.auth.serviceClientSecretKey`) et `jenkins-api-key` (factice, exigée par le template). Le Secret n'est **pas** rendu par le chart ; il est créé hors dépôt.
- **PSA.** Le défaut du chart `appArmorProfile: Unconfined` est refusé par les profils baseline et restricted : on le retire. `readOnlyRootFilesystem` reste `false` : non testé, et non exigé par restricted.
- **IdP unique, deux clients.** Les URL OIDC du portail viennent de `security.oidc.*`, que l'API partage (les `OPENCHOREO_AUTH_*` sont posées après `extraEnv`, non surchargeables). Avec Authentik, chaque provider a son issuer, sauf en `issuer_mode: global` : c'est ce qui permet un `iss` unique pour plusieurs providers, donc des clients distincts (`docs/IDENTITY.md` §2.1). L'hypothèse `iss = https://auth.smadja.dev/` reste à prouver (T-A1).
- **Client de service.** Le chart 1.3.3 rend `OPENCHOREO_SERVICE_CLIENT_ID=openchoreo-backstage-service` et lit son secret dans `service-client-secret`. Le jeton `client_credentials` est demandé avec `scope=openid openchoreo-client-id` (`backstage.auth.scope`) : sans ce scope, pas de claim `client_id`, donc 401.
- **Catalogue.** Le portail lit le catalogue par le **fournisseur d'entités OpenChoreo** (Namespace → Domain, Project → System, Component → Component). **Les fichiers `generated/catalog/*/catalog-info.yaml` ne sont pas lus** : aucune `catalog.locations`. Ne pas les déclarer (collision d'entités, egress GitHub en plus).
- **Autorisation de la synchro.** La liaison système `backstage-catalog-reader-binding` est redéfinie dans `bootstrap.mappings` sur `client_id = openchoreo-backstage-service`. Les liaisons par défaut du chart sont remplacées ; `mcp-tryout-client-binding` (admin pour `service_mcp_client`) est supprimée.
- **Accès sans groupe.** Le portail autorise la lecture du catalogue à tout utilisateur connecté (seules les permissions `openchoreo.*` passent par l'authz de l'API). L'interdiction vient donc **d'Authentik** : policy binding de l'application sur les groupes de `docs/IDENTITY.md` §4, **`openchoreo-viewers`, `openchoreo-developers`, `authentik-admins`**. Rôles API (réalité de `platform/authz/bindings-humans.yaml`, corrigée le 2026-11-18) : `authentik-admins` → `lab-platform-admin` ; `openchoreo-developers` → `developer` (chart, portée cluster, sans `cluster-reader`) ; `openchoreo-viewers` → `lab-viewer` (projet Argo `lab-authz`).

## 4. Procédure d'activation (étape 6b)

Prérequis (IDENTITY, Paul) :
- dans Authentik, les providers en `issuer_mode: global` de `docs/IDENTITY.md` §5 : `openchoreo-backstage-client` (redirect URI `http://localhost:7007/api/auth/openchoreo-auth/handler/frame`, scopes `openid profile email offline_access openchoreo`) et `openchoreo-backstage-service` (`client_credentials`, scope `openchoreo-client-id`) ; application liée aux trois groupes ci-dessus ;
- étape 6 appliquée et validée (`verify.sh --step 6`) ; quota CP à 640 Mi / 2304 Mi (`install.sh --step 1 --apply`).
- checklist pas à pas (une action par ligne, Paul puis coordinateur) : `docs/IDP-USABLE.md` §5.

Création du Secret (opérateur ; valeurs jamais écrites dans le dépôt ni dans les sorties) :

```bash
kubectl -n openchoreo-control-plane create secret generic backstage-secrets \
  --from-literal=backend-secret="$(openssl rand -hex 32)" \
  --from-literal=client-secret="$AUTHENTIK_BACKSTAGE_CLIENT_SECRET" \
  --from-literal=service-client-secret="$AUTHENTIK_BACKSTAGE_SERVICE_SECRET" \
  --from-literal=jenkins-api-key=unused
```

Puis :

```bash
tools/oke/install.sh --step 6b            # dry-run : lit le quota et les NOMS de clés du Secret
tools/oke/install.sh --step 6b --apply    # CNP 03, helm upgrade du CP avec backstage.enabled=true, CA, mesure
tools/oke/verify.sh --step 6b
```

`install.sh --step 6b` refuse si le quota n'est pas relevé ou si une des 4 clés manque. `install.sh --step 6` refuse si le portail est actif (il le désinstallerait) : pour un upgrade du CP avec portail, relancer `--step 6b`.

**Critères d'arrêt** (un seul suffit ; rollback `tools/oke/uninstall.sh --step 6b --apply`) : `verify.sh --step 6b` en FAIL (pod non Available, redémarrage ou OOMKilled, AppArmor Unconfined, PVC, HTTPRoute/Ingress/Service non ClusterIP, pas de redirection Authentik) ; `budget_gate` en code 3, 4 ou 5 ; usage au repos du pod `backstage` au-dessus de 320 Mi sur 24 h (remonter la request par PR, ne jamais baisser).

Rollback : `helm upgrade` du CP avec `backstage.enabled=false`, suppression du Secret `backstage-secrets` et de la CNP `lab-allow-backstage-authentik` (la CNP de l'API reste).

Accès : `kubectl -n openchoreo-control-plane port-forward svc/backstage 7007:7007`, puis http://localhost:7007.

## 5. Contrôle statique (fait, 2026-11-17)

`tools/oke/render-check.sh` (CP rendu sans puis avec portail, chart 1.3.3, sha256 conforme à `versions.env`) :
- rc 0, `psa_check.py restricted` rc 0 (seul avertissement : Job `authz-bootstrap` sans requests, défauts du LimitRange) ;
- Deployment `backstage` : image épinglée par digest, 10m/320Mi → 1000m/768Mi, sans AppArmor `Unconfined`, volume `backstage-db` en emptyDir ;
- env : `OPENCHOREO_AUTH_CLIENT_ID=openchoreo-backstage-client`, `OPENCHOREO_SERVICE_CLIENT_ID=openchoreo-backstage-service`, `OPENCHOREO_AUTH_SCOPE=openid openchoreo-client-id`, URL Authentik globales ;
- 0 PVC, 0 Service LoadBalancer/NodePort, 0 HTTPRoute, 0 image sans digest ; pas de Deployment event-forwarder ; aucune liaison `mcp-tryout`, `platform-engineer` ou `sre`.

## 6. Critères d'acceptation (OKE, tous NOT_TESTED)

| # | Critère | Test |
|---|---|---|
| P1 | Pod sain, PSA, coût | `verify.sh --step 6b` (B6b-deploy, -restarts, -psa) ; 0 redémarrage en 24 h. Usage au repos ≤ request (`measure.sh`). Pile OpenChoreo ≤ 1,5 Gi et 0,3 vCPU (objectif), requests ≤ 70 % du nœud |
| P2 | Page de login Authentik atteinte | B6b-login : `/api/auth/openchoreo-auth/start?env=development` renvoie une `Location` vers `https://auth.smadja.dev/application/o/authorize/?…client_id=openchoreo-backstage-client…`. Le navigateur affiche la page Authentik |
| P3 | Session authentifiée | Login d'un membre de `openchoreo-viewers` : retour sur le portail, profil affiché ; `/api/auth/openchoreo-auth/refresh` renvoie 200 ; aucun `401` dans les logs Backstage |
| P4 | Catalogue | La page Catalog liste les Components existants au plus 120 s après le démarrage ; logs sans `Failed to fetch namespaces: 401/403` (jeton `openchoreo-backstage-service`, T-B5) |
| P5 | Interdiction sans groupe | Un utilisateur hors des trois groupes est refusé par Authentik (« access denied ») ; aucun cookie de session Backstage (T-Z1) |
| P6 | Pas d'exposition | B6b-noexpose : aucun HTTPRoute, Ingress ni Service LB/NodePort `backstage`, aucun PVC |

## 7. Limites

- Mono-réplica avec SQLite éphémère : chaque redémarrage déconnecte les sessions et vide le catalogue jusqu'à la synchro suivante (≤ 120 s).
- Pas de temps réel : une modification OpenChoreo apparaît en ≤ 120 s, faute d'event-forwarder.
- Onglets Workflows et Observability coupés (pas de plans associés). Onglets Deploy et Cell : selon le groupe (§3).
- L'issuer est partagé avec l'API (contrainte du chart) ; `iss` global non prouvé (T-A1). Découverte racine `https://auth.smadja.dev/.well-known/openid-configuration` en 404 : sans effet sur le portail (URL explicites), bloque `occ` (IDENTITY §2.4).
- Le default-deny egress n'est pas prouvable tant que C1 est ouvert.
- `readOnlyRootFilesystem` n'est pas activé (non testé).
- k3d ≠ OKE : les chiffres du §2 sont une base de dimensionnement, pas une preuve OKE.
