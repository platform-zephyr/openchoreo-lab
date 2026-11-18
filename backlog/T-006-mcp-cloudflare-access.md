---
id: T-006
title: "Surface de lecture des agents cloud : check runs dans GitHub et MCP OpenChoreo en lecture seule derrière Cloudflare Tunnel + Access"
status: todo
phase: P0
adr: [0010, 0007, 0025]
depends_on: [T-005]
class: REVUE + MANDAT
velocity: true
lane: acces-mcp
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: 52
---
# T-006 — Surface de lecture des agents cloud (check runs + MCP derrière Tunnel + Access)

## Intention
Les sessions cloud et l'usine lisent l'état des apps sans kubeconfig, sans bastion et sans le compte de Paul : (1) les check runs publiés par T-005 et T-489, lus par l'API GitHub ; (2) le MCP OpenChoreo en lecture seule (rôle reader de `platform/authz/`) derrière Cloudflare Tunnel + Access, sur OKE d'abord, puis le homelab après revue. L'apiserver n'est jamais exposé ; aucune écriture par cette surface (`docs/research/POC-OPENCHOREO-STRATEGY.md` §4bis).

## Périmètre de fichiers
docs/CLOUD-AGENTS.md, platform/cloudflared/, tests/mcp/, tools/status/, tests/status/, docs/state/identities.yaml

## Critères de fin
- [ ] check run d'une app lu depuis une session cloud par l'API GitHub, sans identifiant de Paul (preuve datée)
- [ ] `cloudflared` livré par Git dans un namespace `lab-*` ; NetworkPolicy : seul ce namespace joint le port du MCP ; l'ingress du tunnel ne route que le MCP et le point de jeton reader (test négatif : l'apiserver et Argo ne répondent pas par l'hôte public)
- [ ] MANDAT Paul : application Access en `Service Auth` seulement (aucun « Allow everyone », aucun bypass) et un service token par identité d'agent (sessions cloud, usine), créés côté homelab-infra ; noms inscrits au registre, jamais de valeur
- [ ] injection du service token en un seul en-tête par le proxy de l'environnement cloud (network secret) prouvée, ou relais documenté ; NOT_TESTED tant que non joué
- [ ] `tests/mcp/` rejoué sur OKE par l'hôte public : 401 sans jeton Access, 401 sans JWT, reader sans outil d'écriture ni SecretReference (preuve datée, niveau RUNTIME OKE)
- [ ] journal d'accès : une requête de test retrouvée dans le journal Access et dans l'`ACCESS-LOG` d'`openchoreo-api` ; rotation des service tokens rattachée à T-194
- [ ] `docs/CLOUD-AGENTS.md` : voie retenue, liste des hôtes à autoriser dans l'environnement cloud (GitHub, hôte MCP, hôte du jeton reader, registres de paquets), et pourquoi l'apiserver n'est pas exposé

## Notes
Recadré (contribution de Paul du 2026-11-18, arbitrage n°3) : la surface MCP + Access revient avant la porte, en lecture seule et hors chemin critique du banc (le banc garde le même canal pour les deux bras : les check runs). Reprend la décision « MCP joignable par Cloudflare Tunnel + Access, exception unique » et `docs/CLOUD-AGENTS.md` §3. Annule la limitation à l'option (b) de l'arbitrage Fable.

Historique : différé après la porte (ADR-0020), dégelé par le consensus n°2 (arbitrage 2), limité à l'option (b) par l'arbitrage Fable (constat G2). Access exige normalement deux en-têtes de service token : l'injection en un seul en-tête est à prouver, sinon prévoir un relais.

Exposition publique nouvelle : MANDAT (journal de homelab-infra, D-2026-11-16-07). Cluster jetable et sans donnée : une fuite de jeton expose une lecture d'état sans secret. Extension au homelab seulement après la revue de sécurité de FINAL0.
