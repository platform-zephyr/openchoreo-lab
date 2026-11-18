---
id: T-464
title: "Règles d'agent « local d'abord » dans AGENTS.md et les skills (SL-10)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-455]
class: REVUE
velocity: false
lane: gouvernance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-464 — Règles d'agent « local d'abord » dans AGENTS.md et les skills (SL-10)

## Intention
Avant `git push` : `tools/dev/check --static --changed`, PASS avec niveau et reçu. Étape « local d'abord » dans les skills add-app et fix-app.

## Périmètre de fichiers
AGENTS.md, .agents/skills/

## Critères de fin
- [ ] règle ajoutée à AGENTS.md (courte, sans recopier de règle existante)
- [ ] étape « local d'abord » dans add-app et fix-app

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
