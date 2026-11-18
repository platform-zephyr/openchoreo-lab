---
id: T-026
title: "Sauvegardes : CNPG → R2 par préfixe, mécanisme unique pour les volumes"
status: todo
phase: P2
adr: [0008, 0009]
depends_on: [T-025]
class: AUTONOME + MANDAT
github_issue: null
---
# T-026 — Sauvegardes : CNPG → R2 par préfixe, mécanisme unique pour les volumes

## Intention
La plateforme choisit le mécanisme selon la classe ; spike VolSync/restic vs Velero/Kopia pour les volumes.

## Périmètre de fichiers
platform/resource-types/, tools/appgen/, docs/storage/

## Critères de fin
- [ ] base : WAL + base backup vers R2 hors Oracle
- [ ] volume : mécanisme choisi et mesuré
- [ ] MANDAT Paul : jeton R2 limité au bucket (Tofu)
