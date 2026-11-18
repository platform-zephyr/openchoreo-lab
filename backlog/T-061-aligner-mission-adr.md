---
id: T-061
title: "Acter les ADR 0001-0019 (+ amendements identité/secrets) et aligner MISSION, AGENTS, STATE"
status: todo
phase: P0
adr: [0002, 0012]
depends_on: []
class: MANDAT
velocity: false
lane: gouvernance
github_issue: null
---
# T-061 — Acter les ADR 0001-0019 (+ amendements identité/secrets) et aligner MISSION, AGENTS, STATE

## Intention
Lever les contradictions : MISSION interdit encore exposition publique, création d'identité, Cloudflare ; services visés obsolètes ; ADR tous PROPOSÉ.

## Périmètre de fichiers
missions/MISSION.md, AGENTS.md, STATE.md, docs/adr/

## Critères de fin
- [ ] Paul approuve : ADR passés ACTÉ (ou amendés)
- [ ] MISSION : interdits réécrits en classes (public avec auth, clients OIDC générés, Crossplane borné, volume OCI = MANDAT)
- [ ] AGENTS.md renvoie à backlog/ et docs/adr/ ; STATE.md sans contradiction
- [ ] ADR-0015 à 0019 actés ou amendés après la revue adverse
- [ ] amendements d'ADR-0007/0014/0002 issus de docs/research/IDENTITY-SECRETS.md tranchés (seal statique, noyau users/ groups/ identities/ platform/secrets/)
