---
id: T-026
title: "Sauvegarde des bases : CNPG → R2 par préfixe"
status: todo
phase: P2
adr: [0008, 0009]
depends_on: [T-025, T-061, T-364]
class: AUTONOME + MANDAT
velocity: false
lane: donnees
stage: I1
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
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
- [ ] (repris de T-143) mesure datée par bucket publiée en cost-evidence.v1
- [ ] (repris de T-143) alerte ntfy à 7 Go et à 70 % des opérations estimées
- [ ] (repris de T-143) règle de lifecycle (WAL, versions non courantes) proposée par PR, sans supprimer de donnée sans restauration prouvée
- [ ] mots de passe de bases par rôles gérés CNPG (sans Doppler ni OpenBao)
- [ ] test de restauration : les mots de passe des rôles gérés CNPG sont réalignés après restauration (non documenté en amont, à prouver avant de s'y fier)
