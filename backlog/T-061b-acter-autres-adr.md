---
id: T-061b
title: "Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023, 0024) et les amendements du consensus n°2 (T-061b)"
status: done
phase: P0
adr: [0003, 0020, 0022, 0023, 0024]
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
# T-061b — Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023, 0024) et les amendements du consensus n°2 (T-061b)

## Intention
Acter, en parallèle du pilote, les ADR qui ne le conditionnent pas, avec les amendements homelab et ceux du consensus n°2.

## Périmètre de fichiers
docs/adr/, docs/architecture/

## Critères de fin
- [x] ADR 0001, 0003-0006, 0010-0013 et 0020 actés ou amendés
- [x] ADR-0022 (harness) et ADR-0023 (routage à 3 règles, alias, DeepSeek après le chantier) actés
- [x] amendements actés : ADR-0003 (CP sur le homelab, OKE optionnel), ADR-0020 (porte mono-cluster, C1-C7, horloge par voie, repli = report), ADR-0021 (prérequis du pilote, concurrence, pause d'Atlas, FINAL0) ; texte d'ADR-0017 amendé (acté avec T-218)
- [x] TARGET-ARCHITECTURE, MULTI-DATAPLANE, DECISIONS-OPEN (D1 reformulée, D11 tranchée, D12-D14) à jour
- [x] aucun ticket ne cite encore « Talos éteint la nuit » ou « CP sur OKE » comme prérequis
- [x] ADR-0024 (art antérieur et maintenabilité) acté ou amendé

## Notes
T-061b de la décision 3 (consensus n°2 et arbitrages de Paul, 2026-11-18). Ne bloque pas le pilote.

Done à la fusion de la PR #54 (acte les ADR 0001-0023 et amendements) (arbitrage Fable, 2026-11-18). Ne bloque plus le pilote : retiré des dépendances du pilote et de ses prérequis.

QA-0 fusionné (intégration 5, 2026-11-18) : le fichier docs/adr/0024-art-anterieur-maintenabilite.md existe (PROPOSÉ) ; il n'y a pas de ticket T-410.

Fait : ADR actés par la fusion de la PR #54 (2026-11-18).
