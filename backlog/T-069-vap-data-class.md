---
id: T-069
title: "VAP : refus de DELETE des données `irreplaceable` (G8)"
status: todo
phase: P2
adr: [0008, 0006]
depends_on: [T-025, T-061, T-061b]
class: REVUE
velocity: false
lane: securite
stage: I1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-069 — VAP : refus de DELETE des données `irreplaceable` (G8)

## Intention
Un objet porteur de `data-class=irreplaceable` ne peut pas être supprimé sans exception explicite.

## Périmètre de fichiers
platform/policies/, tests/vap/

## Critères de fin
- [ ] VAP + suite de refus en CI k3d
- [ ] preuve OKE ou homelab datée
