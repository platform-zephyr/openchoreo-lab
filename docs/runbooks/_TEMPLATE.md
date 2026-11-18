---
# Gabarit de runbook lisible par agent (T-100, ADR-0015). Copier vers docs/runbooks/<NomDeLaRègle>.md.
# Contrôlé par tools/observe/lint_runbooks.py : une règle d'alerte sans runbook, ou un runbook sans règle, échoue.
alert: NomDeLaRegle          # identique au nom du fichier et au champ `alert:` de la règle
severity: warning            # critical | warning | info ; identique à la règle
class: AUTONOME              # classe de garde la plus haute que ce runbook autorise : AUTONOME | REVUE | MANDAT (platform-guardrails)
signals:                     # ce qui doit être vrai pour que le runbook s'applique (au moins 1)
  - "condition observable"
checks:                      # commandes de LECTURE seule (au moins 1) ; aucun apply, delete, patch, exec, scale
  - "kubectl get pods -n lab-<app>-<env>"
allowed_actions:             # diagnose | open-pr | revert | notify ; jamais d'écriture directe dans le cluster
  - diagnose
escalate_when:               # conditions d'escalade vers Paul (au moins 1)
  - "condition d'escalade"
---
# NomDeLaRegle

## Contexte
Une phrase : ce que la règle détecte et pourquoi c'est important.

## Arbre de décision
1. Question vérifiable par un check ci-dessus. Oui : étape 2. Non : étape 4.
2. Cause identifiée : agir selon `allowed_actions`.
3. Vérifier par `golden-paths/_checks/run-all.sh` (preuve runtime datée), sinon dire NOT_TESTED.
4. Aucune cause prouvée : escalader (voir `escalate_when`).

## Actions permises
Par classe de garde. Tout changement durable passe par une PR (`apps/<nom>/app.yaml`).

## Escalade
Une issue d'incident par (app, env) ; 2 essais par app et par 24 h ; au-delà, `agent:gave-up` et ntfy.
