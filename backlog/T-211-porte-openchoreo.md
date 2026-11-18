---
id: T-211
title: "Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04)"
status: todo
phase: P1
adr: [0020]
depends_on: [T-031, T-044, T-061, T-140, T-212, T-364]
class: MANDAT
velocity: false
lane: gouvernance
stage: PORTE
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-211 — Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04)

## Intention
Rapport daté des critères C1-C5 et décision adopter/abandonner (ADR-0020), avec les règles en cas d'échec d'une voie.

## Périmètre de fichiers
docs/review/, docs/adr/0020-porte-adoption-openchoreo.md

## Critères de fin
- [ ] C1 à C5 mesurés avec preuves
- [ ] décision de Paul consignée dans ADR-0020
- [ ] tickets `deferred` dégelés ou `dropped` selon la décision
- [ ] C1, C2 et C4 mesurés sur le cluster lab selon ADR-0020 amendé (T-061)
- [ ] D11 : Paul décide l'emplacement définitif du CP (lab ou OKE) ; le backlog ne le tranche pas
- [ ] emplacement d'Authentik décidé par Paul (repris de T-213)
