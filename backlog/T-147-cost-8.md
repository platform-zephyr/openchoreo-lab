---
id: T-147
title: "Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur"
status: todo
phase: P3
adr: [0011, 0017]
depends_on: [T-026, T-061, T-065, T-140]
class: AUTONOME + MANDAT
velocity: false
lane: alertes
stage: I4
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-147 — Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur

## Intention
Faire remonter vers T-065 les FAIL de cost-evidence et ajouter la règle de fraîcheur (absent_over_time) que billing.md de homelab-infra annonce ; la modification des règles Grafana se fait par une PR dans homelab-infra, par Paul.

## Périmètre de fichiers
docs/state/, contrat d'alerte (aucune écriture dans homelab-infra)

## Critères de fin
- [ ] chaque FAIL de coût crée une issue et une alerte ntfy avec la cause typée
- [ ] un collecteur muet depuis plus de 2 jours alerte
- [ ] proposition de PR homelab-infra décrite (règle, seuil), non appliquée ici

## Notes
MANDAT : l'écriture dans homelab-infra et tout jeton Grafana.

Proposé par la recherche `cost` (clé T-147).
