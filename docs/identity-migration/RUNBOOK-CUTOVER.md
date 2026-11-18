# Runbook : bascule d'Authentik homelab → OKE (`auth.smadja.dev`)

**Statut : PRÉPARÉ, jamais exécuté. Ne rien lancer sans les accords listés en P0.** 2026-11-17. Source du chemin : D-2026-11-15-11 [HI:docs/decisions.md:587-588], D-2026-11-15-14 [HI:docs/decisions.md:619-631], plan §5 [HI:docs/architecture/oke-migration-plan.md:42-47]. Notation des sources : voir [AUTHENTIK-MIGRATION.md](AUTHENTIK-MIGRATION.md).

## 0. Conclusion

- Méthode : **réplica CNPG depuis R2 → arrêt de l'écriture au homelab → rejeu jusqu'au LSN final → promotion → CNAME `auth` vers le tunnel `oracle-a1`**. Même version 2026.8.3, même `SECRET_KEY`, même clé de signature.
- Fenêtre de coupure du login : **20 à 40 min** [E]. Retour arrière : environ 10 min [E]. Après le retour, les écritures faites sur OKE sont perdues (liste en §R).
- Les prérequis bloquants sont en P0. La règle la plus importante : **le homelab est arrêté par Git** (réplicas à 0 dans kube-ops), jamais par un `kubectl scale` qu'Argo annulerait.

## P0. Go/no-go avant de réserver une fenêtre (tous requis)

| # | Critère | Preuve |
|---|---|---|
| G1 | Emplacement de stockage attribué à `authentik-db` (option S1 ou S2, accord de Paul) | décision écrite ; quota ≤ 200 Go |
| G2 | Capacité : requests au repos < 70 %, IP de pods ≤ 31 avec la marge du préflight | `verify.sh` (méthode du MAX) |
| G3 | Drill de restauration hors Oracle PASS, sens (a) **et** (b) (P2), RTO ≤ 30 min, RPO mesuré | empreintes égales, horodatages |
| G4 | M10 fait : homelab passé par l'URL publique, aucun `hostAliases` ni egress `192.0.2.192` pour `auth`, `auth` retiré du DNS split, outpost manuel en service | DEPENDENCIES §2 vide ; logins OK via Cloudflare |
| G5 | Accès de secours testés **le jour même** : kubeconfig Talos hors OIDC, admin local d'Argo, Bastion OKE, admin Authentik par NetBird ou port-forward | une commande lue par accès |
| G6 | Gel des changements Authentik (PLT-312, PLT-316) depuis la répétition | aucun merge sous `k8s/infrastructure/auth/` |
| G7 | Aucun autre apply ni bascule en cours (états `cloudflare`, `netbird`, `doppler`) [HI:docs/decisions.md:623-626] | file ARC vide |
| G8 | Plan de retour arrière relu (§R) ; la PR de retour est **préparée** | lien vers la PR de revert |
| G9 | Base backup R2 de moins de 24 h + WAL archivés en continu (`ContinuousArchiving=True`) | `Backup` à la demande Completed |
| G10 | Inventaire des `kid` et des discoveries publié (T-P3) | fichier daté |

No-go automatique : l'un de ces critères manque, le nœud OKE passe au-dessus de 85 % pendant la répétition, un déploiement du pilote est en cours, ou les familles utilisent le service à ce moment-là.

## P1. Préparation sans coupure (jours précédents)

1. Préparer les PR, **sans les merger** : overlay kube-ops `k8s/clusters/oracle-a1/auth/` (chart 2026.8.3 + valeurs du homelab ; requests server ≥ 640 Mi ; Redis retiré si T-P1/doc le permettent ; `outposts` sans service connection locale) ; `Cluster` CNPG en **réplica** (`replica.enabled: true`, source `authentik-r2-store` en lecture seule, `storage` 50 Go, pas de `walStorage`, plugin écrivain vers un **nouveau** préfixe `oracle-a1/authentik/`).
2. Terraform `cloudflare` (ARC) : règle d'entrée `auth.smadja.dev` dans le tunnel `oracle-a1` **sans** toucher au DNS. Inoffensif tant que le CNAME vise le homelab.
3. Kube-ops homelab : PR « `authentik` replicas 0 + CNPG homelab en lecture seule (aucune suppression) » préparée, non mergée.

## P2. Répétition et drill hors Oracle (sans DNS)

| Étape | Action | Mesure |
|---|---|---|
| R1 | Sur OKE, namespace `auth-rehearsal` : `Cluster` en **recovery** depuis `authentik-r2-store` (identité RO). Le cluster est jetable et indépendant. | T0 → `Ready` = RTO (a) |
| R2 | Authentik 2026.8.3 contre cette base (même `SECRET_KEY`), sans route publique | démarrage, migrations nulles |
| R3 | Via port-forward avec `Host: auth.smadja.dev` et `X-Forwarded-Proto: https` : discovery des providers, JWKS | `issuer` et `kid` égaux à T-P3 |
| R4 | Login de `e2e-user` (QA [KO:…/blueprints/qa-e2e-user.yaml]) ; `client_credentials` d'un client de test | jeton RS256, `iss`, `kid` attendus |
| R5 | Empreintes SQL (utilisateurs, groupes, providers, MFA, `kid`) : source homelab comparée à la restauration | égalité |
| R6 | **Sens (b)** : le cluster R1 promu écrit dans `oracle-a1/authentik-rehearsal/` ; insertion d'un marqueur ; attente de l'archivage ; restauration **sur le homelab** (modèle `offsite-restore` [KO:docs/operations/pg-shared-oke-backup-drill.md:47-48]) | marqueur présent = RPO ; `Ready` = RTO (b) |
| R7 | Retraits : `auth-rehearsal` (PVC en `Delete` : quota libéré), cluster de restauration au homelab | quota revenu à 150 Go |

Capacité : R1 et R2 coûtent environ 450m et 1,2 Gi de plus. Arrêter le portail et les apps du DP pendant la répétition, ou mesurer d'abord (AUTHENTIK-MIGRATION §10.1). Stockage : R1 occupe l'emplacement qui servira ensuite au cluster final. On les crée l'un après l'autre, jamais ensemble.

## P3. Réplica final (J-1 à H-1, sans coupure)

1. Merger l'overlay OKE (P1.1) : `authentik-db` en réplica, Authentik à **0 réplica**. Le rejeu des WAL du homelab est continu.
2. Vérifier : réplica `Ready`, retard de rejeu < 15 min, aucune écriture vers `authentik/` depuis OKE.

## P4. Fenêtre de bascule (chronométrée)

| t (min) [E] | Étape | Critère pour continuer |
|---|---|---|
| 0 | Annonce ; gel ; capture des métriques | G1-G10 verts |
| 0-2 | Merger la PR homelab « replicas 0 » ; Argo synchronise | aucun pod `authentik-server/worker` au homelab |
| 2-4 | Au homelab : `CHECKPOINT; SELECT pg_switch_wal();` puis relever `pg_current_wal_lsn()` = **LSN final** ; attendre que ce segment soit archivé dans R2 | objet WAL présent |
| 4-10 | Sur OKE : attendre `pg_last_wal_replay_lsn() ≥ LSN final` | égalité |
| 10-12 | Promotion (`replica.enabled: false`, par PR ou patch documenté) ; l'archivage passe au préfixe `oracle-a1/authentik/` | `Ready`, primaire, `ContinuousArchiving=True` |
| 12-17 | Authentik OKE à 1 réplica (server et worker) | `/-/health/ready/` 200 ; blueprints appliqués sans erreur |
| 17-25 | Terraform `cloudflare` : `content` de `auth` → tunnel `oracle-a1` (apply ARC) | discovery publique 200 servie par OKE (en-tête ou journal cloudflared OKE) |
| 25-40 | Vérifications V1-V12 | toutes PASS, sinon §R |

## P5. Vérifications après la bascule

| # | Vérification | Attendu |
|---|---|---|
| V1 | `GET /application/o/<slug>/.well-known/openid-configuration` pour chaque slug de T-P3 | `issuer` et endpoints identiques |
| V2 | `GET …/jwks/` | même `kid` que T-P3 |
| V3 | Login réel de Paul (MFA) et de `e2e-user` | réussi ; pas de ré-enrôlement MFA |
| V4 | Session existante d'avant la bascule (navigateur déjà connecté) | toujours connecté (même `SECRET_KEY`, sessions en base) |
| V5 | `client_credentials` (`openchoreo-agent-reader` si créé, sinon client de QA) | JWT RS256, `exp-iat` attendu |
| V6 | Groupes : jeton d'un membre de `family` et d'un membre de `authentik-admins` | claims `groups` filtrés comme avant |
| V7 | Outpost manuel (frigate) | connecté (UI Outposts : « healthy ») ; accès proxy OK |
| V8 | Argo homelab : login SSO | OK |
| V9 | apiserver Talos : `kubectl` OIDC | OK (sinon kubeconfig de secours) |
| V10 | Grafana : login OAuth | OK |
| V11 | Cloudflare Access : application protégée | login via l'IdP `apps-cloudflare` OK |
| V12 | Égalité d'empreintes SQL avant et après ; `Backup` à la demande OKE Completed dans `oracle-a1/authentik/` | égalité ; objet présent |
| V13 | J+1 (preuve USER) : Maureen se connecte | OK [HI:docs/decisions.md:599] |
| V14 | Nuit suivante, homelab éteint : login et `client_credentials` | OK : c'est l'objectif |

## §R. Retour arrière

**Déclencheurs** : V1, V2 ou V3 en échec ; une erreur 5xx persistante plus de 5 min ; une divergence d'empreinte ; le nœud OKE saturé.

| Étape | Action | Durée [E] |
|---|---|---|
| R-1 | Terraform `cloudflare` : remettre `content` de `auth` vers le tunnel homelab (ou supprimer l'enregistrement : le joker revient au homelab [HI:terraform/cloudflare/modules/tunnel/main.tf:116-117]) | 5-8 min (ARC) |
| R-2 | Revert de la PR « replicas 0 » au homelab ; Argo relance Authentik **sur la base homelab intacte** | 2-4 min |
| R-3 | Authentik OKE à 0 réplica (aucune suppression de cluster ni de PVC) | 1 min |
| R-4 | V1-V3 sur le homelab | 3 min |

**Écritures perdues au retour** (tout ce qui a été écrit sur OKE après la promotion) : nouveaux comptes et invitations acceptées ; changements de mot de passe ; MFA enrôlée ou retirée ; consentements ; refresh tokens et jetons d'API émis (les RP devront refaire un login) ; secrets générés par des blueprints appliqués après la promotion (d'où le gel G6) ; journal d'événements. **Pas de réconciliation automatique** : on relève la liste (requête sur `authentik_events_event` d'OKE depuis la promotion) avant de couper OKE.

**Interdit pendant le retour arrière** : relancer le homelab sans couper OKE (split-brain), faire écrire OKE dans le préfixe `authentik/` du homelab, supprimer quoi que ce soit.

## J+14 (hors de ce runbook)

Le homelab reste arrêté mais intact deux semaines [HI:docs/decisions.md:251]. Le retrait (suppression du `Cluster` homelab, des PVC Longhorn, de l'archive `authentik/`) est **destructif** : décision de Paul [HI:docs/decisions.md:629].
