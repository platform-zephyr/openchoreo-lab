---
alert: LabAppDown
severity: critical
class: AUTONOME
signals:
  - "aucun réplica disponible pour le Deployment de l'app depuis 5 minutes"
  - "le cluster répond à la sonde (lab_cluster_reachable vaut 1)"
checks:
  - "golden-paths/_checks/run-all.sh --format json"
  - "kubectl get pods -n dp-<projet>-<app>-<env>"
  - "kubectl describe deployment -n dp-<projet>-<app>-<env>"
  - "argocd app get lab-apps"
allowed_actions:
  - diagnose
  - open-pr
  - revert
  - notify
escalate_when:
  - "cause.nature vaut plateforme dans app-status.v1"
  - "aucune cause prouvée après un cycle de diagnose-app"
  - "revert impossible ou migration de données dans le diff fautif"
  - "deux essais d'agent déjà faits sur cette app et cet environnement en 24 h"
---
# LabAppDown

## Contexte
L'application n'a plus aucun réplica disponible. Si l'environnement est `production`, c'est l'alerte la plus urgente du labo.

## Arbre de décision
1. Un merge récent sur `apps/<app>/` précède la panne (`git log -n 5 -- apps/<app>`) ? Oui : `revert` de ce merge par PR (classe AUTONOME, `promote-or-rollback`). Non : étape 2.
2. `run-all.sh` donne `cause.nature` ? `retryable` : une seule relance du check, puis étape 4. `a_corriger` : `fix-app`, correctif par PR. `plateforme` : escalade.
3. Après correctif ou revert, vérifier avec `run-all.sh` : seul un verdict PASS de niveau RUNTIME clôt l'incident.
4. Aucune cause prouvée : escalade.

## Actions permises
PR sur `apps/<app>/app.yaml` ou `git revert` par PR. Jamais d'écriture directe dans le cluster, jamais de modification de règle, de silence ou de CI.

## Escalade
Issue d'incident par (app, env), puis ntfy externe si `escalate_when` est atteint.
