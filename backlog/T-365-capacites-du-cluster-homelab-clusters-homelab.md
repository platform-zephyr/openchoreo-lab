---
id: T-365
title: "Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno"
status: in-progress
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
- [x] un test par refus (arch absente, stockage absent) : `tests/appgen/test_capabilities_homelab.py` (classes `RefusalArchAbsent`, `RefusalStorageAbsent`), `python3 -m unittest discover -s tests/appgen` : 181 tests OK, 2026-11-18 (STATIC)
- [x] placement par défaut homelab (ADR-0003 §4) couvert par test : `DefaultPlacement` (`appgen.default_cluster` rend `homelab`, jamais `oke`, refuse sans politique valide) ; la CLI ne sélectionne pas encore le cluster par défaut (`app.schema.json` hors périmètre)
- [x] `availability: scheduled` refusé par le schéma des capacités (`enum: [always]`, test `RefusalAvailabilityScheduled`) ; `generated/` inchangé (`appgen check` : OK, aucune dérive, 82 fichiers)
- [ ] `docs/architecture/MULTI-DATAPLANE.md` §3 ne propose plus `availability: scheduled` (fichier hors périmètre de T-365)
- [ ] `app.schema.json` : `cluster` admet `homelab`, défaut `homelab`, `oke` seulement avec `placement.requestedBy` (ADR-0003 §4 et Vérification ; fichier hors périmètre de T-365)

## Notes
Proposé par la recherche `homelab` (clé HOME-5) ; intégration 2 du 2026-11-18.
