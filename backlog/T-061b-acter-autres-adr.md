---
id: T-061b
title: "Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023) et les amendements du consensus n°2 (T-061b)"
status: todo
phase: P0
adr: [0003, 0020, 0022, 0023]
depends_on: []
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-061b — Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023) et les amendements du consensus n°2 (T-061b)

## Intention
Acter, en parallèle du pilote, les ADR qui ne le conditionnent pas, avec les amendements homelab et ceux du consensus n°2.

## Périmètre de fichiers
docs/adr/, docs/architecture/

## Critères de fin
- [ ] ADR 0001, 0003-0006, 0010-0013 et 0020 actés ou amendés
- [ ] ADR-0022 (harness) et ADR-0023 (routage à 3 règles, alias, DeepSeek après le chantier) actés
- [ ] amendements actés : ADR-0003 (CP sur le homelab, OKE optionnel), ADR-0020 (porte mono-cluster, horloge à T-363 `done`, repli le 2026-11-25) ; texte d'ADR-0017 amendé (acté avec T-218)
- [ ] TARGET-ARCHITECTURE, MULTI-DATAPLANE, DECISIONS-OPEN (D1 reformulée, D11 tranchée, D12-D14) à jour
- [ ] aucun ticket ne cite encore « Talos éteint la nuit » ou « CP sur OKE » comme prérequis

## Notes
T-061b de la décision 3 (consensus n°2 et arbitrages de Paul, 2026-11-18). Ne bloque pas le pilote.
