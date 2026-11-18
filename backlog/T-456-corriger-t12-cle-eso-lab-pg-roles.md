---
id: T-456
title: "Corriger T12 : clé ESO lab-pg-roles/<nom> refusée par le provider kubernetes"
status: in-progress
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: false
lane: agents
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---

# T-456 — Corriger T12 : clé ESO lab-pg-roles/<nom> refusée par le provider kubernetes

## Intention
Le PushSecret r-*-pg-role écrit une clé avec un « / » que lab-store (provider kubernetes d'ESO) refuse : toute app de l'archétype B échoue. Remplacer le séparateur par un caractère admis, aligner la règle R6 du VAP et les cas de test.

## Périmètre de fichiers
platform/resource-types/cnpg-lab-db.yaml, platform/policies/vap-cluster-agent-scope.yaml, tests/vap/, tests/k3d/

## Critères de fin
- [x] séparateur remplacé dans cnpg-lab-db.yaml (clé sans « / ») : `lab-pg-roles-${metadata.name}` (PushSecret l. 116, ExternalSecret l. 214) ; STATIC
- [x] règle R6 de vap-cluster-agent-scope.yaml et cas P01/P05 de tests/vap/ alignés : R6 lie la clé au nom (`remoteKey + '-pg-role' == 'lab-pg-roles-' + metadata.name`) ; P04/P06 migrés, P05 + P05b-e négatifs (ancienne clé `/`, autre app, préfixe seul, suffixe) ; T12e ajouté à tests/k3d (clé `password` du Secret `lab-pg-roles-<nom>` dans lab-secrets). Preuve STATIC 2026-11-18 : expression R6 extraite du YAML et évaluée par cel-go v0.23.2 sur 9 cas, 9/9 conformes ; l'ancienne R6 refuse P04 et la clé du CRT et admet `lab-pg-roles/app` (rouge attendu). P01 inchangé (ExternalSecret à générateur, sans clé du coffre)
- [ ] dispatch manuel de k3d et vap sur la branche : T12 vert, preuve datée

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.

Reste : pousser la branche, dispatcher `k3d-integration` (suites `k3d` et `vap`) et consigner T12a-e et V1-P04/P05b-e PASS datés (runtime NOT_TESTED : k3s ne démarre pas dans le conteneur de l'agent, 2026-11-18).
