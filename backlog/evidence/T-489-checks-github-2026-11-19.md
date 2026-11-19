# T-489 : check runs GitHub publiés depuis OKE par l'App openchoreo-status (RUNTIME OKE)

Date : 2026-11-19. Décision de Paul (en toutes lettres) : placer la clé réelle de l'App dans ce cluster malgré la lecture des
Secrets par kgateway ; révocation si le chantier kgateway ou un incident l'exige.

| Étape | Verdict | UTC | Détail |
|---|---|---|---|
| (a) Secret `openchoreo-status` dans `lab-secrets` | PASS | 00:57:01 | créé PAR TUBE depuis Doppler (projet identity, config openchoreo-status) ; trois clés `OPENCHOREO_STATUS_APP_ID`, `..._INSTALLATION_ID`, `..._PRIVATE_KEY` ; aucune valeur affichée ni écrite |
| (b) `20-eso-lab-store.yaml` | PASS après correction | 00:59:29 | le ClusterSecretStore vivant n'admettait pas `lab-argocd` (posé à l'étape 4 avant T-489) : `ExternalSecret` en `SecretSyncedError` (« using cluster store lab-store is not allowed from namespace lab-argocd »). `install.sh --step 4 --apply` rejoué, `verify.sh --step 4` PASS, ExternalSecret `SecretSynced` |
| (c) `platform/install/argocd/notifications/` | PASS (appliqué à la main) | 00:57:14 | `kubectl apply --server-side` : ConfigMap, ExternalSecret, CiliumNetworkPolicy ; `install.sh` ne l'applique pas encore (écart : ticket T-497 en cours). Contrôleur de notifications redémarré et sans erreur après la synchro du Secret |
| (d) check run publié et lu anonymement | PASS | 00:59:39 à 00:59:44 | sur le commit synchronisé `fc16f9b…`, l'API publique GitHub (sans identifiant) renvoie 4 check runs de l'App `openchoreo-status` : `argocd/lab-o-whoami`, `-ntfy`, `-echo-demo`, `-searxng`, tous `completed / success` |
| (e) le jeton de l'App ne peut pas écrire de contenu | NOT_TESTED | | la tentative d'écriture avec un jeton d'installation exigeait de manipuler la clé privée dans le shell : refusé par la garde de l'environnement, non contourné ; l'App n'est pas publique (`GET /apps/openchoreo-status` : null), ses permissions ne sont donc pas lisibles anonymement. Reste à prouver par l'intermédiaire de Paul (permissions déclarées : Checks et Commit statuses en écriture, Metadata en lecture) |

Limite relevée : `argocd/lab-o-searxng` est publié `success` alors que le pod searxng est en échec (Argo ne voit que les objets
OpenChoreo, Synced/Healthy). Le check run prouve la synchro GitOps, pas la santé de l'application.

# searxng (SEARXNG_SECRET) : BLOCKED, cause prouvée

Demande : ajouter `SEARXNG_SECRET` (valeur aléatoire) dans `lab-store`. Impossible tel quel : le magasin `lab-store` est un
fournisseur `kubernetes` (coffre = Secrets de `lab-secrets`), et l'ExternalSecret généré référence `remoteRef.key:
SEARXNG_SECRET` sans `property`. Un nom de Secret Kubernetes doit être en minuscules RFC 1123 : la création d'un Secret nommé
`SEARXNG_SECRET` est refusée par l'API (dry-run serveur, 2026-11-19T00:56Z). Le contrat généré (clé en majuscules) vise un
fournisseur Doppler, pas le fournisseur kubernetes de `lab-store`. Aucun secret n'a été créé. Correction : contrat plateforme
(CCT/appgen : `remoteRef.key` = nom de Secret minuscule + `property`) ; ticket à ouvrir.
