---
id: T-006
title: "Accès des agents cloud au statut des apps du homelab : statut publié dans GitHub, lu par l'API GitHub (lecture seule)"
status: todo
phase: P0
adr: [0010, 0007]
depends_on: [T-005]
class: AUTONOME
velocity: false
lane: acces-mcp
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 52
---
# T-006 — Accès des agents cloud au statut des apps du homelab : statut publié dans GitHub, lu par l'API GitHub (lecture seule)

## Intention
Les sessions cloud et les runners lisent l'état des apps du homelab sans kubeconfig ni accès réseau au homelab : la preuve automatique (T-005) publie le statut dans GitHub (statut de commit ou check), lu par l'API GitHub. Pas de Tunnel, d'Access ni de MCP exposé avant la porte.

## Périmètre de fichiers
docs/CLOUD-AGENTS.md, tools/status/, tests/status/

## Critères de fin
- [ ] statut `app-status.v1` publié dans GitHub par la preuve automatique, lisible depuis une session cloud par l'API GitHub (preuve datée)
- [ ] aucune écriture cluster ni accès réseau au homelab par ce chemin (test négatif)
- [ ] docs/CLOUD-AGENTS.md : voie retenue ; MCP derrière Tunnel + Access différé après la porte

## Notes
Inclure le déploiement/réglage de cloudflared et sa NetworkPolicy. Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête est une hypothèse à prouver, sinon prévoir un relais.

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).

Dégelé et élargi (consensus n°2 et arbitrages de Paul, 2026-11-18) (arbitrage 2) : même sujet que le nouveau ticket « accès des agents cloud ». Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête reste à prouver, sinon prévoir un relais.

Limité à l'option (b) (arbitrage Fable, 2026-11-18) (constat G2) : plus de MANDAT ; la voie MCP/Access reviendra après la porte, avec FINAL0.
