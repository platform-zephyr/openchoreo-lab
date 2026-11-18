---
id: T-022
title: "Spike OpenBao : placement, stockage, déscellement, sauvegarde"
status: todo
phase: P2
adr: [0014]
depends_on: [T-009]
class: AUTONOME + MANDAT
github_issue: null
---
# T-022 — Spike OpenBao : placement, stockage, déscellement, sauvegarde

## Intention
Qualifier OpenBao sur OKE : backend (PostgreSQL plateforme ou Raft), auto-unseal hors cluster, sauvegarde chiffrée hors Oracle, coût.

## Périmètre de fichiers
docs/storage/, platform/ (brouillon), tests/

## Critères de fin
- [ ] mesure CPU/mémoire
- [ ] auto-unseal prouvé sur k3d
- [ ] drill perte + restauration
- [ ] MANDAT Paul : clé d'auto-unseal, stockage des clés de récupération
