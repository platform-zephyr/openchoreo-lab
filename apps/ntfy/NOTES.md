# ntfy : notes de portage (golden path n°2, OKE stateless)

Statut : `app.yaml` en `cluster: oke`, `profile: stateless`, rendu par `appgen` (`generated/namespaces/default/projects/ntfy`). Preuve runtime sur OKE : **NOT_TESTED** tant que la PR n'est pas mergée et synchronisée par `lab-o-ntfy` (ApplicationSet `lab-o`). Aucune route publique, aucun PVC, aucun secret, aucune credential réelle.

## Sources et preuves
- kube-ops `origin/main` @ef50472 : `k8s/applications/catalog/ntfy/` (Deployment, PVC `ntfy-data` 1 Gi longhorn-fast, initContainer `bootstrap-admin`, HTTPRoute external + internal, CNP). Référence seulement : rien n'est repris tel quel.
- Image : `docker.io/binwiederhier/ntfy:v2.28.0@sha256:6ef4b819…` (index multi-arch). Vérifié le 2026-11-18 par HEAD sur le registre : HTTP 200, `docker-content-digest` identique.
- Sonde : `/v1/health` (readiness et liveness, `healthPath`).

## Choix pour OKE (stateless strict)
- Pas de PVC, pas de `storage`, pas de `database`. Le cache et l'auth restent EN MÉMOIRE : `NTFY_CACHE_FILE` et `NTFY_AUTH_FILE` ne sont pas posés [S] : à confirmer au premier démarrage (la doc amont décrit un cache mémoire quand le fichier n'est pas défini).
- Aucun chemin inscriptible requis : `readOnlyRootFilesystem` tient sans `emptyDir`. [S] à prouver par le pod Ready sur OKE.
- Conséquence : les messages en cache et les abonnements sont perdus à chaque redémarrage. Accepté pour un service de test.

## Écarts avec kube-ops (à trancher avant tout usage réel)

| # | kube-ops | Lab (`app.yaml`) | Effet | Action |
|---|---|---|---|---|
| 1 | initContainer `bootstrap-admin`, auth `deny-all` | Pas d'auth (`exposure.auth: none`, pas d'`auth.db`) | **Accès ouvert à l'intérieur de la cellule** (pas de route externe, `network.egress: none`) | Acceptable pour un test interne. Avant tout usage réel : ajouter une authentification (secret ESO, hors Git). |
| 2 | Route Alertmanager sur 8080 | Absente (schéma sans `network.ingress`, E4) | Alertmanager ne publie plus vers ntfy | Ce service ne remplace AUCUNE alerte ntfy.sh existante. Extension E4 si besoin. |
| 3 | Routes `external` + `internal` | `exposure: private` | Pas d'exposition publique | Décision de cette étape : aucune route publique. |
| 4 | Requests 10m/32Mi, limits 250m/192Mi | `size: small` = 50m/128Mi, 250m/256Mi | Plus de marge mémoire | Accepté. |
| 5 | PVC `ntfy-data` (`auth.db`, cache) | Aucun volume | Perte des utilisateurs et jetons créés au redémarrage | Accepté : stateless strict. |
| 6 | Egress : aucun explicite | `network.egress: none` | Équivalent | — |

## Secrets
Aucun. Pas de `secrets[]`, pas de `NTFY_AUTH_USERS`. Le secret kube-ops `APP_NTFY_ADMIN_PASSWORD` n'est pas utilisé.

## Preuves attendues (tests/golden-path-ntfy/)
1. `verify-http.sh` (lecture seule, `KUBECONFIG` OKE) : Argo `lab-o-ntfy` Synced/Healthy, ReleaseBinding Ready, pod Ready, 0 PVC / 0 LoadBalancer / 0 route externe, HTTP 200 sur `/v1/health` via `port-forward`.
2. Changement : `make-change-pr.sh` ajoute `NTFY_LOG_LEVEL: DEBUG` ; le revert passe par `APP=ntfy MARKER=NTFY_LOG_LEVEL tests/golden-path-whoami/make-revert-pr.sh`.
3. Après le premier déploiement : une 2e PR `pin-project ntfy` (avertissement d'`appgen check --base`).
