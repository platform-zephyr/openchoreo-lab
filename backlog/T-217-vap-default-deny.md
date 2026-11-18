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
stage: S0
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-217 — VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny

## Intention
Rendre le default-deny réseau non contournable même si un agent modifie un ProjectType.

## Périmètre de fichiers
platform/policies/, tests/vap/

## Critères de fin
- [ ] VAP + test de refus en CI k3d
- [ ] preuve sur k3d datée
