---
id: T-211
title: "Porte d'adoption OpenChoreo en mono-cluster : mesurer C1-C7 et décision de Paul (2026-12-04)"
status: todo
phase: P1
adr: [0020]
depends_on: [T-031, T-044, T-050, T-061, T-061b, T-212, T-364]
class: MANDAT
velocity: false
lane: gouvernance
stage: PORTE
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-211 — Porte d'adoption OpenChoreo en mono-cluster : mesurer C1-C7 et décision de Paul (2026-12-04)

## Intention
Rapport daté des critères C1-C7 (ADR-0020 amendé par l'arbitrage Fable) et décision adopter/abandonner, avec les règles en cas d'échec d'une voie. Seuils proposés par défaut, ajustables par Paul avant la mesure.

## Périmètre de fichiers
docs/review/, docs/adr/0020-porte-adoption-openchoreo.md

## Critères de fin
- [ ] décision de Paul consignée dans ADR-0020
- [ ] tickets `deferred` dégelés ou `dropped` selon la décision
- [ ] emplacement d'Authentik décidé par Paul (repris de T-213)
- [ ] D11 tranché le 2026-11-18 : CP sur la VM lab ; le rapport dit que la porte évalue OpenChoreo en mono-cluster (ADR-0020 amendé)
- [ ] C1 à C7 mesurés avec preuves
- [ ] C2 différentiel : surcoût d'OpenChoreo par rapport au plain sur la même VM ≤ 4 Gio de requests et ≤ 25 pods
- [ ] C4 « jour 2 » : montée d'un patch avec reconstruction du bundle amd64, et CP reconstruit depuis Git sur VM vide, apps Ready (T-031)
- [ ] C5 chiffré : « abandonner » si le plain passe la même suite `_checks` avec ≥ 30 % de lignes et de tickets propres au moteur en moins
- [ ] C6 : au moins 2 capacités d'OpenChoreo utilisées par les 5 intentions et absentes du plain (ex. release épinglée par environnement, cellule isolée par défaut, statut lu par API)
- [ ] C7 : part du catalogue kube-ops couverte (T-050), mesurée pour les deux moteurs ; défaut : OpenChoreo couvre au moins autant d'apps que le plain
- [ ] horloge par voie, en heures d'agent, depuis ses propres prérequis (OpenChoreo : T-364 `done` ; plain : T-363 `done`) ; l'attente d'un MANDAT n'est pas comptée
- [ ] ordre de mesure croisé : 3 intentions OpenChoreo d'abord, 2 plain d'abord ; banc T-044 exécuté pour les deux moteurs
- [ ] repli : si la VM lab n'est pas Ready le 2026-11-25, la porte est reportée (2026-12-11) ; jamais de mesure sur OKE

## Notes
Constats G1-G4 de la revue Fable, acceptés (arbitrage Fable, 2026-11-18) ; T-140 retiré des dépendances.
