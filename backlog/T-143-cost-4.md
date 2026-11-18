---
id: T-143
title: "Mesure R2 : Go, objets et opérations par bucket, alerte avant 10 Go"
status: todo
phase: P2
adr: [0008, 0009, 0017]
depends_on: [T-026, T-140]
class: AUTONOME + MANDAT
velocity: false
lane: sauvegardes
github_issue: null
---
# T-143 — Mesure R2 : Go, objets et opérations par bucket, alerte avant 10 Go

## Intention
R2 n'a pas d'API de facture lisible : compter Go et objets par bucket avec la clé reader existante, estimer les opérations classe A (WAL, restic) et définir lifecycle/expiration pour rester sous 10 Go et 1 M d'opérations.

## Périmètre de fichiers
tools/cost/r2_usage.py, platform/ (CronJob homelab), docs/storage/

## Critères de fin
- [ ] mesure datée par bucket publiée en cost-evidence.v1
- [ ] alerte ntfy à 7 Go et à 70 % des opérations estimées
- [ ] règle de lifecycle (WAL, versions non courantes) proposée par PR, sans supprimer de donnée sans restauration prouvée

## Notes
MANDAT : toute règle de suppression ou jeton R2. Verrous de bucket et rétention gonflent le stockage.

Proposé par la recherche `cost` (clé T-143).
