---
alert: LabClusterUnreachable
severity: info
class: AUTONOME
signals:
  - "la sonde du cluster échoue depuis 10 minutes"
checks:
  - "golden-paths/_checks/run-all.sh --format json"
allowed_actions:
  - notify
escalate_when:
  - "la sonde échoue depuis plus de 24 heures sans arrêt annoncé du homelab"
  - "la sonde échoue alors que le cluster est censé être allumé"
---
# LabClusterUnreachable

## Contexte
Le homelab est éteint certains soirs. Cette alerte d'information suspend les alertes d'application (garde de warm-up) : aucune autre alerte ne doit partir pendant ce temps.

## Arbre de décision
1. Arrêt annoncé ou nocturne : ne rien faire. L'alerte se résout au retour de la sonde.
2. Cluster censé être allumé : notifier Paul (`notify`). Aucun agent de remédiation d'application n'est lancé, aucun accès au cluster n'est tenté en écriture.
3. Au retour du site, vérifier avec `run-all.sh` : NOT_TESTED sans cluster, jamais PASS.

## Actions permises
Notification seulement.

## Escalade
Voir `escalate_when`.
