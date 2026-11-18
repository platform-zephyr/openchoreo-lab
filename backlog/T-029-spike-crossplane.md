---
id: T-029
title: "Spike Crossplane sur le homelab (provider Cloudflare pour Access)"
status: blocked
phase: P5
adr: [0009]
depends_on: [T-030, T-061, T-140]
class: AUTONOME + MANDAT
velocity: false
lane: exposition
stage: après-porte
github_issue: null
---
# T-029 — Spike Crossplane sur le homelab (provider Cloudflare pour Access)

## Intention
Qualifier un provider Cloudflare maintenu, `deletionPolicy: Orphan`, coût ; sinon repli Tofu via ARC.

## Périmètre de fichiers
docs/, platform/ (brouillon homelab)

## Critères de fin
- [ ] provider choisi ou rejeté avec preuves
- [ ] app `public` → application Access créée, `git revert` → retirée
- [ ] MANDAT Paul : jeton Cloudflare limité à Access

## Notes
Crossplane en `lab-*` sur le homelab. Les CR générées par appgen sont appliquées par l'Argo du homelab dans un projet borné à ces CR (ADR-0003 §6 amendé). Re-mesure CPU/mémoire datée.

Bloqué par : déclencheur ADR-0009 §6 non atteint.
