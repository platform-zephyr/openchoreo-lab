---
id: T-142
title: "Refus CI de tout ce qui sort du free tier (volume sur OKE, LB, IP, hors région)"
status: dropped
phase: P1
adr: [0003, 0004, 0017]
depends_on: [T-004, T-030, T-140]
class: AUTONOME
velocity: true
lane: appgen
stage: —
github_issue: null
---
# T-142 — Refus CI de tout ce qui sort du free tier (volume sur OKE, LB, IP, hors région)

## Intention
capabilities.yaml déclare freeTier (blockGB restant, lb: 0) ; appgen et la CI refusent storage/base sur OKE hors budget, expose via LB, Service LoadBalancer, PVC rendu, avec message typé et correction attendue.

## Périmètre de fichiers
tools/appgen/, clusters/<cluster>/capabilities.yaml (freeTier), tests/appgen/

## Critères de fin
- [ ] un test par refus, sur valeurs effectives après overrides
- [ ] erreur typée cost-free-tier avec la correction
- [ ] aucun contournement de VAP/PSA/NetworkPolicy (AGENTS.md)

## Notes
Complète T-004 (frugalité dev) sans le remplacer ; les VAP qui refusent le LB sont du noyau protégé (REVUE si modifiées).

Proposé par la recherche `cost` (clé T-142).

Fusion coût (consensus du 2026-11-18). Fusionné dans T-140.
