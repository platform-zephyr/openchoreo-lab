---
id: T-207
title: "Jauges bornées vers Grafana Cloud et alertes sur seuils d'objectif"
status: todo
phase: P3
adr: [0019]
depends_on: [T-065, T-206]
class: AUTONOME + MANDAT
velocity: false
lane: observabilité
github_issue: null
---
# T-207 — Jauges bornées vers Grafana Cloud et alertes sur seuils d'objectif

## Intention
Pousser quelques jauges (D1-D4, S1, niveau CNCF) en remote_write sous budget de séries ; alerter sur dérive.

## Périmètre de fichiers
apps/metrics-job/, règles d'alerte

## Critères de fin
- [ ] moins de 100 séries ajoutées
- [ ] jeton d'écriture via OpenBao, jamais dans Git

## Notes
MANDAT pour la création du jeton Grafana Cloud.

Proposé par la recherche `data-platform` (clé T-207).
