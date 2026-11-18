---
id: T-340
title: "Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket`"
status: todo
phase: P0
adr: [0022]
depends_on: [T-061, T-210, T-337]
class: AUTONOME
velocity: true
lane: agents-harness
stage: S1
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-340 — Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket`

## Intention
Fixer : PR brouillon dès le premier jalon comme journal (champs STE80), push WIP à chaque jalon, `max_attempts: 2`, classes d'échec (CI rouge, hors périmètre, outil indisponible, ambiguïté), passage à `blocked` avec `Bloqué par :`. `session-start` imprime ticket, branche, dernier CI, git log, critères restants ; le skill reprend une tentative interrompue (VM expirée, quota, SIGTERM).

## Périmètre de fichiers
docs/AGENT-RUN-PROTOCOL.md, .agents/skills/resume-ticket/, tools/dev/session-start

## Critères de fin
- [ ] essai : une session interrompue en cours de ticket est reprise par un autre agent sans intervention humaine (preuve datée)
- [ ] une 2e tentative échouée produit `blocked` et un commentaire de PR au format STE80
- [ ] le protocole tient en 60 lignes ou moins

## Notes
Les processus en arrière-plan ne survivent pas à l'expiration d'une VM cloud ; seuls l'historique et la branche poussée comptent.

Proposé par la recherche `harness` (clé HAR-10) ; intégration 2 du 2026-11-18.
