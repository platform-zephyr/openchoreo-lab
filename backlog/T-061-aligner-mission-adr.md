---
id: T-061
title: "Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote)"
status: done
phase: P0
adr: [0002, 0021]
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
# T-061 — Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote)

## Intention
Acter le minimum qui autorise le pilote : ADR-0002 (avec la sécurité de dev et l'étape FINAL) et ADR-0021 réduit (règle d'usine, paliers, liste figée, PAUSE). Lever les contradictions de MISSION et STATE.

## Périmètre de fichiers
missions/MISSION.md, AGENTS.md, STATE.md, docs/adr/0002-autonomie-des-agents.md, docs/adr/0021-usine-agents-24-7.md, docs/adr/README.md

## Critères de fin
- [x] ADR-0002 (amendement « sécurité de dev, sécurité finale ») et ADR-0021 réduit actés par Paul
- [x] MISSION.md réaligné : homelab par défaut, CP OpenChoreo sur le homelab (D11), OKE sur demande, interdits réécrits en classes, critère « plateforme finie » = étape FINAL `done`
- [x] STATE.md : homelab par défaut, chiffres du backlog à jour, consensus n°2 cité ; AGENTS.md sans contradiction
- [x] MISSION.md et STATE.md : A1 = 2/12, plus de « 4/24 »

## Notes
T-061a de la décision 3 (consensus n°2 et arbitrages de Paul, 2026-11-18). Le reste de l'ancien T-061 est dans T-061b, en parallèle du pilote.

Done à la fusion de la PR #54 (acte les ADR 0001-0023 et amendements) (arbitrage Fable, 2026-11-18). Ne bloque plus le pilote : retiré des dépendances du pilote et de ses prérequis.

Fait : ADR actés par la fusion de la PR #54 (2026-11-18).
