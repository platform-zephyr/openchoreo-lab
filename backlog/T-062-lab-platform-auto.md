---
id: T-062
title: "`lab-platform` en synchronisation automatique (hors lab-pg)"
status: todo
phase: P0
adr: [0002]
depends_on: [T-001, T-002]
class: REVUE
velocity: true
lane: socle-oke
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
