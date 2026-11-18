---
id: T-210
title: "Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins)"
status: todo
phase: P0
adr: [0002, 0012, 0013]
depends_on: [T-008, T-061]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-210 — Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins)

## Intention
Calculer les tickets prêts (dépendances `done`, étape ouverte, aucun geste humain en attente), recalculer classe et modèle depuis les chemins du périmètre, et sortir une liste que Paul lance à la main pendant le pilote.

## Périmètre de fichiers
tools/backlog/next.py, tools/backlog/admission.py, tests/backlog/

## Critères de fin
- [ ] next.py liste prêts et débloqués, sortie JSON stable (`ready.v1`)
- [ ] classe recalculée depuis les chemins touchés, jamais lue de l'en-tête ; un chemin du noyau force REVUE (test)
- [ ] la liste à lancer reste fournie par Paul (workflow_dispatch) ; next.py ne lance rien
- [ ] modèle et effort recalculés depuis les chemins du périmètre (3 règles d'ADR-0023) ; un `model:` d'en-tête sous le plancher est ignoré (test)

## Notes
Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.

Intégration 2 : absorbe FAC-3 et HAR-5. Le lancement (workflow_dispatch, preuve de 3 PR parallèles) passe à T-313.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-007, T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Version minimale (consensus n°2 et arbitrages de Paul, 2026-11-18) : l'admission (couloirs, chevauchement, ressources exclusives, gouverneur, plafond) passe au dispatcher planifié T-314.
