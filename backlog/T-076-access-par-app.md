---
id: T-076
title: "Application Cloudflare Access générée par app (Crossplane)"
status: blocked
phase: P5
adr: [0010, 0009]
depends_on: [T-028, T-029]
class: AUTONOME
velocity: false
lane: exposition
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
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

## Notes


Bloqué par : déclencheur ADR-0009 §6 non atteint.
