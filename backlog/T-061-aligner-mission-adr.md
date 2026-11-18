---
id: T-061
title: "Acter les ADR et aligner MISSION, AGENTS, STATE sur ADR-0002/0007/0010/0012/0014"
status: todo
phase: P0
adr: [0002, 0012]
depends_on: []
class: MANDAT
github_issue: null
---
# T-061 — Acter les ADR et aligner MISSION, AGENTS, STATE sur ADR-0002/0007/0010/0012/0014

## Intention
Lever les contradictions : MISSION interdit encore exposition publique, création d'identité, Cloudflare ; services visés obsolètes ; ADR tous PROPOSÉ.

## Périmètre de fichiers
missions/MISSION.md, AGENTS.md, STATE.md, docs/adr/

## Critères de fin
- [ ] Paul approuve : ADR passés ACTÉ (ou amendés)
- [ ] MISSION : interdits réécrits en classes (public avec auth, clients OIDC générés, Crossplane borné, volume OCI = MANDAT)
- [ ] AGENTS.md renvoie à backlog/ et docs/adr/ ; STATE.md sans contradiction
