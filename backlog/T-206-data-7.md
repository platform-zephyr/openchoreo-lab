---
id: T-206
title: "Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique"
status: todo
phase: P3
adr: [0011, 0019]
depends_on: [T-011, T-023, T-202, T-205]
class: AUTONOME
velocity: false
lane: homelab
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
