---
id: T-005
title: "Preuve runtime automatique après sync et statut `app-status.v1`"
status: todo
phase: P0
adr: [0011]
depends_on: [T-003]
class: AUTONOME
github_issue: 51
---
# T-005 — Preuve runtime automatique après sync et statut `app-status.v1`

## Intention
Après chaque sync Argo, un Job lit l'état et exécute les checks de l'archétype, puis publie un `app-status.v1` daté (statut de commit + lisible par MCP).

## Périmètre de fichiers
platform/ (Job PostSync, SA lecture), golden-paths/_checks/, tools/, tests/

## Critères de fin
- [ ] schéma `app-status.v1` versionné (repris de kube-ops)
- [ ] `_checks` en sortie JSON stable
- [ ] k3d CI : PASS puis FAIL volontaire typé
- [ ] preuve OKE datée sans coordinateur
- [ ] Job ≤ 50m / 64Mi, se termine

## Notes
Supprime le goulot « coordinateur + bastion » pour les apps.
