---
id: T-005
title: "Preuve runtime automatique après sync (Job PostSync + publication)"
status: todo
phase: P0
adr: [0011]
depends_on: [T-072, T-003]
class: AUTONOME + REVUE + MANDAT
github_issue: 51
---
# T-005 — Preuve runtime automatique après sync (Job PostSync + publication)

## Intention
Après chaque sync Argo, un Job lit l'état et exécute les checks de l'archétype, puis publie un `app-status.v1` daté (statut de commit + lisible par MCP).

## Périmètre de fichiers
platform/ (Job PostSync, SA lecture), golden-paths/_checks/, tools/, tests/

## Critères de fin
- [ ] k3d CI : PASS puis FAIL volontaire typé
- [ ] preuve OKE datée sans coordinateur
- [ ] Job ≤ 50m / 64Mi, se termine

## Notes
Publication du statut de commit = jeton GitHub (MANDAT). RBAC de lecture à valider contre `argo_guard` (REVUE). Egress de la cellule vers l'API GitHub à déclarer. Supprime le goulot « coordinateur + bastion » pour les apps.
