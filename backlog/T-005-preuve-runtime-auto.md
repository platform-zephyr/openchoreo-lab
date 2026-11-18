---
id: T-005
title: "Preuve runtime automatique après sync (Job PostSync + publication)"
status: todo
phase: P0
adr: [0011]
depends_on: [T-003, T-061, T-061b, T-072, T-487]
class: AUTONOME + REVUE + MANDAT
velocity: true
lane: preuve
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 51
---
# T-005 — Preuve runtime automatique après sync (Job PostSync + publication)

## Intention
Après chaque sync Argo, un Job lit l'état et exécute les checks de l'archétype, puis publie un `app-status.v1` daté (statut de commit + lisible par MCP).

## Périmètre de fichiers
platform/ (Job PostSync, SA lecture), golden-paths/_checks/, tools/, tests/

## Critères de fin
- [ ] k3d CI : PASS puis FAIL volontaire typé
- [ ] preuve runtime datée sur OKE réinitialisé (T-487), sans coordinateur, pour les bras O et K du banc A/B
- [ ] le même Job publie le statut des apps du bras K (`lab-k-*`) au même format `app-status.v1`
- [ ] Job ≤ 50m / 64Mi, se termine
- [ ] (repris de T-105) lab_app_status{app,env,verdict,cause_type} visible dans Grafana après un FAIL volontaire (k3d et OKE)
- [ ] (repris de T-105) Job ≤ 50m / 64Mi (critère T-005 conservé)

## Notes
Publication du statut de commit = jeton GitHub (MANDAT). RBAC de lecture à valider contre `argo_guard` (REVUE). Egress de la cellule vers l'API GitHub à déclarer. Supprime le goulot « coordinateur + bastion » pour les apps.

Avancé sur OKE (ADR-0025, 2026-11-18) : T-364 remplacé par T-487 ; la preuve sur le cluster lab revient avec T-364 en porte 2.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.
