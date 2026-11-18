---
id: T-492
title: "Cible : l'Argo du cluster, amorcé par kube-ops, livre la plateforme par une seule Application racine"
status: todo
phase: P2
adr: [0025, 0003]
depends_on: [T-488, T-491]
class: REVUE + MANDAT
velocity: false
lane: hybride
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-492 — Branchement cible sur l'Argo de kube-ops

## Intention
Après une porte 1 positive, retirer l'instance Argo propre du labo sur le cluster cible : l'Argo du cluster est amorcé par kube-ops (mode pull, D-2026-11-11-17), qui porte une seule Application vers `platform/install/argocd/apps` de ce dépôt et les AppProjects du labo (`docs/research/POC-OPENCHOREO-STRATEGY.md` §3.4).

## Périmètre de fichiers
platform/install/argocd/, docs/architecture/, dépôt kube-ops (hors de ce dépôt : Application racine et AppProjects, par PR côté kube-ops)

## Critères de fin
- [ ] PR côté kube-ops : une Application `openchoreo-lab` et les AppProjects du labo, rien d'autre ; frontière identique (diff des AppProjects nul)
- [ ] `tests/argo-escalation/` rejoué contre la version d'Argo de kube-ops, PASS (preuve datée)
- [ ] règle écrite : toute montée d'Argo côté kube-ops rejoue `tests/argo-escalation/` avant fusion
- [ ] sur le cluster cible : un seul Argo, `lab-root` Synced par l'Argo de kube-ops (preuve datée RUNTIME)

## Notes
Dépend de la décision de la porte 1 ; le cluster cible (VM lab ou autre) est tranché par la porte 2 (T-211).
