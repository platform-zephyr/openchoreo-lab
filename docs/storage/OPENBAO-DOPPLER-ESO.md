# Secrets : Doppler, OpenBao, ESO, Authentik — direction et prérequis

Statut : **PROPOSÉ**, rien n'est déployé. OpenBao **n'est pas installé** par ce flux. Date : 2026-11-17.

## 1. Direction (rôle de chaque brique)

| Brique | Rôle | Exemples | N'est pas |
|---|---|---|---|
| **Doppler** | secrets **externes** et de **bootstrap** : ce qui vient d'un tiers ou doit exister avant le cluster | jetons Cloudflare, R2, clés API tierces, `RESTIC_BACKUP_PASSWORD` (D-2026-11-15-10), jeton ESO | un générateur de mots de passe internes |
| **OpenBao** (futur) | secrets **internes générés** et dynamiques, propres au cluster | mots de passe de bases, clés de chiffrement d'app, PKI interne | un prérequis du golden path |
| **ESO** | **distribution** : un seul chemin vers les `Secret` Kubernetes, quel que soit le magasin | `ClusterSecretStore` `doppler-cluster`/`lab-store` ; générateurs `Password` | un magasin |
| **Authentik** | **identités** humaines et machines (OIDC, client_credentials) | `openchoreo-agent-reader`, clients OAuth des apps | un magasin de secrets |

**Écart avec un document existant, à arbitrer par Paul** : homelab-infra `docs/architecture/secret-store-decision.md` (PROPOSÉ, 15/11) recommande de **ne pas** migrer vers OpenBao et de garder Doppler, notamment parce qu'« il n'existe pas d'hébergement sain pour OpenBao ici » (OKE mono-nœud sans SLA, homelab éteint la nuit). La direction ci-dessus ne le contredit pas tant qu'OpenBao reste limité aux secrets internes générés et n'est déployé qu'après les prérequis du §2 ; elle le contredirait si elle déplaçait les secrets externes ou le bootstrap hors de Doppler. L'invariant `INV-REC-01` (la reconstruction de Kubernetes ou d'OpenBao ne dépend pas d'eux seuls) s'applique.

## 2. Prérequis avant tout OpenBao durable

| Prérequis | Exigence | État |
|---|---|---|
| Stockage | Raft intégré sur un PVC du profil `database`-équivalent (`fast-rwo`, taille appliquée, `Retain`) | **impossible sur OKE aujourd'hui** (aucun volume autorisé, `STORAGE-RECOMMENDATION.md` §1) ; sur Talos après migration LVM |
| Déverrouillage | auto-unseal par KMS hors du cluster (OCI KMS, ou Transit d'une autre instance) ; **pas** de clés de déscellement dans un Secret du même cluster | à décider |
| Clés de récupération | hors ligne, chez Paul (même procédure papier que restic, D-2026-11-15-10) | à faire |
| Sauvegarde | snapshot Raft périodique vers R2, chiffré, hors Oracle | à construire |
| Restauration | exercice réel : nouveau cluster jetable, restauration du snapshot, déscellement, lecture d'un secret témoin | **obligatoire avant toute donnée durable** (même règle que D-2026-11-14-03) |
| Supervision | alerte « sealed » et âge du dernier snapshot, hors du cluster surveillé (ntfy.sh) | à faire |

### Risques du déscellement sur un seul nœud

- **Redémarrage = indisponibilité** : chaque redémarrage du pod ou du nœud rescelle OpenBao. Sans auto-unseal, tous les consommateurs échouent jusqu'à une action humaine (souvent la nuit).
- **Auto-unseal par KMS du même fournisseur** (OCI KMS sur OKE) : une suspension du compte Oracle bloque à la fois le cluster, le stockage et la clé de descellement. C'est le risque déjà relevé (« secrets et states dans le même compte Oracle »).
- **Clés de descellement dans le cluster** (Secret, init container) : annule la protection du scellement ; refusé.
- **Perte du PVC** (nœud remplacé, disque de démarrage) : sans snapshot hors site, tous les secrets générés sont perdus, donc toutes les bases qui en dépendent deviennent inaccessibles. D'où l'ordre : stockage durable, puis sauvegarde, puis restauration prouvée, puis seulement OpenBao.
- **Dépendance circulaire** : OpenBao ne doit pas dépendre d'un secret qu'il fournit lui-même (bootstrap par Doppler).

## 3. Golden paths : aucun ne dépend d'OpenBao

| Golden path | Secrets | Dépend de |
|---|---|---|
| 1 — `whoami` | aucun | rien |
| 2 — **Miniflux + PostgreSQL**, mot de passe généré **sans préconfiguration Doppler** | mot de passe de la base généré dans le cluster | CNPG (`lab-pg`, profil `database`) + ESO générateur `Password` |

Mécanisme du golden path 2, sans OpenBao ni clé Doppler créée à la main :
- ESO `Password` generator référencé par un `ExternalSecret` (`dataFrom.sourceRef.generatorRef`) avec `refreshPolicy: CreatedOnce` (ou `refreshInterval: 0`) : le `Secret` est créé une fois et jamais régénéré [P : doc ESO ExternalSecret, « syncs the Kind=Secret once … and then stops »]. Sans cette option, le mode par défaut `Periodic` régénérerait le mot de passe à chaque intervalle et casserait la connexion à la base.
- Alternative : laisser CNPG générer le secret applicatif de l'`initdb` [NV : comportement à relire dans la doc CNPG actuelle, la page a déménagé].
- Limite assumée : le mot de passe vit seulement dans le cluster. Perdre le cluster sans sauvegarde du `Secret` = régénérer et réappliquer à la base restaurée. Acceptable pour `backup.class: regenerable` ; pour `irreplaceable`, le secret doit suivre la base dans la même sauvegarde (Velero du namespace) ou passer par un magasin externe.
- Écart avec APP-CONTRACT §2.2 actuel (clé Doppler `MINIFLUX_PG_PASSWORD` « créée une fois, hors Git ») : ce golden path la remplacerait ; modification de l'APP-CONTRACT = PR plateforme séparée.
