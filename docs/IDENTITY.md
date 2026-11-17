# Identité : Authentik (homelab) comme IdP de l'IDP OpenChoreo sur OKE

**Statut : BROUILLON, rien d'appliqué, tout NOT_TESTED.** Aucun client n'existe dans Authentik. Les seuls faits prouvés sont des lectures HTTPS publiques (§10). Rien n'est déclaré fonctionnel sans les tests du §9.

## 1. Décision (arbitrage de Paul)

- IdP = **Authentik de production du homelab** (`https://auth.smadja.dev`, 2026.8.3, blueprints kube-ops), utilisé comme **IdP externe** par OKE. Ni ThunderID, ni migration d'Authentik vers OKE dans ce mandat.
- **Un issuer unique** pour l'API et le portail (contrainte : l'API valide un seul `iss`, et le portail lit `security.oidc` partagé avec l'API, `docs/PORTAL.md` §3). Cet issuer est porté par **plusieurs providers Authentik** en `issuer_mode: global`, un par client : identités et permissions distinctes.
- Clients (tous en GitOps dans des blueprints séparés, secrets générés par Authentik, jamais dans Git) :

| Client (`client_id`) | Flux | Usage | Blueprint |
|---|---|---|---|
| `openchoreo-backstage-client` | authorization_code + refresh, confidentiel | login utilisateur du portail | `apps-openchoreo.yaml` (slug `openchoreo`) |
| `openchoreo-backstage-service` | client_credentials | service backend du portail (synchro catalogue) | `apps-openchoreo.yaml` |
| `openchoreo-cli` | authorization_code + PKCE, public | occ (bloqué, §2.4) | `apps-openchoreo.yaml` |
| `openchoreo-agent-reader` | client_credentials | agent lecture seule | `apps-openchoreo-agents.yaml` |
| `openchoreo-agent-operator` | client_credentials | agent écriture bornée | `apps-openchoreo-agents.yaml` |
| `miniflux` | authorization_code | Miniflux du labo (issuer propre, hors OpenChoreo) | `apps-miniflux.yaml` (slug `miniflux-lab`) |

Fichiers : `platform/identity/authentik/*.yaml` (blueprints, cible kube-ops), `platform/identity/openchoreo-oidc-values.yaml` (à fusionner dans `platform/install/values/openchoreo-control-plane.yaml`), `platform/authz/*.yaml` (rôles et liaisons du labo, testés sur k3d : 50 PASS ; remplacent le brouillon `identity/authz` supprimé le 2026-11-17), `platform/identity/network-policy-api-idp.yaml` (egress JWKS de l'API).

## 2. Ce qu'Authentik doit émettre (OpenChoreo 1.3.3, code source)

| Élément | Valeur | Source OpenChoreo |
|---|---|---|
| `iss` | `https://auth.smadja.dev/` (mode global, [S] T-A1) | `jwt/middleware.go` l.224-227, égalité stricte |
| Signature | RS256, `kid` présent, clé RSA dédiée `openchoreo-oidc` | `jwks.go` l.102 (clés non RSA ignorées), l.118 (`kid` obligatoire) |
| `jwksUrl` | `https://auth.smadja.dev/application/o/openchoreo/jwks/` | |
| `authorizationUrl` / `tokenUrl` | `…/application/o/authorize/` / `…/application/o/token/` (globaux) | |
| `aud` | = `client_id` du provider ; **non validée** (`security.jwt.audience: ""`) | `middleware.go` l.232 : validée seulement si configurée |
| Humain | `groups` (liste), filtrée sur `authentik-admins`, `openchoreo-developers`, `openchoreo-viewers` ; `preferred_username` | sujet `user`, priorité 1 |
| Service / agent | `client_id` (chaîne fixe) **par property mapping** (Authentik ne l'émet pas, il émet `azp`/`aud`) ; aucun `groups` | sujet `service_account`, priorité 2 |
| Format | jeton d'accès JWT (Authentik émet des JWT) | |

### 2.1 Pourquoi pas un provider unique (hypothèse de `docs/PORTAL.md`)
Un provider Authentik = un `client_id`. Un provider unique donnerait la même identité au login, à la synchro et aux agents : impossible de distinguer `agent-reader` d'`agent-operator`, ni de les révoquer séparément. Le mode `issuer_mode: global` (déjà utilisé comme champ dans kube-ops `apps-cloudflare.yaml`) donne un `iss` commun à plusieurs providers. **Tranché : issuer global + un provider par client.** Écarts à reporter par le coordinateur dans `docs/PORTAL.md` et `platform/portal/values-backstage.yaml` (je ne les modifie pas) : issuer `https://auth.smadja.dev/` au lieu de `…/application/o/openchoreo/` ; client de service distinct `openchoreo-backstage-service` (clé `service-client-secret` du Secret) ; groupes d'accès `openchoreo-viewers`/`openchoreo-developers`/`authentik-admins` au lieu de `openchoreo-portal`.

### 2.2 Isolation sans audience
Les providers OpenChoreo ont des `aud` différents, donc pas d'audience unique. Protection retenue : (1) `iss` global, qu'aucune autre application Authentik n'utilise (toutes en `per_provider`) ; (2) clé de signature dédiée `openchoreo-oidc` : un jeton d'une autre application, même en mode global un jour, porte un `kid` absent du JWKS OpenChoreo, donc il est rejeté. À prouver par T-Z2. Variante possible : forcer `aud=openchoreo-api` par mapping et poser `security.jwt.audience` ; non retenue tant qu'un test ne prouve pas qu'Authentik laisse un mapping surcharger `aud`.

### 2.3 Scopes à demander
- Portail et CLI : `openid profile email offline_access openchoreo` (scope `openchoreo` = groupes filtrés + `given_name`/`family_name`).
- Service du portail et agents : `scope=openid openchoreo-client-id`. **Sans ce scope, pas de claim `client_id`, donc 401.** Pour le portail, c'est `backstage.auth.scope`.
- Nom de scope dédié : un second mapping `groups` rendrait ambigus les `!Find [scope_name, "groups"]` des autres blueprints kube-ops.

### 2.4 Limite : découverte racine absente (occ, MCP navigateur)
`occ` lit `<issuer>/.well-known/openid-configuration` (`internal/occ/auth/oidc_config.go` l.127), y compris pour `occ login --client-credentials`. Avec l'issuer global, cela donne `https://auth.smadja.dev/.well-known/openid-configuration`, qui répond **404** (§10). Il en va de même des clients MCP qui découvrent le serveur d'autorisation. Conséquence : **occ et le login MCP navigateur ne marchent pas** tant que kube-ops ne redirige pas ce chemin. Option B de la PR (§5) : une redirection 302 de ce seul chemin vers `/application/o/openchoreo/.well-known/openid-configuration`. Agents : sans effet, ils obtiennent leur jeton par POST direct sur `tokenUrl` puis appellent l'API/MCP en `Authorization: Bearer`.

## 3. Flux

**Utilisateur (portail).** Navigateur → `http://localhost:7007` (port-forward, pas d'exposition) → redirection vers `auth.smadja.dev/application/o/authorize/` (client `openchoreo-backstage-client`) → la policy Authentik exige un des 3 groupes, sinon accès refusé chez Authentik → code → le pod Backstage l'échange sur `tokenUrl` (egress `lab-allow-backstage-authentik`) → appels à l'API avec le jeton d'accès de l'utilisateur. L'API vérifie la signature (JWKS en cache), `iss` et `exp`, puis classe le sujet (`groups`), puis évalue les liaisons authz.

**Service du portail.** Backstage → `POST tokenUrl` (`grant_type=client_credentials`, client `openchoreo-backstage-service`, `scope=openid openchoreo-client-id`) → JWT avec `client_id=openchoreo-backstage-service` → rôle `backstage-catalog-reader`.

**Agent.** L'agent reçoit son secret hors Git (Doppler, remis par Paul) → `POST tokenUrl` (client_credentials, `scope=openid openchoreo-client-id`) → JWT de 15 min → API ou MCP (`/mcp`) en Bearer. L'API classe le sujet en `service_account` d'après `client_id` et lui applique `lab-viewer` (reader) ou `lab-viewer` + `lab-release-operator` limité au namespace `default` (operator).

**Miniflux.** Flux OIDC classique sur son propre issuer `https://auth.smadja.dev/application/o/miniflux-lab/`, avec liaisons `family` et `friends`. `OAUTH2_USER_CREATION=1` : le refus vient d'Authentik.

## 4. Groupes et clients → rôles OpenChoreo

| Sujet | Claim | Rôle | Portée | Où |
|---|---|---|---|---|
| `authentik-admins` (existant) | groups | `admin` | cluster | values `bootstrap.mappings` |
| `openchoreo-developers` (nouveau) | groups | `developer` + `cluster-reader` | ns `default` / cluster | values |
| `openchoreo-viewers` (nouveau) | groups | `lab-viewer` (lecture sans secrets, exec ni journaux) | cluster | `platform/authz/bindings-humans.yaml` |
| `openchoreo-backstage-service` | client_id | `backstage-catalog-reader` | cluster | values |
| `openchoreo-agent-reader` | client_id | `lab-viewer` | cluster | authz |
| `openchoreo-agent-operator` | client_id | `lab-viewer` + `lab-release-operator` (`releasebinding:view/update`) | cluster / ns `default` | authz |

- `bootstrap.mappings` **remplace** la liste du chart. Liaisons retirées : `mcp-tryout-client-binding` (rôle **admin** pour `client_id=service_mcp_client`), `platform-engineer`, `sre`, et celles des agents non déployés.
- Le hook fait un upsert sans suppression : si une installation a déjà créé les liaisons par défaut, il faut les supprimer par PR et le vérifier (T-Z5).
- **Conflit à trancher par Paul** : `docs/APP-CONTRACT.md` §5 prévoit un agent en lecture seule, alors qu'`agent-operator` écrit (promotion/rollback). Argo CD réconcilie `generated/` : une écriture API est écrasée au sync suivant. Elle ne sert qu'en urgence ; le changement durable reste une PR.

## 5. PR kube-ops (Authentik = production PROTÉGÉE, décision de Paul requise)

Je ne l'ouvre pas. Prérequis manuel de Paul **avant le merge** : Authentik → System → Certificates → Generate, nom `openchoreo-oidc`, type **RSA**, validité 3 ans. Sinon les blueprints échouent sur `!Find`.

**Texte exact proposé :**

```markdown
## Authentik : clients OIDC pour l'IDP OpenChoreo (OKE lab) et Miniflux lab

Ajoute trois blueprints, rédigés dans openchoreo-lab (`platform/identity/authentik/`) :
- `apps-openchoreo.yaml` : groupes `openchoreo-developers` et `openchoreo-viewers` ; scope `openchoreo` (groupes filtrés) ;
  providers `openchoreo-backstage-client` (login du portail), `openchoreo-backstage-service` (client_credentials) et `openchoreo-cli` (public, PKCE) ;
  accès par groupe : `openchoreo-viewers`, `openchoreo-developers`, `authentik-admins`.
- `apps-openchoreo-agents.yaml` : providers client_credentials `openchoreo-agent-reader` et `openchoreo-agent-operator`, sans liaison humaine.
- `apps-miniflux-lab.yaml` : provider `miniflux` (slug `miniflux-lab`), accès `family` et `friends`.

Les providers OpenChoreo sont en `issuer_mode: global` (iss `https://auth.smadja.dev/`) et signent avec la clé RSA dédiée
`openchoreo-oidc`, générée dans Authentik avant le merge. Le claim `client_id` des clients de service vient d'un mapping
à valeur fixe (scope `openchoreo-client-id`). Aucun `client_secret` dans Git : Authentik les génère à la création.
Aucune ExternalSecret, aucun `envFrom` modifié.

Changements :
- `k8s/infrastructure/auth/authentik/extra/kustomization.yml` : trois fichiers ajoutés à `authentik-blueprints` ;
- `tests/harness/authentik-friends-contract-test.sh` : `miniflux-lab` ajouté à ALLOWED ;
- `docs/operations/authentik-access-model.md` : ligne `miniflux-lab` (friends + family) et `openchoreo*` (classe admin/dev).

Option B (décision séparée) : HTTPRoute `auth.smadja.dev`, redirection 302 du seul chemin exact
`/.well-known/openid-configuration` vers `/application/o/openchoreo/.well-known/openid-configuration` (aujourd'hui 404).
Nécessaire pour `occ` et le login MCP navigateur.

Impact : aucune application existante n'est modifiée. Nouvelles entrées dans la bibliothèque des membres des groupes
liés. Les applications sans liaison humaine (agents, service) sont masquées (`blank://blank`). La clé dédiée isole les jetons
OpenChoreo des autres applications.
Rollback : `git revert`. Les objets créés par blueprint restent dans Authentik : à supprimer à la main ou par `state: absent`.
Tests : docs/IDENTITY.md §9 d'openchoreo-lab, à exécuter après le merge.
```

Après le merge, Paul copie, hors Git, chaque secret généré : `openchoreo-backstage-client` → clé `client-secret` du Secret `backstage-secrets` ; `openchoreo-backstage-service` → clé `service-client-secret` ; les deux agents → Doppler ; `miniflux` → clé `MINIFLUX_OAUTH2_CLIENT_SECRET` du coffre `lab-secrets`.

Limite assumée : une réinitialisation de la base Authentik régénère ces secrets. Il faut alors les recopier, contrairement à la convention kube-ops `!Env`/Doppler.

## 6. Rotation et révocation

- **Rotation** (par client) : générer une nouvelle valeur dans Authentik (provider → Client secret), puis mettre à jour le consommateur (Secret, Doppler) et redémarrer Backstage si besoin. L'ancien secret cesse de servir immédiatement. Les jetons déjà émis restent valides jusqu'à `exp` (15 min).
- **Révocation d'un agent** : changer son secret. Pour un arrêt durable : `state: absent` sur le provider par PR, ou suppression de la liaison authz (`lab-agent-*-binding`) par PR openchoreo-lab. Effet côté API : au plus 15 min (JWT sans introspection).
- **Révocation d'un humain** : le retirer du groupe. Refresh refusé, et `groups` filtré à la prochaine émission. Le jeton d'accès en cours vit au plus 15 min ; le refresh token au plus 12 h, révocable dans Authentik.
- **Clé `openchoreo-oidc`** : en générer une nouvelle, l'assigner aux 5 providers (PR), puis attendre le rafraîchissement JWKS de l'API (`kid` inconnu ⇒ nouvelle lecture, au plus 1 h sinon).

## 7. Homelab éteint la nuit

- **Login et refresh impossibles** (authorize/token injoignables). Les sessions du portail tombent à l'expiration du jeton d'accès (15 min) faute de refresh. Les agents ne peuvent pas obtenir de jeton : un jeton obtenu avant l'arrêt sert au plus 15 min. Compromis réglable par `access_token_validity` : plus long = plus d'autonomie la nuit, mais révocation plus lente (décision de Paul).
- **JWKS** : l'API garde les clés en cache si le rafraîchissement échoue (`jwks.go` refresh : les clés ne sont remplacées qu'en cas de succès ; échec journalisé en Warn). Les jetons valides continuent donc d'être acceptés. Mais `lastRefresh` n'avance pas en cas d'échec : après l'intervalle (1 h), **chaque requête retente le GET** et peut subir le délai du client HTTP (à mesurer, T-N3).
- **Redémarrage de l'API la nuit** : cache vide, donc **toute requête est refusée en 401**. Échec fermé, jamais d'ouverture.
- Miniflux : login impossible la nuit ; sa session native survit (cookie Miniflux).

## 8. À faire hors de mon périmètre (coordinateur)

- Fusionner `openchoreo-oidc-values.yaml` dans les values CP et réconcilier `platform/portal/values-backstage.yaml` (issuer, `serviceClientId`, `scope`).
- `apps/miniflux/app.yaml` : `OAUTH2_OIDC_DISCOVERY_ENDPOINT` et `identity.oidc.issuer` = `https://auth.smadja.dev/application/o/miniflux-lab/`, `provider: authentik`, `allowedGroups: [family, friends]`, egress `{fqdn: auth.smadja.dev, ports: [443]}` (APP-CONTRACT E2). Retirer `adminGroup: admin` : Miniflux ne reçoit ni `admin` ni `authentik-admins`.
- Ajouter la CNP `network-policy-api-idp.yaml` au même endroit que celle du portail (C1 reste ouvert).

## 9. Tests à exécuter (tous NOT_TESTED ; preuve datée, sans secret dans les sorties)

| # | Test | Attendu |
|---|---|---|
| T-A1 | Discovery `…/application/o/openchoreo/.well-known/openid-configuration` | 200, `issuer` = `https://auth.smadja.dev/` exactement |
| T-A2 | JWKS `…/application/o/openchoreo/jwks/` | 1 clé RSA RS256, `kid` ≠ celui d'argocd |
| T-A3 | client_credentials réel `openchoreo-agent-reader` (secret lu depuis Doppler, jamais affiché) ; décoder le jeton | JWT RS256, `iss` global, `client_id=openchoreo-agent-reader`, pas de `groups`, `exp-iat` = 900 |
| T-A4 | Même requête **sans** `scope=openchoreo-client-id` | Jeton sans `client_id` ; API : 401 |
| T-A5 | Login OIDC réel au portail (membre `openchoreo-viewers`) | Retour au portail ; jeton avec `groups=["openchoreo-viewers"]` ; catalogue visible |
| T-B1 | Jeton reader : `GET` d'une ressource (API et MCP) | 200 |
| T-B2 | Jeton reader : écriture (`PUT` d'une releasebinding, outil MCP de déploiement) | 403 |
| T-B3 | Jeton operator : `releasebinding:update` dans `default` | 200 (puis revert par Argo, constaté) |
| T-B4 | Jeton operator hors périmètre : `component:update`, `workload:create`, `resource:read-secrets`, releasebinding d'un autre namespace | 403 pour chacun |
| T-B5 | Jeton `openchoreo-backstage-service` : synchro catalogue | Logs Backstage sans 401/403 ; Components listés |
| T-Z1 | Utilisateur sans groupe OpenChoreo (ex. membre de `family` seul) | Refusé par Authentik au login ; un jeton forgé par un autre client avec `groups: []` donne 401 à l'API |
| T-Z2 | Jeton d'une autre application Authentik (ex. argocd) envoyé à l'API | 401 (`iss` ou `kid`) |
| T-Z3 | Jeton expiré (rejouer T-A3 après 16 min) | 401 |
| T-Z4 | Jeton altéré (signature modifiée) ; audience incorrecte avec `security.jwt.audience` posée dans un test dédié | 401 |
| T-Z5 | `kubectl get clusterauthzrolebinding` | Ni `mcp-tryout-client-binding`, ni `platform-engineer-binding`, ni `sre-binding` |
| T-M1 | Miniflux : login d'un membre de `family`, puis d'un utilisateur hors `family`/`friends` | Compte créé ; puis refus Authentik et aucun compte créé |
| T-N1 | Homelab éteint : jeton valide en cache | Accepté jusqu'à `exp` |
| T-N2 | Homelab éteint : redémarrage du pod API | 401 sur tout appel (échec fermé) |
| T-N3 | Homelab éteint, plus de 1 h après le dernier JWKS | Latence par requête mesurée (délai du GET JWKS) |
| T-O1 | `occ login` (après l'option B) | Login PKCE, puis `occ namespace list` OK |

## 10. Vérifié (lecture HTTPS publique, sans client créé)

| Date | Vérification | Résultat |
|---|---|---|
| 2026-11-17 19:38 CET | `GET /application/o/argocd/.well-known/openid-configuration` | 200 ; issuer par provider `…/application/o/argocd/` ; authorize/token/userinfo globaux ; `client_credentials` dans `grant_types_supported` ; `groups` dans `claims_supported` ; RS256 seul |
| 2026-11-17 19:38 CET | `GET /application/o/argocd/jwks/` | 1 clé RSA, RS256, `kid` présent (compatible `jwks.go`) |
| 2026-11-17 19:38 CET | `GET /.well-known/openid-configuration` (racine) | **404** (§2.4) |
| 2026-11-17 19:43 CET | `POST /application/o/token/` avec un client inexistant | 400 `invalid_client` : endpoint joignable serveur à serveur via Cloudflare, sans défi Access |
| 2026-11-17 19:43 CET | `GET /application/o/openchoreo/jwks/` | 404 : slug libre |

Non vérifiable sans client : `iss` en mode global, présence d'`azp`, surcharge d'`aud`, scopes appliqués en client_credentials, policy d'application en client_credentials. Tous couverts par §9.
