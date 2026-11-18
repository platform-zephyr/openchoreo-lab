---
id: T-066
title: "Rotation et échéances des secrets et jetons racines"
status: dropped
phase: P2
adr: [0014]
depends_on: [T-023]
class: MANDAT
velocity: false
lane: secrets
stage: —
github_issue: null
---
# T-066 — Rotation et échéances des secrets et jetons racines

## Intention
Inventaire des échéances (service token Access, jetons R2, jeton GitHub, clé d'auto-unseal, secrets clients OIDC) et procédure testée.

## Périmètre de fichiers
docs/runbooks/, tools/

## Critères de fin
- [ ] inventaire sans valeurs, avec échéances
- [ ] rotation d'un secret OIDC prouvée sans coupure
- [ ] alerte avant échéance

## Notes
Absorbé par T-194 (intégration des recherches du 2026-11-18).
