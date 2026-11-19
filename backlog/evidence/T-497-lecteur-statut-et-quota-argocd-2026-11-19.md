# T-497 / T-489 : lecteur de statut, notifications appliquées par install.sh, quota lab-argocd (RUNTIME OKE)

| Preuve | Verdict | UTC | Détail |
|---|---|---|---|
| `helm upgrade argocd` (étape 11 rejouée, 1re tentative) | FAIL | 01:12 à 01:23 | hook Job `argocd-redis-secret-init` InProgress, pod jamais créé : ResourceQuota `lab-argocd` pods 6/6 (6 pods installés après ApplicationSet + notifications) |
| Cause prouvée (lecture seule) | PASS | 01:25 | `kubectl describe resourcequota` : pods 6/6 ; Job sans pod |
| Correctif PR #166 (quota pods 8, requests 150m/768Mi, limits 3072Mi), `install.sh --step 1 --apply`, Job de hook supprimé (objet créé par le chart) | PASS | 01:29 | quota vivant pods=8 |
| Étape 11 rejouée (2e et dernière tentative) | PASS | 01:29:24 à 01:30:46 | upgrade Helm complet ; `install.sh` applique lui-même `platform/install/argocd/notifications/` (le Secret existe) : ConfigMap, ExternalSecret, CiliumNetworkPolicy |
| `verify.sh --step 11` | PASS (FAIL=0) | 01:31:15 | |
| ExternalSecret `argocd-notifications-secret` | PASS (SecretSynced) | 01:31 | |
| Lecteur anonyme `tools/status/app_status.py ntfy --ref main` | PASS | 01:31:18 | `success`, `completed_at` 01:29:51Z, `error` null (lecture sans identifiant, API publique) |
| Contrôleurs Argo : applicationset 1/1, notifications 1/1 | PASS | 01:31 | |
Limite : le check run `success` prouve la synchro GitOps, pas la santé applicative (searxng est publié `success` avec son pod en échec).
