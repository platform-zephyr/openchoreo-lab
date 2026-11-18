---
id: T-063
title: "Reprise après sinistre de la plateforme : runbook de reconstruction et drill"
status: deferred
phase: P5
adr: [0008, 0003]
depends_on: [T-022, T-062]
class: AUTONOME + MANDAT
velocity: false
lane: exploitation
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-063 — Reprise après sinistre de la plateforme : runbook de reconstruction et drill

## Intention
Reconstruire OKE de zéro : CA du cluster-gateway et mTLS des data planes, Argo, ESO, OpenBao, objets OpenChoreo, bundle privé ; RTO mesuré.

## Périmètre de fichiers
docs/runbooks/, tests/

## Critères de fin
- [ ] runbook ordonné avec RTO
- [ ] drill complet sur k3d en CI ou manuel daté
- [ ] liste des secrets racines nécessaires (Doppler) sans valeurs

## Notes
Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
