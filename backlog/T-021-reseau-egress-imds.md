---
id: T-021
title: "Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules"
status: todo
phase: P2
adr: [0006, 0003]
depends_on: [T-002, T-061, T-364]
class: AUTONOME + MANDAT
velocity: false
lane: securite
stage: I3
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-021 — Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules

## Intention
Même rendu réseau sur OKE et homelab ; `dp-*` couverts par le refus IMDS.

## Périmètre de fichiers
tools/appgen/, platform/project-types/, tests/

## Critères de fin
- [ ] CNP rendues pour fqdn/app/idp
- [ ] preuve OKE : IMDS refusé depuis une cellule `dp-*`
- [ ] test de non-régression egress

## Notes
La CCNP `deny-imds` et `allow-egress-unisolated` sont possédées par kube-ops (PR #1629 non fusionnée) : ne pas créer un second propriétaire.
