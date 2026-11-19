---
name: read-app-status
description: Lire, sans accès cluster ni identifiant, l'état de déploiement d'une app du labo sur OKE (success, failure, pending, absent) pour une révision Git, par le check run GitHub `argocd/<application>` que publie Argo CD Notifications. Pour un agent cloud ou de l'usine qui doit savoir si sa PR fusionnée est déployée et saine. Ne diagnostique pas : un failure passe au coordinateur (diagnose-app).
---

# read-app-status

Lecture seule, anonyme : API GitHub publique, aucun jeton lu ni envoyé, aucune commande `kubectl`. Producteur du
statut : Argo CD Notifications sur OKE, sous l'App GitHub `openchoreo-status` (T-489,
`platform/install/argocd/notifications/argocd-notifications-cm.yaml`).

## Commande

```bash
python3 tools/status/app_status.py <app> --sha <SHA>   # révision précise (SHA du commit de fusion, de préférence)
python3 tools/status/app_status.py <app>               # --ref main par défaut (branche, tag ou SHA)
```

`<app>` : `whoami` lit l'Application `lab-o-whoami` dans ce dépôt ; `lab-k-<nom>` lit le bac à sable du bras K
(`platform-zephyr/bench-ab-arm-k`). Une app absente de `generated/namespaces/default/projects/` ou exclue de
l'ApplicationSet `lab-o` (non déployée sur OKE) est refusée sans requête (code 2, `unknown_app`).

## Interprétation (sortie JSON `app-checkrun.v1`, clés stables ; schéma : docstring de l'outil)

| `conclusion` | Sens | Suite |
|---|---|---|
| `success` | Argo CD : Synced + Healthy sur `revision` | preuve de niveau RECONCILED (pas une preuve HTTP) |
| `pending` | Progressing (check `neutral`) ou check non terminé | relire plus tard (≥ 1 min), jamais en boucle serrée |
| `failure` | Degraded, ou synchro Error/Failed | demander au coordinateur `diagnose-app` (lecture cluster) ; citer `details_url` et `revision` |
| `absent` | aucun check run `openchoreo-status` de ce nom sur cette révision | voir Limites |

`error` non nul : `code` = `usage`/`unknown_app` (2), `throttled`/`rate_limited` (3, `retry_after_s` donné),
`not_found`/`network`/`api_error` (4). `source: cache` + `stale: true` : statut ancien servi faute de requête permise.
Codes de sortie : 0 = lecture faite, quelle que soit la conclusion.

## Limites

- **1 requête par minute** (horloge locale dans le cache) et 60 requêtes/heure par IP côté GitHub (anonyme) : sur un
  runner partagé, la limite peut être déjà consommée. L'outil n'attend jamais et ne réessaie pas : relancer après
  `retry_after_s`.
- **`--ref main` mouvant** : Argo CD publie sur la révision qu'il a synchronisée. Juste après une fusion, HEAD peut
  n'avoir aucun check (`absent`) alors que la révision précédente est `success`. Préférer `--sha` du commit attendu.
- **`absent` n'est pas un échec** : révision pas encore synchronisée, app hors OKE, Notifications non posé
  (`tools/oke/install.sh` étape 11 l'omet si le Secret `openchoreo-status` manque), ou cluster éteint.
- Un check run `success` dit « Synced + Healthy », pas « l'app répond » : la preuve HTTP reste au coordinateur
  (`golden-paths/_checks/run-all.sh`).
- Un check run du même nom publié par une autre App (Actions, etc.) est ignoré.
- Lecture du cluster (Argo, OpenChoreo, pods) : jamais par cette voie. Le coordinateur, qui a l'accès, utilise
  `diagnose-app`.

Tests hors réseau : `python3 -I -m unittest discover -s tests/status -p 'test_*.py'`.
