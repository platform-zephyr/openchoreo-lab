---
id: T-217
title: "VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny"
status: todo
phase: P0
adr: [0006, 0002]
depends_on: [T-002]
class: REVUE
velocity: false
lane: securite
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-217 — VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny

## Intention
Rendre le default-deny réseau non contournable même si un agent modifie un ProjectType.

## Périmètre de fichiers
platform/policies/, tests/vap/

## Critères de fin
- [x] VAP + test de refus en CI k3d (PASS V3-01 à V3-05, job `k3d vap` : run `workflow_dispatch` 44402302864 du 2026-11-18 sur 7a6a517, puis run de `main` 44410837626 sur 79a63e0, conclusion success)
- [x] preuve sur k3d datée (2026-11-18, CI k3d : https://github.com/platform-zephyr/openchoreo-lab/actions/runs/44402302864 ; `main` : https://github.com/platform-zephyr/openchoreo-lab/actions/runs/44410837626)

## Notes
Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

2026-11-18 — Défaut trouvé par le test. La première version de la VAP refusait les pods de TOUT namespace sans default-deny, car l'apiserver collecte le paramètre avant d'évaluer les `matchConditions`. Correctif : un `namespaceSelector` sur le label `platform.smadja.dev/cell: restricted`. Preuve du correctif : V3-05 (pod hors cellule sans NetworkPolicy : ALLOW) PASS dans les runs 44402302864 et 44410837626.
