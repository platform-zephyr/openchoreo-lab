---
id: T-205
title: "Spike Garage sur le homelab (objet S3, volume, sauvegarde R2)"
status: deferred
phase: P5
adr: [0008, 0019]
depends_on: [T-025, T-026, T-030]
class: AUTONOME + MANDAT
velocity: false
lane: homelab
stage: après-porte
github_issue: null
---
# T-205 — Spike Garage sur le homelab (objet S3, volume, sauvegarde R2)

## Intention
Mesurer RAM, CPU, disque de Garage ; comparer SeaweedFS ; copier le gold chiffré vers R2.

## Périmètre de fichiers
apps/data-store/app.yaml, docs/research/

## Critères de fin
- [ ] mesures datées
- [ ] restauration du bucket prouvée
- [ ] décision Garage vs alternative

## Notes
MANDAT pour les clés R2. Archétype exact à confirmer (T-014 si chart).

Proposé par la recherche `data-platform` (clé T-205).

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
