---
id: T-062
title: "`lab-platform` en synchronisation automatique (hors lab-pg)"
status: todo
phase: P1
adr: [0002]
depends_on: [T-001, T-002, T-061, T-061b, T-363]
class: REVUE
velocity: true
lane: socle-oke
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-062 — `lab-platform` en synchronisation automatique (hors lab-pg)

## Intention
Un merge sur `platform/` hors noyau est appliqué sans geste humain (promesse d'ADR-0002 §1).

## Périmètre de fichiers
platform/install/argocd/

## Critères de fin
- [ ] sync auto, `prune: false`, selfHeal
- [ ] lab-pg exclu tant que le volume n'est pas autorisé
- [ ] preuve : un changement de CCT appliqué après merge

## Notes
Intégration 2 : cible = Argo du cluster qui porte le CP (lab-argocd pendant la porte, D4).
