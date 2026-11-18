---
id: T-068
title: "Sécurité et attribution des agents"
status: todo
phase: P1
adr: [0002, 0011]
depends_on: [T-001]
class: REVUE + MANDAT
github_issue: null
---
# T-068 — Sécurité et attribution des agents

## Intention
Compte dédié rôle Write, jetons fins sans admin, trailers d'attribution, journal des clients OpenChoreo ; entrées non fiables (issues, README amont, recettes) traitées comme données.

## Périmètre de fichiers
docs/AGENT-IDENTITY.md, .github/, platform/authz/

## Critères de fin
- [ ] identité agent créée par Paul (MANDAT)
- [ ] test : un agent ne peut pas fusionner une PR du noyau
- [ ] règle documentée contre l'injection de prompt
