---
alert: LabArgoAppDegraded
severity: warning
class: REVUE
signals:
  - "l'application Argo CD d'un namespace lab-* est Degraded ou Missing depuis 10 minutes"
checks:
  - "argocd app get lab-apps"
  - "argocd app history lab-apps"
  - "kubectl get applications.argoproj.io -n argocd"
  - "git log -n 5 -- apps generated"
allowed_actions:
  - diagnose
  - revert
  - notify
escalate_when:
  - "la dérive vient de platform/ ou d'Argo CD lui-même"
  - "le revert ne rend pas l'application Synced et Healthy"
  - "aucune cause prouvée après un cycle de diagnose-app"
---
# LabArgoAppDegraded

## Contexte
Argo CD n'obtient plus un état sain pour l'application. Classe `platform` : l'agent d'app n'a pas la main sur Argo CD.

## Arbre de décision
1. Le dernier merge sur `apps/` ou `generated/` précède l'incident ? Oui : `revert` par PR (un revert ne supprime jamais les releases historiques : job `release-history`).
2. Sinon : `diagnose-app` en lecture seule, rendre une cause prouvée.
3. Aucune action directe sur Argo CD (pas de sync, pas de suppression) ; escalade si la cause n'est pas dans Git.

## Actions permises
Revert par PR. Jamais de `sync` ou d'écriture dans le cluster.

## Escalade
Voir `escalate_when`.
