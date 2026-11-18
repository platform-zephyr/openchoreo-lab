---
id: T-367
title: "Runners ARC sur le cluster lab pour la CI du dépôt (sans Docker, éphémères)"
status: blocked
phase: P5
adr: [0002, 0017]
depends_on: [T-061, T-215, T-311, T-343, T-363]
class: REVUE + MANDAT
velocity: true
lane: agents
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-367 — Runners ARC sur le cluster lab pour la CI du dépôt (sans Docker, éphémères)

## Intention
Scale set ARC éphémère pour les jobs qui lisent le cluster lab (preuve runtime PostSync, kubeconform, Kyverno CLI) ; k3d reste sur les runners GitHub (T-002). Dépôt public : jamais de PR de fork sur un runner auto-hébergé.

## Périmètre de fichiers
platform/lab-runners/, .github/workflows/

## Critères de fin
- [ ] runners éphémères, GitHub App à portée minimale, groupe limité aux branches du dépôt, aucun secret de production monté
- [ ] plafond de concurrence et cpulimit ; arrêt si Tctl > seuil
- [ ] test : une PR de fork ne démarre aucun job sur le runner

## Notes
Risque principal : exécution de code de PR sur le matériel domestique. MANDAT : GitHub App et groupe de runners.

Proposé par la recherche `homelab` (clé HOME-7) ; intégration 2 du 2026-11-18.

Bloqué par : décision (b) de T-343 (runners ARC) ; par défaut (a) aucun runner homelab sur un dépôt public.

(consensus n°2 et arbitrages de Paul, 2026-11-18) : bloqué jusqu'à T-343 ; règle d'admission = push/dispatch de mainteneurs, jamais PR de fork (arbitrage 6).
