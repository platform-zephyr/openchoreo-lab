---
alert: LabPodCrashLooping
severity: warning
class: AUTONOME
signals:
  - "un conteneur de l'app est en CrashLoopBackOff depuis 5 minutes"
checks:
  - "kubectl get pods -n dp-<projet>-<app>-<env>"
  - "kubectl describe pod -n dp-<projet>-<app>-<env>"
  - "kubectl logs -n dp-<projet>-<app>-<env> --previous --tail=50"
  - "golden-paths/_checks/run-all.sh --format json"
allowed_actions:
  - diagnose
  - open-pr
  - revert
  - notify
escalate_when:
  - "le journal du conteneur montre un secret, une base ou un service de la plateforme injoignable"
  - "aucune cause prouvée après un cycle de diagnose-app"
  - "deux essais d'agent déjà faits sur cette app et cet environnement en 24 h"
---
# LabPodCrashLooping

## Contexte
Le conteneur démarre puis s'arrête en boucle : mauvaise commande ou variable, image incompatible, dépendance absente.

## Arbre de décision
1. Un bump d'image ou un changement d'`env` récent précède la boucle ? Oui : `revert` par PR.
2. Le journal du conteneur précédent nomme une erreur de configuration de l'app ? Oui : correctif par PR sur `apps/<app>/app.yaml` (`fix-app`).
3. L'erreur vient d'une dépendance (base, ExternalSecret) : `diagnose-app` ; si la cause est plateforme, escalade.
4. Aucune cause : escalade. Ne jamais copier le journal brut dans l'issue ou la PR (le dépôt est public) : citer la cause en une phrase.

## Actions permises
PR ou revert par PR. Pas de suppression de pod à la main.

## Escalade
Voir `escalate_when`.
