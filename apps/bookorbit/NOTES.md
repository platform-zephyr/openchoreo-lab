# bookorbit : notes de portage (pas de descripteur)

Statut : **aucun `app.yaml`**. Blocages multiples (RWX, IdP, extensions PostgreSQL, IP privée). Ne pas forcer.

## Source
- kube-ops `origin/main` @ef50472 : `k8s/applications/media/bookorbit/` (app.yaml : PVC `bookorbit-data` 10 Gi, Deployment, Service, HTTPRoute `internal` ; database.yaml : CNPG 18.4 + `Database` avec extensions ; networkpolicy.yaml ; external-secret.yaml). Blueprint Authentik staged : `k8s/optional/bookorbit-authentik-*.staged.yaml`.
- Image `ghcr.io/bookorbit/bookorbit:3.6.0@sha256:bbb5da52…` : **index** contenant linux/arm64 (`3cb7b2d6…`) et linux/amd64. Digest kube-ops valide, à reprendre tel quel.

## Causes de non-portage

1. **Volume `/data` = `media-share` RWX** (2 Ti, homelab, partagé). `rwx-shared` est refusé sur k3d (`local-path`) et sur OKE (pas de FSS). Pas de data plane homelab dans `clusters/`. Extension : admission RWX et volume partagé, côté homelab uniquement.
2. **OIDC Authentik** (`auth.smadja.dev`, blueprint groupe `friends`) : `authentik` non admis (k3d et OKE : `thunderid`). Écart documenté pour OKE.
3. **Extensions PostgreSQL** : `uuid-ossp`, `pg_trgm`, `unaccent`, `vector` (pgvector), créées par un `Database` CNPG en superuser. Le schéma n'a pas `database.extensions[]`. Le rôle applicatif ne peut pas créer `vector` (crash-loop tracé dans kube-ops, PLT-340). Extension requise, et image `lab-pg` avec pgvector à vérifier.
4. **IP privée `10.0.20.192/32`** (hostAliases + egress CIDR vers Authentik interne) : `privateEgressCIDRs` vide sur k3d et OKE. `hostAliases` absent du schéma (E16).
5. **Egress FQDN** `auth.smadja.dev:443` : refus k3d (pas de Cilium).
6. **Sauvegarde** : kube-ops = CNPG R2 + Velero annoté sur `/appdata`. `cnpg` non admis (capabilities : `none`). Déclarer `regenerable` serait faux pour une base de bibliothèque.
7. **Sondes** : `httpGet /api/v1/health` (startup 24 échecs). E10 absent.
8. **Sécurité** : uid 2501, `readOnlyRootFilesystem`, drop ALL, tmp en emptyDir : conforme au profil restricted. Pas d'exception nécessaire.
9. `OIDC_ALLOW_LOCAL_ISSUERS=true` (kube-ops) : permet un issuer local configuré par admin. À garder en revue si le descripteur est écrit.

## Ce qu'il faut pour un descripteur
Dépendance RWX (homelab), IdP Authentik admis (ou identité OKE), extensions `database`, IP privée admise, backup cnpg admis, sondes (E10).
