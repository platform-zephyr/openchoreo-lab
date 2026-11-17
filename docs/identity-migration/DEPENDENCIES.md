# Authentik : dépendances, connectivité et ordre de démarrage

**Statut : ÉTUDE, rien n'est appliqué.** 2026-11-17. Notation des sources : voir [AUTHENTIK-MIGRATION.md](AUTHENTIK-MIGRATION.md).

## 0. Conclusion

- Authentik doit pouvoir démarrer **sans Argo, sans OpenChoreo, sans Cloudflare Access ni OpenBao**. Ordre : stockage → CNPG → ESO et jeton Doppler → Secrets → PostgreSQL → Authentik → tunnel et DNS → Argo → OpenChoreo.
- Côté homelab, **7 politiques et 3 fichiers** visent encore Authentik en local sur `origin/main` le 17/11. Le plan citait « 10 `hostAliases` et 17 politiques » [HI:docs/architecture/oke-migration-plan.md:9]. **Recompter avant M10** (T-P6), puis les corriger **avant** la bascule. Sinon : split-brain ou panne.
- L'outpost proxy géré (`Local Kubernetes Cluster`) doit devenir un outpost manuel sur le homelab avant la bascule.

## 1. Consommateurs (qui dépend d'Authentik)

| Consommateur | Où | Mécanisme | Sensibilité à la bascule | Action |
|---|---|---|---|---|
| Argo CD homelab | `issuer: …/application/o/argocd/` [KO:k8s/infrastructure/controllers/argocd/values.yaml:85] | OIDC | nulle si l'issuer et le `kid` sont identiques | vérifier le login ; secours : admin local |
| Grafana homelab | `auth_url`/`token_url`/`api_url` globaux [KO:k8s/infrastructure/monitoring/prometheus-stack/values.yaml:83-91] | OAuth générique | nulle | vérifier le login |
| apiserver Talos (kubectl OIDC, cellules blue/green) | blueprints `apps-kubernetes.yaml`, `apps-talos-bluegreen.yaml` (clé partagée) | l'apiserver lit discovery et JWKS **depuis le nœud** (DNS du LAN) | **élevée** si le DNS split renvoie encore `auth` vers `10.0.20.192` | retirer l'entrée split ; secours : kubeconfig Talos hors OIDC |
| Cloudflare Access (IdP `apps-cloudflare`, `per_provider`) | [KO:…/blueprints/apps-cloudflare.yaml:31] | Cloudflare appelle Authentik depuis Internet | nulle | vérifier une application protégée |
| OpenChoreo (API, Backstage, agents) sur OKE | [OCL:platform/identity/openchoreo-oidc-values.yaml:16-21] | JWKS et token par FQDN public [OCL:platform/identity/network-policy-api-idp.yaml:26-29] | nulle ; c'est même le gain (identité disponible la nuit) | T-A1…T-N3 de [OCL:docs/IDENTITY.md:115-138] |
| Apps OIDC homelab (Immich, Mealie, Vikunja, RoMM, Karakeep, Pinepods, Paperless, Invoice Ninja, Matrix MAS, RustiCal, SparkyFitness, BookOrbit, Polyfin, AIOStreams, Home Assistant…) | `git grep auth.smadja.dev` [KO:k8s/applications/**] | OIDC par l'URL publique, **sauf** celles qui ont des `hostAliases` ou un egress limité au LAN | voir §2 | — |
| Proxy outpost (`frigate`) | `Local Kubernetes Cluster` [KO:…/blueprints/outposts.yaml:19-44], [KO:…/blueprints/outposts-v2.yaml:13-39] | Authentik **crée** l'outpost dans son propre cluster | **élevée** : sur OKE, l'outpost serait créé sur OKE, sans route vers le LAN (D-2026-11-11-17 [HI:docs/decisions.md:245]) | outpost manuel sur le homelab (sortie vers `auth.smadja.dev`), avant la bascule (M10) |
| SMTP (Migadu) | `authentik-smtp-credentials` [KO:…/values.yaml:89] | sortie 465 (`use_ssl`) | autoriser l'egress depuis OKE | test d'envoi (récupération de mot de passe) |
| Familles (Maureen…) | — | navigateur | coupure pendant la fenêtre | preuve USER [HI:docs/decisions.md:599] |

## 2. Références réseau locales au homelab (relevé Git `origin/main`, 17/11)

| Fichier | Nature | Après la bascule |
|---|---|---|
| `k8s/applications/media/polyfin/deployment.yaml:26` | `hostAliases` `auth.smadja.dev → 10.0.20.192` | à retirer |
| `k8s/applications/media/bookorbit/app.yaml:44-46` | `hostAliases` | à retirer |
| `k8s/applications/media/kustomization.yaml:25-36` | patch qui ajoute `auth.smadja.dev` aux `hostAliases` | à retirer |
| `k8s/applications/media/{aiostreams,polyfin}/networkpolicy.yaml:59`, `bookorbit/networkpolicy.yaml:32` | egress `10.0.20.192/32` | egress FQDN `auth.smadja.dev:443` (ou `world:443`) |
| `k8s/applications/platform/matrix/networkpolicy.yaml:160` | idem | idem (Matrix protégé : analyse avant) |
| `k8s/infrastructure/monitoring/blackbox/networkpolicy.yaml:35` | idem | idem ; sonde à pointer sur l'URL publique |
| `k8s/optional/{rustical,personal-ai-2026/librechat}/networkpolicy.yaml` | idem | idem |
| `httproute.yaml` (parents `internal` + `external`) [KO:k8s/infrastructure/auth/authentik/httproute.yaml:7-11] | alimente le DNS split (ExternalDNS privé, UniFi) [KO:k8s/infrastructure/network/externaldns-private/README.md:106-109] | retirer `auth` du split **avant** la bascule (sinon le LAN résout encore le homelab) |
| `k8s/clusters/oracle-a1/media/kustomization.yaml:1-33` | retire déjà les `hostAliases` sur OKE | modèle à réutiliser |

Ordre (M10, sans prérequis OKE [HI:docs/architecture/oke-migration-plan.md:63]) : faire passer tous les consommateurs par l'URL publique **pendant qu'Authentik est encore au homelab**. C'est réversible, et prouvable avant la bascule : connexions OK via Cloudflare.

## 3. Dépendances circulaires à éviter

| Cycle potentiel | Pourquoi c'est un cycle | Coupure retenue |
|---|---|---|
| Authentik ← Argo (OIDC) ← Authentik | Argo se connecte via Authentik ; si Argo devait déployer Authentik… | bootstrap manuel d'Authentik (`kustomize build --enable-helm \| kubectl apply --server-side`) ; Argo l'adopte ensuite ; admin local d'Argo comme secours |
| Authentik ← OpenChoreo (CP, ReleaseBinding) | OpenChoreo s'authentifie via Authentik | Authentik **n'est pas** un Component OpenChoreo ; namespace `auth`, hors `openchoreo-*`/`lab-*` |
| Authentik ← Cloudflare Access ← Authentik | Access utilise Authentik comme IdP | pas d'Access devant `auth.smadja.dev` [HI:docs/architecture/oke-target-architecture.md:119] |
| Authentik ← OpenBao ← Authentik | OpenBao (futur) pourrait utiliser l'OIDC Authentik ; Authentik lirait ses secrets dans OpenBao | secrets d'Authentik dans **Doppler** seulement [OCL:docs/storage/OPENBAO-DOPPLER-ESO.md:5-12] |
| Authentik ← ESO ← pile du labo | `helm uninstall` de la pile supprime des CRD [OCL:STATE.md:48] ; ExternalSecrets `creationPolicy: Owner` [KO:k8s/infrastructure/auth/authentik/extra/secrets.yml:15] : le Secret `AUTHENTIK_SECRET_KEY` disparaîtrait | ESO, CNPG et cert-manager d'Authentik appartiennent à la couche plateforme kube-ops ; le labo les **réutilise** sans les posséder ; garde dans `tools/oke/uninstall.sh` (à ajouter par le coordinateur) |
| Accès admin ← NetBird ← Authentik ? | l'administration d'Authentik passe par NetBird (D-2026-11-11-17) ; si le login NetBird passe par Authentik… | à vérifier (T-P14) ; secours : Bastion OCI [HI:docs/architecture/oke-migration-plan.md:36] |
| Authentik ← CNPG plugin barman ← cert-manager | le plugin exige cert-manager [KO:docs/operations/pg-shared-oke-backup-drill.md:34] | cert-manager dans l'étape 2 du bootstrap |

## 4. Ordre de démarrage (restauration ou bootstrap à froid)

| # | Brique | Dépend de | Geste | Preuve de sortie |
|---|---|---|---|---|
| 0 | Cluster OKE + Cilium + baseline | OpenTofu (ARC), Bastion | existant (PASS 17/11) | `acceptance.sh` PASS |
| 1 | Stockage : `oci-bv` (+ classe `Retain` pour `auth`) | 0 | natif ; classe `Retain` = PR cluster-wide | StorageClass présente |
| 2 | cert-manager, opérateur CNPG, plugin barman | 0 | `kustomize build \| kubectl apply` (kube-ops `oracle-a1/*`) | Deployments Ready |
| 3 | ESO + jeton Doppler (`auth`) | 0 | **Paul** pose le Secret du jeton (seul geste humain) | `ClusterSecretStore`/`SecretStore` Ready |
| 4 | ExternalSecrets `auth` (R2 RO et RW, core, blueprints, SMTP) | 3 | apply | Secrets présents (noms seulement) |
| 5 | CNPG `authentik-db` (réplica ou recovery depuis R2) | 1, 2, 4 | apply | `Ready` ; puis promotion (RUNBOOK) |
| 6 | Authentik (server, worker, ConfigMap des blueprints) | 4, 5 | `kustomize build --enable-helm` | `/-/health/ready/` 200 via port-forward |
| 7 | cloudflared + règle du tunnel `auth` | 3 (token), 6 | Terraform `cloudflare` (ARC), un apply à la fois [HI:docs/decisions.md:623] | discovery 200 publique (après le DNS) |
| 8 | Argo CD (adopte 1 à 7 sans re-créer) | 6 pour l'OIDC ; admin local sinon | bootstrap Paul | Applications Synced **sans** diff destructif |
| 9 | OpenChoreo CP et DP, portail | 6, 7 | pilote | T-A1… [OCL:docs/IDENTITY.md:115] |

Au redémarrage du nœud, ou si Argo est cassé, les étapes 1 à 7 restent en place (objets Kubernetes ordinaires) : Authentik ne dépend d'Argo que pour la **réconciliation**, pas pour **fonctionner**.

## 5. Matrice de connectivité (cible)

| Source | Vers Authentik | Chemin | Autorisation réseau |
|---|---|---|---|
| Internet (navigateurs, Cloudflare Access) | `https://auth.smadja.dev` | Cloudflare → tunnel `oracle-a1` → Service `authentik-server:80` | CNP `auth` : ingress depuis `cloudflared` seulement |
| CP OpenChoreo (OKE) | idem | sortie NAT → Cloudflare → tunnel → OKE | `toFQDNs auth.smadja.dev:443` [OCL:platform/identity/network-policy-api-idp.yaml:26] |
| DP OKE (apps) | idem | idem | egress FQDN (contrat E2 [OCL:docs/IDENTITY.md:112]) |
| DP Talos / homelab (apps, Argo, Grafana, apiserver) | idem | Internet → Cloudflare → tunnel OKE | egress FQDN ou `world:443` ; **plus de `10.0.20.192`** |
| Outpost manuel homelab | idem (websocket sortant) | idem | egress 443 |
| Authentik → PostgreSQL | `authentik-db-rw:5432` | intra-namespace | CNP |
| Authentik → SMTP, R2 (sidecar barman) | sortie | NAT | egress FQDN |
| Admin (`/if/admin/`) | NetBird ou port-forward Bastion | privé | — |
