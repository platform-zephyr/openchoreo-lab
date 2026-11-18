---
id: T-452
title: "Réactiver les suites k3d : quand et sous quelle forme (étude)"
status: todo
phase: P0
adr: [0024]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-452 — Réactiver les suites k3d : quand et sous quelle forme

## Intention
Les suites k3d (vap, k3d, argo-escalation, gitops-k3d) sont désactivées sur PR, push et nuit (décision de Paul, 2026-11-18) : lancement manuel seulement. Elles ne doivent pas freiner les itérations rapides des agents ; l'environnement de dev permet de ne pas attraper tous les bugs à cette étape. Décider quand et comment les remettre, sans bloquer les agents.

## Périmètre de fichiers
docs/research/K3D-REACTIVATION.md, .github/workflows/k3d-integration.yml, docs/CI-K3D.md

## Critères de fin
- [ ] rapport `docs/research/K3D-REACTIVATION.md` : jalon de réactivation (avant FINAL0 ?), forme (nuit seule, label, post-merge non bloquant, suite réduite), coût en minutes, signal d'échec sans bloquer
- [ ] état des échecs connus (B-09, T12, durée d'argo-escalation) et plan de correction
- [ ] workflow mis à jour selon la décision, `ci-ok` inchangé, aucune suite bloquante avant le jalon retenu

## Notes
Étude confiée à un sous-agent Opus. Rapport à arbitrer par Paul.
