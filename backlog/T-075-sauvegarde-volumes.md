---
id: T-075
title: "Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia"
status: todo
phase: P2
adr: [0008]
depends_on: [T-025, T-030, T-061]
class: AUTONOME
velocity: false
lane: donnees
stage: I1
github_issue: null
---
# T-075 — Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia

## Intention
Un seul mécanisme pour les volumes, mesuré sur le homelab.

## Périmètre de fichiers
docs/storage/, platform/

## Critères de fin
- [ ] comparaison mesurée (coût, restauration)
- [ ] mécanisme choisi installé en `lab-*`
- [ ] sauvegarde + restauration d'un PVC prouvées
