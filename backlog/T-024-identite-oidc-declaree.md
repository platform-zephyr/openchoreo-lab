---
id: T-024
title: "Identité déclarée : `identity.mode: oidc | proxy | none`"
status: dropped
phase: P2
adr: [0007]
depends_on: [T-023, T-061, T-074]
class: REVUE
velocity: false
lane: identite
github_issue: null
---
# T-024 — Identité déclarée : `identity.mode: oidc | proxy | none`

## Intention
Client OIDC Authentik généré (blueprint) avec secret dans OpenBao ; mode proxy par l'outpost ; accès par groupe.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/identity/, clusters/*/capabilities.yaml

## Critères de fin
- [ ] k3d : client créé sans geste, hors groupe → refus
- [ ] preuve sur une app réelle

## Notes
Préciser comment les blueprints atteignent l'Authentik de production (kube-ops #1630) et où tourne Authentik en k3d. `platform/identity/` est dans le noyau.

Absorbé par T-189 (intégration des recherches du 2026-11-18).
