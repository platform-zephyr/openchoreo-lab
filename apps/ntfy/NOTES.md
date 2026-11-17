# ntfy : notes de portage

Statut : `app.yaml` valide (`appgen validate` OK, 2026-11-17). Pas de `render`, rien dans `generated/`. Cluster : k3d uniquement. OKE interdit tant que le gate Cilium n'est pas franchi.

## Sources et preuves
- kube-ops `origin/main` @ef50472 : `k8s/applications/catalog/ntfy/` (Deployment, PVC `ntfy-data` 1 Gi longhorn-fast, initContainer `bootstrap-admin`, HTTPRoute external + internal, CNP).
- Image : tag `v2.28.0` dans kube-ops, sans digest. Index `6ef4b819…` (linux/amd64, linux/arm64, arm/v6, arm/v7), vérifié par `docker buildx imagetools inspect`. Digest d'index épinglé dans `app.yaml`.
- Sonde : `/v1/health` (kube-ops readiness et liveness). Le schéma n'a pas de sondes distinctes (E10), seul `healthPath` est porté.

## Écarts avec kube-ops (équivalence de sécurité)

| # | kube-ops | Lab (`app.yaml`) | Effet | Action |
|---|---|---|---|---|
| 1 | initContainer `bootstrap-admin` : lance `ntfy serve`, crée l'utilisateur admin | Pas d'initContainer (E14 absent). Admin fourni par `NTFY_AUTH_USERS` (secret, ligne `admin:<hash bcrypt>:admin`) | Même effet attendu : un admin, `deny-all` par défaut | **[S]** à prouver en Phase 0 (variable d'env `NTFY_AUTH_USERS` supportée par ntfy 2.28). Le hash est généré hors Git, dans le store. Jamais de valeur dans le dépôt. |
| 2 | Route Alertmanager : ingress depuis `monitoring/alertmanager` sur 8080 | Absente. Schéma sans `network.ingress` (E4). Ingress limité à la passerelle (default-deny) | **Perte** : Alertmanager ne peut plus publier vers ntfy | Extension E4 `network.ingress[]` (`fromEndpoints` nommé). Jusque-là, alertes ntfy non couvertes. |
| 3 | Route `external` + `internal` | `exposure: public`, `auth: app-password` | Exposition publique : identique à kube-ops (clients mobiles) | Choix explicite. La règle « privé par défaut » est écartée ici pour l'équivalence. **Décision de Paul** à confirmer. |
| 4 | Requests 10m/32Mi, limits 250m/192Mi | `size: small` = 50m/128Mi, 250m/256Mi | Plus de marge mémoire | Accepté. |
| 5 | Pas de label de sauvegarde Velero | `backup.class: regenerable` | Le cache se reconstruit. `auth.db` (utilisateurs et jetons créés) ne l'est pas complètement : seul l'admin est reconstruit depuis le secret | **Décision** : `regenerable` est une déclaration partielle. Un PVC perdu fait perdre les jetons utilisateurs. |
| 6 | `Prune=false` sur le PVC | Non exprimable | Argo gère le PVC dans le rendu | Cohérent avec `docs/APP-CONTRACT.md` §5. |
| 7 | Egress : aucun explicite (CNP ingress only) | `network.egress: none` | Équivalent | — |

## Secrets
- Une seule clé : `NTFY_AUTH_USERS` (préfixe `NTFY_` vérifié par la CI). Le secret kube-ops `APP_NTFY_ADMIN_PASSWORD` (mot de passe en clair) ne doit pas être réutilisé tel quel : il faut le transformer en hash bcrypt, hors dépôt.

## Pour passer en PR / OKE
1. Phase 0 k3d : vérifier `NTFY_AUTH_USERS` (login admin, refus anonyme avec `deny-all`).
2. Décider de l'exposition publique (écart 3) et de la rétention (écart 5).
3. Extension E4 pour Alertmanager (écart 2).
4. OKE : refusé avant le gate Cilium (`cluster: oke`), et pas d'egress FQDN ici.
