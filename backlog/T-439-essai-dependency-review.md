---
id: T-439
title: "Essai de dependency review sur ce dépôt (gratuité contradictoire dans la documentation)"
status: todo
phase: P1
adr: [0016]
depends_on: [T-431]
class: REVUE
velocity: false
lane: supply-chain
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-439 — Essai de dependency review sur ce dépôt (gratuité contradictoire dans la documentation)

## Intention
La page dependency review ouvre la fonction aux dépôts publics ; le tableau Advanced Security dit non. Tester actions/dependency-review-action sur une PR qui modifie un pin d'action ou requirements.txt ; requérir le check seulement si l'essai passe.

## Périmètre de fichiers
.github/workflows/dependency-review.yml

## Critères de fin
- [ ] PR d'essai : le job s'exécute et échoue sur une dépendance vulnérable factice, ou NOT_AVAILABLE consigné
- [ ] permissions : contents read seulement, action épinglée par SHA, dans l'allowlist
- [ ] décision requis ou non écrite

## Notes
Proposition GH-10 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Valeur faible aujourd'hui (peu de manifestes : requirements.txt, pins d'actions, digests d'images). Renovate couvre les versions.
