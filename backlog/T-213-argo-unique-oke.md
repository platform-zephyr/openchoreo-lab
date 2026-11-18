---
id: T-213
title: "Un seul Argo CD sur OKE et nomenclature OKE figée (D4)"
status: todo
phase: P1
adr: [0003]
depends_on: [T-001, T-061]
class: REVUE + MANDAT
velocity: false
lane: socle-oke
stage: S2
github_issue: null
---
# T-213 — Un seul Argo CD sur OKE et nomenclature OKE figée (D4)

## Intention
Fusionner les Argo sur OKE (AppProject borné), trancher l'emplacement d'Authentik, sortir Backstage d'OKE, mesurer la nomenclature (≤ 33 pods, ≤ 70 %).

## Périmètre de fichiers
platform/install/argocd/, docs/architecture/

## Critères de fin
- [ ] un seul Argo sur OKE, preuve datée
- [ ] nomenclature mesurée et versionnée
- [ ] emplacement d'Authentik décidé par Paul
