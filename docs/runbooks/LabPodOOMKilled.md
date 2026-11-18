---
alert: LabPodOOMKilled
severity: warning
class: REVUE
signals:
  - "le dernier arrêt d'un conteneur de l'app a pour raison OOMKilled"
checks:
  - "kubectl describe pod -n dp-<projet>-<app>-<env>"
  - "kubectl top pod -n dp-<projet>-<app>-<env>"
  - "golden-paths/_checks/run-all.sh --format json"
allowed_actions:
  - diagnose
  - open-pr
  - notify
escalate_when:
  - "la taille demandée dépasse la taille maximale du type de composant ou le quota du namespace"
  - "la fuite mémoire est probable (consommation qui croît sans charge)"
  - "deux essais d'agent déjà faits sur cette app et cet environnement en 24 h"
---
# LabPodOOMKilled

## Contexte
Le conteneur dépasse sa limite mémoire. La limite vient du champ `size` de l'app, pas d'un réglage libre.

## Arbre de décision
1. L'app tourne à la taille la plus grande permise ? Oui : escalade (le quota est une décision de Paul).
2. Sinon : PR qui monte `size` d'un cran dans `apps/<app>/app.yaml` (classe REVUE : fusion après `ci-ok`, mode dev).
3. Vérifier avec `run-all.sh` ; surveiller que l'alerte ne revient pas sous 24 h, sinon fuite probable : escalade.

## Actions permises
PR sur `size` uniquement. Jamais de contournement de quota ou de politique d'admission.

## Escalade
Voir `escalate_when`.
