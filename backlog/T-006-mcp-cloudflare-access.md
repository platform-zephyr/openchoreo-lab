---
id: T-006
title: "MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz)"
status: todo
phase: P0
adr: [0010, 0007]
depends_on: [T-001]
class: REVUE + MANDAT
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
Vérifier : service token en un seul en-tête ; JWT reader par client_credentials injecté par le proxy.
