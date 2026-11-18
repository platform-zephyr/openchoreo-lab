---
id: T-204
title: "Grille de maturité cloud native CNCF automatisée (niveaux 1-5)"
status: todo
phase: P4
adr: [0019]
depends_on: [T-061, T-072, T-201]
class: AUTONOME
velocity: false
lane: données
stage: I8
github_issue: null
---
# T-204 — Grille de maturité cloud native CNCF automatisée (niveaux 1-5)

## Intention
Traduire reference/v4beta1 en checks binaires datés par application et par cluster ; niveau = plus haut niveau tout PASS.

## Périmètre de fichiers
tools/metrics/maturity/, docs/reference/cncf-maturity-grid.yaml

## Critères de fin
- [ ] chaque check a source, niveau, dimension, cluster
- [ ] k3d et OKE jamais mélangés
- [ ] relire maturitymodel.cncf.io une fois l'hôte autorisé

## Notes
Hôtes maturitymodel.cncf.io, tag-app-delivery.cncf.io et dora.dev bloqués dans la session de recherche.

Proposé par la recherche `data-platform` (clé T-204).
