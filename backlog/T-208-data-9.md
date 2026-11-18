---
id: T-208
title: "Gouvernance des données de mesure (classes, rétention, purge, pseudonymes)"
status: todo
phase: P2
adr: [0008, 0019]
depends_on: [T-025, T-061]
class: AUTONOME
velocity: false
lane: données
github_issue: null
---
# T-208 — Gouvernance des données de mesure (classes, rétention, purge, pseudonymes)

## Intention
Appliquer rétentions bronze 90 j, silver 400 j, gold 5 ans ; aucun prompt, secret ni donnée personnelle.

## Périmètre de fichiers
docs/data/METRICS-DATA-POLICY.md, tools/metrics/retention/

## Critères de fin
- [ ] test CI de scan des Parquet de test
- [ ] purge bronze/silver prouvée
- [ ] suppression gold = MANDAT documentée

## Notes
Proposé par la recherche `data-platform` (clé T-208).
