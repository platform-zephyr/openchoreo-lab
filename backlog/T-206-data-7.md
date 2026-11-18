---
id: T-206
title: "Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique"
status: deferred
phase: P5
adr: [0011, 0019]
depends_on: [T-011, T-023, T-201, T-205]
class: AUTONOME
velocity: false
lane: homelab
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-206 — Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique

## Intention
Déplacer ingestion et gold sur le homelab comme app du golden path ; produire metrics.json et index.html.

## Périmètre de fichiers
apps/metrics-job/app.yaml, tools/metrics/render/

## Critères de fin
- [ ] metrics.json de moins de 26 h, alerte sinon
- [ ] egress déclaré api.github.com
- [ ] preuve runtime app-status RUNTIME PASS

## Notes
Proposé par la recherche `data-platform` (clé T-206).

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
