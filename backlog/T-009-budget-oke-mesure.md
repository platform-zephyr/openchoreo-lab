---
id: T-009
title: "Estimer le budget OKE et tenir le registre des quotas gratuits"
status: todo
phase: P0
adr: [0003, 0004]
depends_on: [T-001]
class: AUTONOME
github_issue: null
---
# T-009 — Estimer le budget OKE et tenir le registre des quotas gratuits

## Intention
Estimation initiale de ce qui tient sur le nœud A1 (seuil 70 %) et registre des quotas Always Free (volumes, IP, LB) avec contrôle périodique. Les composants futurs sont re-mesurés dans leur propre ticket.

## Périmètre de fichiers
tools/oke/verify.sh (lecture), docs/

## Critères de fin
- [ ] mesure datée (requests, usage, pods, IP)
- [ ] tableau : composant → cluster recommandé
- [ ] registre des quotas gratuits (volumes orphelins, disque de boot) et contrôle périodique
