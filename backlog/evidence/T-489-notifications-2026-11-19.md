# T-489 : notifications Argo CD, check run GitHub (statut RUNTIME OKE : BLOCKED)

Date : 2026-11-19. Le contrôleur de notifications d'Argo est Running (1/1, activé par le chart). Rien n'a été écrit pour T-489.

| Étape | Verdict | Cause |
|---|---|---|
| (a) Secret `openchoreo-status` dans `lab-secrets` depuis Doppler | BLOCKED | la clé de l'App GitHub est un credential RÉEL ; décision de Paul : credentials FACTICES seulement dans OKE tant que le contrôleur kgateway lit les Secrets du cluster (risque accepté, `verify.sh` B6-sa-effective). Il faut une décision explicite de Paul pour ce secret. |
| (b) `20-eso-lab-store.yaml` | PASS (déjà appliqué par l'étape 4, ClusterSecretStore Ready) | |
| (c) `platform/install/argocd/notifications/` | NOT_TESTED | inutile sans (a) ; `install.sh` ne l'applique pas encore : écart à transformer en ticket |
| (d) check run sur une PR de test | NOT_TESTED | dépend de (a) |
| (e) test négatif : le jeton ne peut pas écrire de contenu | NOT_TESTED | dépend de (a) |
