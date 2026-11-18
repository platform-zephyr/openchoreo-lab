---
id: T-013
title: "Surcharges par environnement (G12) et dépendances entre apps (G11)"
status: todo
phase: P1
adr: [0005, 0004]
depends_on: [T-003]
class: AUTONOME
github_issue: null
---
# T-013 — Surcharges par environnement (G12) et dépendances entre apps (G11)

## Intention
`overrides.<env>` (size, replicas, env) et `dependsOn` (egress ciblé + variable d'URL).

## Périmètre de fichiers
docs/schema/, tools/appgen/

## Critères de fin
- [ ] tests appgen
- [ ] NetworkPolicy d'egress ciblée rendue
- [ ] preuve k3d A → B
