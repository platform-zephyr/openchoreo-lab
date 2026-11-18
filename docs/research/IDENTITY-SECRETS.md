# Identités, secrets et migration Doppler : recherche
Statut : **PROPOSITION de recherche**, rien n'est appliqué, aucun cluster ni Doppler touché. Date : 2026-11-18.
Tags : [S] lu dans un fichier cité · [NV] non vérifié, à prouver par un spike · [V AAAA-MM-JJ + URL] vérifié en ligne le 2026-11-18 (`VERIFICATION-2026-11-18.md`) · [D] décision de Paul (2026-11-18).
Aucune valeur, aucun identifiant de compte ici : on décrit des mécanismes et des catégories. Le dépôt est public.

## 1. Conclusion
1. **Doppler passe de plusieurs dizaines de jetons et plusieurs projets à 1 projet, 7 configs, 7 jetons permanents** (+1 jeton temporaire de migration).
   Règle : un jeton = un consommateur × une config, lecture seule sauf un seul jeton d'écriture IaC (§5).
2. **OpenBao devient le seul coffre des secrets internes** (apps, plateforme, clés LLM). Les cellules n'ont aucun accès Doppler.
3. **Ajouter un utilisateur = une PR `users/<id>.yaml`** sans donnée personnelle (dépôt public) ; Authentik porte l'état civil.
   Le retirer = désactiver, révoquer sessions et jetons, retirer des groupes, purger (MANDAT) (§3).
4. **Migration en 4 temps** : inventaire par motif, copie idempotente sans affichage de valeur, ESO en ombre puis bascule
   app par app, nettoyage Doppler gardé par une liste fermée en CI (§6).
5. **Point dur trouvé** : le déscellement. `OPENBAO-DOPPLER-ESO.md` §2 refuse une clé de déscellement dans un Secret du cluster ;
   OCI KMS exige un credential OCI ou l'IMDS, interdits dans les pods (HOMELAB-INFRA §6.1 pt 4). Seul le seal statique
   (clé dans Doppler, livrée par ESO, précédent homelab-infra [S]) tient. Amendement proposé §8, Paul tranche.
6. **Le « geste humain » ne disparaît pas partout** : créer une identité reste MANDAT (ADR-0002 §3). L'approbation de la PR
   `users/` par Paul *est* le mandat. Désactiver est AUTONOME (fail-safe, réversible).

## 2. Matrice identité × secrets (moindre privilège)
Conventions : OB = OpenBao, DP = Doppler, `A/E` = `<app>/<env>`. « Valeur » = lecture du contenu ; « présence » = métadonnées (liste, existence).

| Identité | Authentification | OpenBao | Doppler | Secrets K8s | Durée du jeton |
|---|---|---|---|---|---|
| Paul (admin) | OIDC Authentik, groupe `authentik-admins`, MFA | policy `platform-admin` : config + présence ; valeur **seulement** `break-glass` (audité) | session personnelle MFA ; config `root` | admin | OB 1 h, max 4 h |
| Humain déposant (`openchoreo-developers`) | OIDC Authentik | `apps/*/*/<nom provided>` : **create/update sans read**, présence | aucun | aucun | OB 1 h |
| Humain famille/amis | OIDC Authentik | aucun | aucun | aucun | n/a |
| Agent dev (Claude, Codex, runner cloud) | GitHub App (jeton d'installation) | aucun | config `agents` lecture seule, uniquement les clés d'accès de l'exécutant | aucun | 1 h |
| Agent ops (`agent-reader`) | Authentik `client_credentials` | aucun ; la présence vient de `app-status` (`secret-missing`) | aucun | aucun (pas de lecture des Secrets) | 15 min |
| Agent remédiation (`agent-operator`) | idem + liaison authz bornée | aucun | aucun | aucun | 15 min |
| OpenChoreo (control plane, cluster-agent) | SA Kubernetes | aucun (ils manipulent `SecretReference`, jamais la valeur) | aucun | selon `platform/authz` | SA 1 h |
| Backstage / portail | SA, auth K8s OB | rôle `portal` : lecture `platform/portal/*` | aucun | son namespace | 1 h |
| ESO apps (par cluster) | auth K8s OB | v1 : rôle `eso-apps` lecture `apps/*` + VAP sur `remoteRef` ; **cible** : un `SecretStore` et un rôle par cellule, lecture `apps/A/E/*` | aucun | écrit les Secrets de cellule | 15 min |
| ESO plateforme (par cluster) | jeton DP statique | aucun | `oke-runtime` ou `homelab-runtime` (1 jeton chacun), `ClusterSecretStore` limité aux namespaces de plateforme | écrit les Secrets de plateforme | 90 j |
| Authentik (serveur) | auth K8s OB | lecture `apps/+/+/oidc_client_secret` uniquement | bootstrap admin via `homelab-runtime`/`oke-runtime` | son namespace | 15 min |
| Réconciliateur OpenBao (Job Argo) | auth K8s OB | rôle `bao-config` : écriture `sys/policies`, `auth/*`, **aucune** lecture `kv/data` | aucun | aucun | 15 min |
| Générateur de secrets (Job) | auth K8s OB | création seule (`cas=0`) `apps/*`, `platform/*` | aucun | aucun | 15 min |
| Crossplane (homelab) | jeton fournisseur | aucun | jeton Cloudflare Access-only dans `homelab-runtime`, via ESO | son namespace | 90 j |
| CI GitHub (PR, k3d) | n/a | aucun (valeurs factices en k3d, ADR AGENTS.md) | aucun | n/a | n/a |
| ARC / OpenTofu | jeton DP | rôle `bao-bootstrap` hors v1 | `iac-plan` (lecture seule), `iac-apply` (écriture) | aucun | 90 j |
| OpenBao (pod) | n/a | n/a | `seal` : 1 jeton, lu seulement par le namespace `openbao` | Secret de seal, lisible par le seul pod | 90 j |
| Job de migration | jeton DP temporaire + auth K8s OB | rôle `migration` : création seule | jeton lecture seule, **TTL 24 h** | aucun | 24 h |

Règles transverses : (a) aucun agent ne lit une valeur de secret, jamais (ADR-0014 §5) ; (b) aucune identité n'a deux
chemins d'élévation ; (c) un secret consommé **hors cluster** par un exécutant externe (agent, IaC) reste dans Doppler : c'est
le complément de la règle ADR-0014 §4 ; (d) la clé LLM d'une plateforme est un secret de plateforme `platform/llm/<fournisseur>`
lu par un seul consommateur (passerelle) ; sinon une clé `provided` par app, avec plafond de coût chez le fournisseur.

### 2.1 Politiques OpenBao (catégories, sans valeur)
- Montage KV v2 `kv/`. Chemins : `apps/<app>/<env>/<nom>` (apps), `platform/<composant>/<nom>` (plateforme), `platform/llm/*`.
  Pas de chemin `shared/` : un secret appartient à un seul propriétaire.
- Jetons : TTL 15 min (machines), 1 h (humains), `max_ttl` 4 h, jamais de jeton `root` hors génération initiale (révoqué ensuite).
- Auth **Kubernetes** pour toute machine in-cluster (`bound_service_account_*`) ; auth **OIDC/JWT Authentik** pour les humains,
  groupes → policies (`authentik-admins` → `platform-admin`, `openchoreo-developers` → `secret-provider`).
- Politiques générées depuis le dépôt (`appgen` liste les cellules, un réconciliateur applique) : jamais à la main ;
  le chemin `sys/*` n'est écrit que par `bao-config`.
- Création sans lecture : `capabilities = ["create","update"]` sur `kv/data/...`, `["read","list"]` sur `kv/metadata/...`.
  Génération : `cas=0` donne l'idempotence (un second passage échoue proprement) ; politique de mots de passe côté OpenBao [V 2026-11-18 + https://openbao.org/api-docs/system/policies-password/ : `GET /sys/policies/password/:name/generate` renvoie `{"password": …}`].
- Audit : périphérique d'audit vers stdout (valeurs hachées), collecté ; alertes §7.

## 3. Golden paths utilisateur
### 3.1 Ajouter (classe REVUE, l'approbation de Paul vaut mandat)
```yaml
# users/<id>.yaml : AUCUNE donnée personnelle (dépôt public), l'id est un pseudonyme
id: <pseudonyme>
kind: human
groups: [family]          # jamais d'accès par utilisateur (ADR-0007 §3)
expires: 2027-06-30       # obligatoire pour `friends`, facultatif pour `family`
status: active
```
1. L'agent ouvre une PR : `users/<id>.yaml`. `tools/usergen` génère `generated/identity/authentik/users.yaml` (blueprint).
2. CI : schéma, groupe autorisé (liste fermée), **refus de tout groupe privilégié** (`authentik-admins`, `openchoreo-*`) hors MANDAT,
   refus de PII (e-mail, nom) dans le fichier, test k3d : utilisateur dans `family` voit l'app `family`, refus ailleurs.
3. Paul approuve (`users/` rejoint le noyau CODEOWNERS, amendement ADR-0002 §2). Argo applique le blueprint.
4. **Hors Git** : Paul émet un lien d'invitation à usage unique (e-mail et nom saisis dans Authentik seulement). Le lien ne passe
   ni par la PR ni par une conversation d'agent.
5. Preuve : événement d'inscription Authentik + connexion d'un jeton de test, datés.

Accès aux apps : `identity.groups` de chaque `app.yaml` (ADR-0007) ∩ groupes de l'utilisateur. Un nouveau groupe = `groups/<nom>.yaml`, REVUE.

### 3.2 Retirer (départ)
| Étape | Mécanisme | Classe |
|---|---|---|
| 1. Désactiver | PR `status: disabled` → blueprint `is_active: false`, `groups: []` | AUTONOME sur demande de Paul ou alerte |
| 2. Révoquer sessions et jetons | Job `identity-offboard` (jeton API Authentik à droits bornés : sessions, jetons, refresh) | AUTONOME, déclenché par l'étape 1 |
| 3. Sessions locales des apps | cookies d'app non révoqués par l'IdP : durée maximale déclarée par app ; liste produite par le Job [V 2026-11-18 + https://docs.goauthentik.io/add-secure-apps/providers/oauth2/frontchannel_and_backchannel_logout/ : le fournisseur OAuth2/OIDC d'Authentik gère le *back-channel logout* (authentik ≥ 2025.8.0, en préversion à cette date) mais **l'application doit elle-même le prendre en charge** ; la liste des apps sans support reste donc à produire] | rapport |
| 4. Données personnelles | rapport par app : comptes OIDC créés, données de l'utilisateur ; conservation 30 j puis purge | purge = **MANDAT** (irréversible, ADR-0008) |
| 5. Suppression du compte | PR `state: absent` + retrait de `users/<id>.yaml` ; PII effacées dans Authentik seul | MANDAT |

Preuve de départ : jeton émis avant la désactivation refusé après son `exp` (15 min) ; refresh refusé ; accès à l'app refusé.
Limites : retirer un fichier ne supprime pas l'objet Authentik (cf. rollback de `docs/IDENTITY.md` §5) : c'est pourquoi `state: absent` est explicite.
Expiration `expires:` : un job quotidien ouvre la PR de désactivation à l'échéance (AUTONOME, fail-safe).

### 3.3 Blueprints : où ils tournent
Authentik de production est géré par kube-ops (`apps-*.yaml` sous `k8s/infrastructure/auth/authentik/extra/blueprints`, `!Env` pour les secrets [S]).
Cible : **une seule PR kube-ops (MANDAT)** qui monte un second ConfigMap `lab-blueprints` (`blueprints.configMaps` du chart [V 2026-11-18 + https://raw.githubusercontent.com/goauthentik/helm/main/charts/authentik/values.yaml : liste de ConfigMaps montés, seules les clés se terminant par `.yaml` sont découvertes ; `blueprints.secrets` existe aussi ; Authentik rescanne le répertoire toutes les 60 min par défaut, https://docs.goauthentik.io/docs/customize/blueprints/]) alimenté depuis
ce dépôt ; ensuite aucune PR kube-ops par utilisateur ou par app. Les secrets clients viennent d'OpenBao via ESO (`!Env`), plus de Doppler.

## 4. Identité des IA
- Une identité logique par **usage × exécutant** (`identities/agents/<id>.yaml`, sans valeur) : surface (GitHub App, client Authentik,
  rôle OpenChoreo), durée, propriétaire, échéance, secrets accessibles (catégories). CI : propriétaire et échéance obligatoires.
- Authentik : un `client_credentials` par usage, jeton 15 min, claim `client_id` (`docs/IDENTITY.md` §2). Pour les agents *in-cluster*,
  préférer un JWT fédéré (`client_assertion` d'un jeton de SA) : plus de secret statique [V 2026-11-18 + https://docs.goauthentik.io/add-secure-apps/providers/oauth2/machine_to_machine/ : `client_credentials` avec `client_assertion_type=…jwt-bearer`, source OAuth fédérée (JWKS), les jetons de ServiceAccount Kubernetes projetés sont explicitement pris en charge ; la page ne porte pas de marque Enterprise (version 2026.8 en préversion) : la disponibilité en OSS stable reste à prouver par un spike].
- Le secret du client d'un agent *externe* (cloud, poste de Paul) reste en Doppler `agents` ; il n'est jamais lu par une cellule.
- Coupe-circuit : supprimer la clé GitHub App, régénérer le secret du client, retirer la liaison authz (PR). Drill trimestriel.
- Frontière : un agent ne crée pas de client, de clé ou de jeton (ADR-0002 §3). Création d'un client agent = MANDAT.

## 5. Refonte Doppler (blast radius et nombre de jetons)
Constat [S] (inventaire homelab-infra, détail hors dépôt public) : nombre de jetons proche du plafond du plan, plusieurs projets
et domaines runtime, secrets répartis dans plusieurs roots, un `ClusterSecretStore` unique pour tout le cluster.
Cause principale : les secrets d'app vivent dans Doppler, donc un jeton par domaine et par cluster. OpenBao retire cette cause.

| Config (projet unique, un environnement) | Contenu (catégorie) | Jetons | Lecteur |
|---|---|---|---|
| `root` | récupération Doppler/Oracle/GitHub, clés de récupération d'OpenBao (copie) | **0** | Paul seul, hors service tokens |
| `seal` | clé de déscellement d'OpenBao | 1 (lecture) | ESO, namespace `openbao` |
| `oke-runtime` | primitives externes lues par la plateforme OKE (tunnel, stockage de sauvegarde) | 1 | ESO plateforme OKE |
| `homelab-runtime` | idem homelab (+ jeton Cloudflare Access-only de Crossplane) | 1 | ESO plateforme homelab |
| `iac-plan` | identifiants fournisseurs en lecture seule | 1 | ARC, plans de PR |
| `iac-apply` | identifiants fournisseurs en écriture | 1 (écriture) | ARC, apply sur `main` |
| `agents` | clés d'accès des exécutants externes | 2 (local, runner) | exécutants |
| (migration) | copie temporaire, lecture seule | 1, TTL 24 h | Job de migration |

Total : **7 permanents** (≤ 8 avec la migration), 1 projet, 7 configs (contre plusieurs dizaines de jetons et plusieurs projets aujourd'hui).
- **Blast radius** : compromettre un cluster n'expose que sa config `*-runtime` ; compromettre un runner agent n'expose que `agents` ;
  `seal` et `root` ne sont jamais montés avec autre chose. Aucune cellule d'app n'a de jeton Doppler (CI : refus d'un store Doppler référencé hors namespaces de plateforme).
- **Références Doppler** : Tofu écrit dans `iac-apply` et les configs `*-runtime` n'ont que des références vers lui, ce qui évite un jeton d'écriture par config [NV 2026-11-18 : introuvable dans la doc officielle ; des fils de la communauté Doppler indiquent qu'un jeton de service est limité à une seule config et que le contournement est une config qui référence les autres ; à prouver par un spike avant d'adopter, https://community.doppler.com/t/cross-project-service-tokens/773].
- **Rotation** : TTL 90 j à la création [V 2026-11-18 + https://docs.doppler.com/docs/service-tokens : un jeton de service peut recevoir une expiration (jeton « éphémère » supprimé automatiquement), lecture seule par défaut, accès en écriture optionnel ; la doc lue ne distingue pas les plans, le plan Developer offre 50 jetons de service, https://www.doppler.com/pricing] ; un jeton émis par Tofu, jamais écrit à la main ;
  l'ancien est révoqué après preuve d'usage du nouveau. Livraison du jeton ESO au cluster : à qualifier (amorce Argo ou root ARC) : IDS-15.
- **Jeton d'espace de travail** de la root `doppler` (crée projets, configs, jetons) : le plus dangereux ; la structure étant fixe, il n'est utilisé que sur MANDAT, jamais en continu [NV 2026-11-18 : la disponibilité d'un jeton d'espace de travail sur le plan gratuit n'est pas documentée sur les pages lues].
- Chemin legacy kube-ops : ne pas y toucher ; la consolidation 46→19 de homelab-infra (#540) s'y applique jusqu'au retrait (T-052). La nouvelle plateforme n'y réutilise aucun jeton.

## 6. Migration Doppler → OpenBao
**Inventaire par catégorie** (par motif de nom, résultat sans valeur ; le manifeste réel n'est **pas** committé, seules les règles le sont) :

| Cat. | Exemples génériques | Destination |
|---|---|---|
| P primitives externes | jetons de fournisseurs (edge, stockage, cloud), GitHub App, clé de seal | **restent Doppler** |
| G secrets d'app générés | mots de passe de base, clés de chiffrement d'app | OB `apps/A/E/*`, **copiés** (jamais régénérés : les bases attendent l'ancienne valeur) |
| O secrets clients OIDC | `APP_*_OIDC_CLIENT_SECRET*` | OB `apps/A/E/oidc_client_secret` |
| T clés tierces propres à une app | clés d'API d'un service | OB `apps/A/E/*` (`provided`) |
| L clés LLM | clés de fournisseurs de modèles | OB `platform/llm/*` |
| I jetons internes de plateforme | cookies, jetons inter-services | OB `platform/*` |
| R secrets de restauration | mot de passe de sauvegarde chiffrée | **restent Doppler** (nécessaires si OpenBao est perdu) |
| X obsolètes | doublons `_V1`, apps retirées, `handoff`, pont `cluster` | non migrés, supprimés au nettoyage |

**Tâche d'init `tools/secrets-migrate`** (MANDAT à l'exécution, par Paul ou Job borné ; un agent ne lit jamais Doppler) :
1. `--dry-run` : liste les noms par catégorie (comptes seulement dans la sortie), vérifie les consommateurs en cherchant `remoteRef.key` dans les dépôts.
2. Copie : valeur lue du CLI Doppler et écrite dans OpenBao **par stdin**, jamais en argument ni en variable exportée ; `set +x` ; chemin déduit de la règle de catégorie.
3. Idempotence : écriture `cas=0` ; si la clé existe, compare les empreintes (HMAC avec sel éphémère) : égal = `SKIP`, différent = `CONFLICT` (aucun écrasement sans `--force <clé>` explicite).
4. Vérification : relecture des deux côtés, empreintes comparées en mémoire ; rapport JSON `{catégorie: {copied, skipped, conflict, missing}}`, daté, sans valeur ni nom sensible, archivé comme preuve.
5. **Ombre** : un ExternalSecret `<nom>-bao` dans un namespace de test lit OpenBao ; un Job compare les empreintes avec le Secret actuel.
6. **Bascule par app** (une PR, au moment où l'app entre dans la plateforme, T-052) : `secretStoreRef` → `openbao-apps`, même nom de Secret donc pas de redémarrage forcé ; retour = `git revert`.
7. **Nettoyage** : clés X immédiatement (consommateur absent prouvé) ; clés G/O/T/L/I après 14 jours stables et preuve runtime de l'app ; suppression par Tofu (`prevent_destroy` : MANDAT) ;
   puis révocation des jetons devenus sans lecteur, puis suppression des projets vides. Pas d'export intermédiaire (contrat `docs/secrets.md` interdit `secrets download`) :
   le retour arrière est l'historique de révision de Doppler (**CORRIGÉ 2026-11-18** : l'historique avec « Rollback Changes » existe pour l'ajout, la modification et la suppression de secrets [V https://docs.doppler.com/docs/versioning.md], **mais le plan Developer ne conserve que 3 jours de journal d'activité** [V https://www.doppler.com/pricing] : la fenêtre de retour arrière est de 3 jours, pas indéfinie) et la copie vérifiée dans OpenBao.
8. Garde finale en CI : l'inventaire Doppler (noms) **égale** la liste fermée des primitives ; un secret présent des deux côtés échoue.

Pourquoi la bascule suit T-052 : les ExternalSecret legacy vivent dans kube-ops (128 fichiers [S]) ; les réécrire en bloc coûte plus qu'il ne rapporte. La copie peut précéder, la bascule suit l'app.

## 7. Audit
- OpenBao : audit stdout (HMAC), alertes : lecture de `platform/*` par une identité hors `eso-*`/`portal`, usage d'un jeton `root`, `sealed`, rafale d'échecs d'auth, écriture hors `bao-config`.
- Doppler : journal d'activité, relu à chaque rotation [V 2026-11-18 + https://www.doppler.com/pricing : **3 jours** de rétention au plan Developer, 90 jours au plan payant ; relire plus souvent qu'à chaque rotation de 90 jours, ou exporter vers un webhook HTTPS/Slack (fonction listée dans https://docs.doppler.com/llms.txt)]. Authentik : événements (l'export est Enterprise ; collecte via les journaux du pod).
- Rapport hebdomadaire « qui a lu quoi » (comptes par identité et par chemin, pas de valeurs) dans `docs/proofs/` ; `identity-inventory` (CI) échoue si un credential n'a pas de propriétaire et d'échéance.
- Preuve de moindre privilège (tests de politique) : agent reader → 403 sur `kv/data`, déposant → 403 en lecture, cellule A → 403 sur `apps/B/*`.

## 8. Amendements proposés (Paul tranche)
**ADR-0007 : ajouter**
- §6 Cycle de vie humain : `users/<id>.yaml` sans PII, `groups/<nom>.yaml`, ajout REVUE, désactivation AUTONOME, purge et suppression MANDAT, expiration `expires`.
- §7 Identités non humaines : inventaire `identities/agents/`, un client par usage × exécutant, jeton ≤ 15 min, création MANDAT, coupe-circuit documenté.
- §8 Transport : blueprints du dépôt montés dans Authentik par un ConfigMap dédié (une PR kube-ops MANDAT).
- Vérification : test de départ (jeton refusé après `exp`), refus d'un groupe privilégié par un fichier `users/`.

**ADR-0014 : amender**
- §4 : ajouter « secret consommé hors cluster par un exécutant externe (agent, IaC) → Doppler » ; Doppler = **1 projet, ≤ 7 configs, ≤ 8 jetons, un jeton par consommateur × config** ; liste fermée de clés en CI.
- §5 : auth Kubernetes (rôle par cellule en cible), OIDC pour humains, dépôt sans lecture, jetons 15 min / 1 h.
- §6 : **trancher le seal** [V 2026-11-18 + https://openbao.org/docs/configuration/seal/static/ : le bloc `seal "static"` existe (clé de 32 octets AES-256-GCM-96, `current_key`/`previous_key` pour la rotation, valeurs `env://` ou `file://`) ; la doc l'avertit comme recommandé seulement quand une source de confiance existe déjà ; l'init avec un seal automatique renvoie des clés de *récupération*, pas de déscellement, https://openbao.org/docs/concepts/seal/] : seal statique avec clé dans Doppler `seal`, livrée par ESO, Secret lisible par le seul pod (levant le refus de `OPENBAO-DOPPLER-ESO.md` §2) ;
  clés de récupération hors ligne ; OCI KMS écarté tant que l'IMDS est interdit aux pods ; Transit sur homelab écarté (éteint la nuit).
- §7 (nouveau) Migration : copie vérifiée, ombre, bascule par app, nettoyage à liste fermée, invariant « un secret n'existe qu'à un endroit ».

**ADR-0002 §2 :** ajouter `users/`, `groups/`, `identities/`, `platform/secrets/` au noyau et dans `CODEOWNERS` (test T-007).

## 9. Risques et questions ouvertes
- OpenBao sur OKE : dépendance au démarrage des *nouveaux* déploiements ; sauvegarde hors Oracle et restauration à prouver avant toute valeur durable (T-022).
- Seal statique : la clé vit en Doppler *et* dans un Secret du cluster ; atténué par RBAC strict, clés de récupération hors ligne, drill (T-063).
- homelab-infra déconseille OpenBao ; ce document n'en contredit pas la logique si OpenBao reste limité aux secrets internes (primitives et bootstrap restent Doppler).
- Non prouvés : références Doppler, expiration des jetons, `blueprints.configMaps`, back-channel logout, endpoint de génération, PushSecret `IfNotExists` (variante de génération par ESO).

## Sources
`docs/adr/0002,0007,0009,0014`, `docs/IDENTITY.md`, `docs/storage/OPENBAO-DOPPLER-ESO.md`, `docs/research/HOMELAB-INFRA-REQUIREMENTS.md` §5-6, `docs/AGENT-ACCESS.md`,
`docs/AGENT-IDENTITY.md`, `docs/architecture/DECISIONS-OPEN.md` D2, `backlog/T-022,023,024,066,068,074` ; homelab-infra `docs/secrets.md`, `docs/architecture/secret-store-decision.md`,
`agent-identities.md`, `terraform/doppler/main.tf` ; kube-ops `k8s/infrastructure/auth/authentik/extra/blueprints/`, `controllers/*/externalsecret.yaml`.

## Vérifications en ligne du 2026-11-18 (compléments)
- **Auth Kubernetes d'OpenBao** [V 2026-11-18 + https://openbao.org/docs/auth/kubernetes/] : `token_reviewer_jwt` et `kubernetes_ca_cert` ; avec des jetons de pod de courte durée, une section dédiée décrit les compromis ; `disable_iss_validation` à contrôler.
- **Backend PostgreSQL d'OpenBao** [V 2026-11-18 + https://openbao.org/docs/configuration/storage/postgresql/] : « production ready », **haute disponibilité prise en charge depuis OpenBao v2.7.0** (`ha_enabled`, table `openbao_ha_locks`), table `openbao_kv_store` créée automatiquement (`skip_create_table` pour un utilisateur sans droit de création), PostgreSQL ≥ 9.5, **tente SSL par défaut**. L'option « backend PostgreSQL du CNPG plateforme » d'ADR-0014 §3 est donc réaliste ; la dépendance circulaire (OpenBao dépend du CNPG, qui dépend de ses secrets) reste à trancher.
- **Rôles gérés CNPG** [V 2026-11-18 + https://cloudnative-pg.io/docs/1.28/declarative_role_management/] : `spec.managed.roles` réconcilie les attributs *et les mots de passe* ; un `ALTER ROLE` manuel est annulé au cycle suivant ; sans `passwordSecret`, l'opérateur ne touche pas au mot de passe ; `disablePassword` met le mot de passe à NULL (erreur si les deux sont posés). La doc ne mentionne **pas explicitement la restauration** : le réalignement après restauration se déduit de la réconciliation périodique et reste à prouver. En version de développement, un nouveau CRD `DatabaseRole` (https://cloudnative-pg.io/docs/devel/declarative_role_management/) génère le mot de passe dans un Secret et le fait tourner ; il n'est réconcilié que sur changement de sa spec ou de son Secret, et `managed.roles` l'emporte en cas de conflit.
