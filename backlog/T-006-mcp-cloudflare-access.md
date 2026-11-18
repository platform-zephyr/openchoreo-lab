---
id: T-006
title: "MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz)"
status: deferred
phase: P5
adr: [0010, 0007]
depends_on: [T-001, T-060]
class: REVUE + MANDAT
velocity: false
lane: acces-mcp
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: 52
---
# T-006 — MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz)

## Intention
Lecture MCP depuis une session cloud avec double contrôle : service token Access et client `openchoreo-agent-reader`.

## Périmètre de fichiers
platform/ (NetworkPolicy tunnel → MCP), docs/CLOUD-AGENTS.md, tests/mcp/

## Critères de fin
- [ ] NetworkPolicy : seul le namespace du tunnel atteint le port MCP
- [ ] depuis une session cloud : lecture OK, sans token Access → refus, écriture → refus (preuve datée)
- [ ] MANDAT Paul : hôte, application Access, service token, client Authentik, network secrets de l'environnement cloud

## Notes
Inclure le déploiement/réglage de cloudflared et sa NetworkPolicy. Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête est une hypothèse à prouver, sinon prévoir un relais.

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
