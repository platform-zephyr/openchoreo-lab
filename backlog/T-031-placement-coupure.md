---
id: T-031
title: "Test de reprise du cluster lab (critère C4 révisé)"
status: todo
phase: P1
adr: [0003]
depends_on: [T-061, T-061b, T-364]
class: AUTONOME + MANDAT
velocity: false
lane: hybride
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-031 — Test de reprise du cluster lab (critère C4 révisé)

## Intention
Prouver 3 reprises sans action : redémarrage de la VM lab, pod agent arrêté 10 min, et coupure NetBird 10 min si un DP OKE existe ; apps Ready après chaque reprise.

## Périmètre de fichiers
tests/, docs/architecture/MULTI-DATAPLANE.md

## Critères de fin
- [ ] 3 coupures, délai de reprise mesuré, preuve datée par coupure
- [ ] kube-ops inchangé pendant l'essai (aucune alerte nouvelle)
- [ ] résultat C4 transmis au rapport de porte (T-211)

## Notes
Intégration 2 : absorbe HOME-6. La règle de placement passe à T-365, le déplacement oke ↔ homelab à T-030.
