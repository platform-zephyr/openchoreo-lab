---
id: T-365
title: "Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno"
status: todo
phase: P0
adr: [0003]
depends_on: [T-214]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-365 — Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno

## Intention
Étendre le schéma (enum de clusters, arch amd64|arm64, availability always, gvisor proven|absent, profils) ; appgen refuse ce que le cluster ne déclare pas.

## Périmètre de fichiers
clusters/homelab/, docs/schema/capabilities.schema.json, tools/appgen/

## Critères de fin
- [ ] un test par refus (arch absente, stockage absent)
- [ ] placement par défaut homelab (ADR-0003 §4) couvert par test
- [ ] availability: scheduled supprimé du contrat

## Notes
Proposé par la recherche `homelab` (clé HOME-5) ; intégration 2 du 2026-11-18.
