---
alert: LabAppStatusFail
severity: warning
class: AUTONOME
signals:
  - "app-status.v1 de l'app a un verdict FAIL depuis 10 minutes"
checks:
  - "golden-paths/_checks/run-all.sh --format json"
  - "argocd app get lab-o-<app>"
  - "kubectl get pods -n dp-<projet>-<app>-<env>"
allowed_actions:
  - diagnose
  - open-pr
  - revert
  - notify
escalate_when:
  - "cause.nature vaut plateforme"
  - "cause.type vaut cluster_unreachable"
  - "deux essais d'agent déjà faits sur cette app et cet environnement en 24 h"
---
# LabAppStatusFail

## Contexte
Le Job de statut a observé un check en échec. `cause` du document `app-status.v1` donne le premier check bloquant.

## Arbre de décision
1. Lire `cause.nature`. `retryable` : relancer `run-all.sh` une fois ; si le verdict reste FAIL, traiter comme `a_corriger`.
2. `a_corriger` : `fix-app` sur la règle `cause.rule` ; `revert` d'abord si un merge récent précède.
3. `plateforme` ou `cluster_unreachable` : l'agent n'agit pas, escalade.
4. Clore seulement sur un verdict PASS de niveau RUNTIME ; NOT_TESTED n'est pas PASS.

## Actions permises
PR ou revert par PR.

## Escalade
Voir `escalate_when`.
