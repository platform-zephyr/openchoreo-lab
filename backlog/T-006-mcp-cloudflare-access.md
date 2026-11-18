---
id: T-006
title: "Accès des agents cloud à la plateforme du homelab : lecture MCP/API OpenChoreo et statut des apps (lecture seule)"
status: todo
phase: P0
adr: [0010, 0007]
depends_on: [T-061, T-061b, T-364]
class: REVUE + MANDAT
velocity: false
lane: acces-mcp
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 52
---
# T-006 — Accès des agents cloud à la plateforme du homelab : lecture MCP/API OpenChoreo et statut des apps (lecture seule)

## Intention
Les sessions cloud et les runners lisent l'état de la plateforme du homelab sans kubeconfig : (a) MCP/API OpenChoreo derrière le Cloudflare Tunnel + Access déjà présents côté homelab (kube-ops), service token Access et client `openchoreo-agent-reader` ; ou (b) statut des apps publié dans GitHub par la preuve automatique (T-005). Lecture seule dans les deux cas.

## Périmètre de fichiers
docs/CLOUD-AGENTS.md, docs/AGENT-RUNNERS.md, platform/ (NetworkPolicy tunnel → MCP), tests/mcp/, PR cross-dépôt kube-ops (route du tunnel, application Access)

## Critères de fin
- [ ] décision (a), (b) ou les deux, écrite dans docs/CLOUD-AGENTS.md avec le risque de chaque voie
- [ ] NetworkPolicy : seul le namespace du tunnel atteint le port MCP (si (a))
- [ ] depuis une session cloud et un runner : lecture OK, sans service token → refus, écriture → refus (preuve datée)
- [ ] aucune écriture cluster possible par ce chemin (test négatif)
- [ ] MANDAT Paul : application Access et service token (côté kube-ops), client Authentik, secret réseau de l'environnement cloud (formulaire, jamais dans le chat)

## Notes
Inclure le déploiement/réglage de cloudflared et sa NetworkPolicy. Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête est une hypothèse à prouver, sinon prévoir un relais.

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).

Dégelé et élargi (consensus n°2 et arbitrages de Paul, 2026-11-18) (arbitrage 2) : même sujet que le nouveau ticket « accès des agents cloud ». Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête reste à prouver, sinon prévoir un relais.
