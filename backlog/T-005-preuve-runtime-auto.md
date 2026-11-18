---
id: T-005
title: "Preuve runtime automatique après sync (Job PostSync + publication)"
status: todo
phase: P0
adr: [0011]
depends_on: [T-061, T-061b, T-072, T-487, T-489]
class: AUTONOME + REVUE + MANDAT
velocity: true
lane: preuve
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: 51
---
# T-005 — Preuve runtime automatique après sync (Job PostSync + publication)

## Intention
Après chaque sync Argo, un Job PostSync exécute les checks de l'archétype et rend la santé de l'app ; Argo CD Notifications (amont) publie un check run par app et par révision, avec le résumé `app-status.v1`, sous l'identité de T-489.

## Périmètre de fichiers
platform/ (Job PostSync, SA lecture), golden-paths/_checks/, tools/, tests/

## Critères de fin
- [ ] k3d CI : PASS puis FAIL volontaire typé
- [ ] preuve runtime datée sur OKE vierge (T-487) : check run `success` puis `failure` volontaire publié pour une app témoin, sans coordinateur
- [ ] les Applications du bras K (`lab-k-*`) publient par le même gabarit de check run
- [ ] Job ≤ 50m / 64Mi, se termine
- [ ] (repris de T-105) lab_app_status{app,env,verdict,cause_type} visible dans Grafana après un FAIL volontaire (k3d et OKE)
- [ ] (repris de T-105) Job ≤ 50m / 64Mi (critère T-005 conservé)

## Notes
Publication du statut de commit = jeton GitHub (MANDAT). RBAC de lecture à valider contre `argo_guard` (REVUE). Egress de la cellule vers l'API GitHub à déclarer. Supprime le goulot « coordinateur + bastion » pour les apps.

Avancé sur OKE (ADR-0025, 2026-11-18) : T-364 remplacé par T-487 ; la preuve sur le cluster lab revient avec T-364 en porte 2.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Accéléré (arbitrages de Paul n°3, 2026-11-18) : publication par Argo CD Notifications et l'App `openchoreo-status` (T-489) au lieu d'un Job qui détient un jeton ; plus d'identité de Paul. T-003 retiré des dépendances (la preuve ne dépend pas de la promotion ; M3 la demande, via T-486).
