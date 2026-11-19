---
name: read-app-status
description: Lire, sans accès cluster ni identifiant, l'état de déploiement d'une app du labo sur OKE (success, failure, pending, absent) pour une révision Git, par le check run GitHub `argocd/<application>` que publie Argo CD Notifications. Pour un agent cloud ou de l'usine qui doit savoir si sa PR fusionnée est déployée et saine. Ne diagnostique pas : un failure passe au coordinateur (diagnose-app).
---

# read-app-status

Lecture seule : API GitHub publique, aucune commande `kubectl`, aucun identifiant à fournir. Producteur du statut :
Argo CD Notifications sur OKE, sous l'App GitHub `openchoreo-status` (T-489,
`platform/install/argocd/notifications/argocd-notifications-cm.yaml`). Un seul appel `gh api` (T-507, remplace
`tools/status/app_status.py`).

## Commande

```bash
APP=whoami                      # nom du dossier generated/namespaces/default/projects/<APP>
SHA=<SHA du commit de fusion>   # préférer un SHA à `main` (voir Limites)
# Garde : refuser une app inconnue ou absente de la liste OKE de lab-o (clusters/oke/lab-o-apps.yaml, T-502).
[ -d "generated/namespaces/default/projects/$APP" ] &&
  grep -qx -- "- app: $APP" clusters/oke/lab-o-apps.yaml ||
  { echo "unknown_app: $APP non déployée sur OKE" >&2; exit 2; }
gh api "repos/platform-zephyr/openchoreo-lab/commits/$SHA/check-runs?check_name=argocd/lab-o-$APP&filter=all" \
  --jq '[.check_runs[] | select(.app.slug == "openchoreo-status")] | sort_by(.id) | last
        | {status, conclusion, completed_at, details_url}'
```

`null` en sortie = aucun check run : `absent`. `lab-k-<nom>` (bac à sable du bras K) : même appel sur
`platform-zephyr/bench-ab-arm-k`, sans garde.

## Interprétation

| `status` / `conclusion` | Sens | Suite |
|---|---|---|
| `completed` / `success` | Argo CD : Synced + Healthy sur ce SHA | preuve de niveau RECONCILED (pas une preuve HTTP) |
| `neutral`, ou `status` ≠ `completed` | pending : Progressing ou check non terminé | relire plus tard |
| `failure` (ou `timed_out`, `cancelled`, `action_required`) | Degraded, ou synchro Error/Failed | demander au coordinateur `diagnose-app` (lecture cluster) ; citer `details_url` et le SHA |
| `null` | absent : voir Limites | relire plus tard |

## Limites

- **Pas de boucle serrée : ≥ 1 min entre deux lectures.** Limite GitHub : 60 requêtes/heure par IP sans jeton. Une
  réponse 403 ou 429 se traite par une pause, jamais par une relance immédiate.
- **`main` mouvant** : juste après une fusion, le nouveau HEAD peut n'avoir aucun check (`absent`) alors que la
  révision précédente est `success`. Utiliser le SHA du commit attendu.
- **`absent` n'est pas un échec** : révision pas encore synchronisée, app hors OKE, Notifications non posé
  (`tools/oke/install.sh` étape 11 l'omet si le Secret `openchoreo-status` manque), ou cluster éteint.
- Un `success` dit « Synced + Healthy », pas « l'app répond » : la preuve HTTP reste au coordinateur
  (`golden-paths/_checks/run-all.sh`).
- Un check run du même nom publié par une autre App (Actions, etc.) est ignoré par le filtre `app.slug`.
- Lecture du cluster (Argo, OpenChoreo, pods) : jamais par cette voie ; le coordinateur utilise `diagnose-app`.
