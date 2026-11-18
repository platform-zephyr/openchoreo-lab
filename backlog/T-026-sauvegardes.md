---
id: T-026
title: "Sauvegarde des bases : CNPG → R2 par préfixe"
status: todo
phase: P2
adr: [0008, 0009]
depends_on: [T-023, T-025, T-030]
class: AUTONOME + MANDAT
velocity: false
lane: donnees
github_issue: null
---
# T-026 — Sauvegarde des bases : CNPG → R2 par préfixe

## Intention
La plateforme choisit le mécanisme selon la classe ; spike VolSync/restic vs Velero/Kopia pour les volumes.

## Périmètre de fichiers
platform/resource-types/, tools/appgen/, docs/storage/

## Critères de fin
- [ ] WAL + base backup vers R2 hors Oracle
- [ ] jeton R2 hors cellule d'app ; bucket versionné ou object lock contre l'effacement
- [ ] `irreplaceable` : copie chiffrée côté client + vérification d'intégrité
- [ ] MANDAT Paul : jeton R2 limité au bucket (Tofu)
