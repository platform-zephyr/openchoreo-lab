---
id: T-433
title: "Protection des tags : core-baseline et v* (ruleset de type tag)"
status: todo
phase: P0
adr: [0002]
depends_on: [T-305, T-430]
class: REVUE + MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-433 — Protection des tags : core-baseline et v* (ruleset de type tag)

## Intention
Interdire suppression et déplacement du tag core-baseline (référence du diff de T-401) et des tags v*. Paul applique le ruleset juste après T-305.

## Périmètre de fichiers
.github/rulesets/tags.json, tools/github/apply.sh

## Critères de fin
- [ ] tags.json : cibles refs/tags/core-baseline* et refs/tags/v*, règles deletion et update (et non_fast_forward)
- [ ] essai daté : suppression et déplacement du tag refusés pour une identité Write
- [ ] --check dev couvre aussi tags.json

## Notes
Proposition GH-4 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Releases immuables à activer au premier artefact publié (GH-14), pas avant.
