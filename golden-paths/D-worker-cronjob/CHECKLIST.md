# Checklist D : worker et CronJob (NON DISPONIBLE)

État au 2026-11-17 : **BLOCKED**. Le schéma v2alpha1 exige `runtime.port` et `runtime.healthPath`. La CCT `service-restricted` exige au moins un endpoint et ne rend qu'un Deployment. Détail et proposition : `../SCHEMA-GAPS.md` G1 et `app.proposed.yaml`.

Conduite d'un agent face à ce besoin :

1. Répondre « archétype D non disponible ». Ne pas simuler un worker avec un faux endpoint HTTP ni avec un `kubectl create cronjob`.
2. Proposer une PR **plateforme** (classe protégée : `platform/`, schéma, `tools/appgen`) qui ajoute une CCT `cronjob-restricted` (copie durcie du sample `scheduled-task` v1.3.3) et le champ `spec.kind`.

Vérifications prévues, déjà scriptées dans `../_checks/check-cronjob.sh` :

| ID | Preuve attendue |
|---|---|
| D1 | CronJob présent, `concurrencyPolicy=Forbid`, `suspend=false` |
| D2 | `runAsNonRoot`, image par digest |
| D3 | `lastSuccessfulTime` renseigné ; aucun Job en échec |

Rollback prévu : `git revert`. Un Job déjà exécuté n'est pas annulé : ses effets de bord relèvent de l'app.
