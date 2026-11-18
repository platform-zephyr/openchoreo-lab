---
id: T-146
title: "Coût par app en monnaie de CPU/Go (sans OpenCost)"
status: dropped
phase: P3
adr: [0004, 0017]
depends_on: [T-010, T-140]
class: AUTONOME
velocity: false
lane: observabilité
stage: —
github_issue: null
---
# T-146 — Coût par app en monnaie de CPU/Go (sans OpenCost)

## Intention
Sommer par app les requests CPU/mémoire de la cellule et les volumes déclarés, exprimés en part du budget nœud (70 %) ; décision écrite de ne pas déployer OpenCost ni le FinOps Agent.

## Périmètre de fichiers
tools/appgen/ (calcul requests/volumes), tools/cost/app_footprint.py, docs/

## Critères de fin
- [ ] sortie app-footprint par app et par cluster, datée
- [ ] la somme par app est cohérente avec le total mesuré du nœud (écart documenté)
- [ ] note de décision : OpenCost/FinOps Agent réévalués seulement si un observability plane est déjà déployé

## Notes
OpenCost dépend de l'observability plane, lourd sur un nœud A1 à ~260m de marge avant 70 %.

Proposé par la recherche `cost` (clé T-146).

Supprimé par la revue adverse (consensus du 2026-11-18).
