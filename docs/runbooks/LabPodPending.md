---
alert: LabPodPending
severity: warning
class: REVUE
signals:
  - "un pod de l'app reste Pending depuis 15 minutes"
checks:
  - "kubectl get pods -n dp-<projet>-<app>-<env>"
  - "kubectl describe pod -n dp-<projet>-<app>-<env>"
  - "kubectl get events -n dp-<projet>-<app>-<env>"
  - "kubectl get resourcequota -n dp-<projet>-<app>-<env>"
allowed_actions:
  - diagnose
  - open-pr
  - notify
escalate_when:
  - "l'événement nomme un manque de CPU ou de mémoire du nœud"
  - "l'événement nomme un volume (PVC) non lié ou un refus d'admission"
  - "aucune cause prouvée après un cycle de diagnose-app"
---
# LabPodPending

## Contexte
Le pod ne peut pas être planifié : ressources du nœud, quota du namespace, volume, ou refus d'admission.

## Arbre de décision
1. Les événements parlent du quota du namespace et l'app demande plus que nécessaire ? Oui : PR qui réduit `size` ou `replicas`.
2. Les événements parlent des ressources du nœud ou d'un volume : problème de plateforme, escalade (budget CPU et stockage du labo).
3. Refus d'admission : ne jamais contourner la politique ; corriger `apps/<app>/app.yaml` si l'app est en cause, sinon escalade.

## Actions permises
PR sur `size` ou `replicas`. Aucune écriture directe, aucun contournement de quota, de PSA ou de NetworkPolicy.

## Escalade
Voir `escalate_when`.
