---
id: T-076
title: "Application Cloudflare Access générée par app (Crossplane)"
status: todo
phase: P2
adr: [0010, 0009]
depends_on: [T-029, T-028]
class: AUTONOME
github_issue: null
---
# T-076 — Application Cloudflare Access générée par app (Crossplane)

## Intention
Une app `public` obtient son application Access ; `git revert` la retire.

## Périmètre de fichiers
tools/appgen/, platform/

## Critères de fin
- [ ] preuve : création et retrait sans geste
- [ ] `deletionPolicy: Orphan` vérifié
