# romm : notes de portage (pas de descripteur)

Statut : **aucun `app.yaml`**. Plusieurs blocages du schéma et de la politique k3d/OKE. Ne pas forcer.

## Source
- kube-ops `origin/main` @ef50472 : `k8s/applications/games/romm/` (Deployment, 4 PVC, CNPG `romm-postgresql`, CNP, ExternalSecret `romm-runtime`, `romm-postgresql-app`).
- Image `ghcr.io/rommapp/romm:5.2.0` : tag seul en kube-ops. Index `3512f2ca…` (linux/amd64 `6a2a16f7…`, linux/arm64 `61299d6a…`), vérifié **[C]** par `imagetools`. Digest d'index à épingler si le descripteur est écrit plus tard.

## ALERTE sécurité (image upstream)
La config de l'image `5.2.0` embarque des variables d'environnement d'identifiants tiers (clés `SCREENSCRAPER_DEV_*`). Valeurs non reproduites ici. Avant tout usage : les surcharger à vide dans le runtime, ou vérifier l'image. Signalement à Paul.

## Causes de non-portage

1. **OIDC Authentik** (`OIDC_PROVIDER=authentik`, issuer `auth.smadja.dev`, groupes `authentik-admins` et `family`) : `authentik` absent de `capabilities.identityProviders` (k3d et OKE : `thunderid` seul). Authentik non admis sur OKE : **écart documenté**. Extension requise : admission PR plateforme + `allowedGroups` (l'image n'accepte qu'un groupe littéral par rôle, voir commentaire kube-ops).
2. **Egress FQDN** `hasheous.org`, `*.hasheous.org`, `*.igdb.com` : refusé sur k3d (pas de Cilium). Sur OKE, nécessite le gate Cilium. `public-internet` interdit (plus large que kube-ops).
3. **Capacités ajoutées** `CHOWN`, `SETGID`, `SETUID` (kube-ops) : `drop ALL` puis `add` est refusé en PSA `restricted`. Aucune règle `securityExceptions` ne couvre `add capabilities`. Extension E12 requise (règle `add-capabilities`, expirable).
4. **uid** : kube-ops ne fixe pas de `runAsUser`, et ajoute des capacités de changement d'uid. Probable entrypoint root qui abaisse ses privilèges **[S]** (User de l'image non lu). Si uid 0 confirmé : `securityExceptions: run-as-root`, `expires` ≤ 90 jours (ex. `2027-02-15` max), `approver: user:default/paul`, `reason` ≥ 20 caractères.
5. **Stockage** : 4 volumes (library 100 Gi bulk, assets 20 Gi, resources 20 Gi, redis-data 2 Gi). La forme liste E8 les exprime, mais 100 Gi sur OKE `oci-bv` est un coût à arbitrer, et le lab n'a pas de classe `bulk`.
6. **Base** : CNPG `romm-postgresql` (17.7) avec WAL R2 (barman). `lab-pg` est éphémère et sans sauvegarde. `backup.mechanism: cnpg` non admis (capabilities : `none`). `irreplaceable` est refusé. Écart : pas de sauvegarde R2 du contenu.
7. **Ressources** : kube-ops 50m/1Gi requests, 2 CPU/4 Gi limites. Le schéma offre `small` et `medium` seulement (E11 absent).
8. **Sondes** : `tcpSocket` (startup 60 échecs). E10 absent.
9. **Ingress** : `ext` et `int` en kube-ops. Décision d'exposition à prendre (défaut privé).

## Ce qu'il faut pour un descripteur
Identité Authentik admise, FQDN (Cilium ou labo `--allow-unenforced-fqdn`), extension `add-capabilities`, décision uid, sauvegarde cnpg admise, `size` large (E11), sondes (E10).
