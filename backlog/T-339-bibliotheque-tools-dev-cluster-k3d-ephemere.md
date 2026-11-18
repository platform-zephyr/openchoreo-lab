---
id: T-339
title: "Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins"
status: todo
phase: P0
adr: [0002, 0022]
depends_on: [T-002, T-061, T-216, T-332]
class: AUTONOME + REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-339 — Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins

## Intention
`cluster up|down --name pr-<n>` partagé par la CI (runner arm64) et la VM cloud (Docker x86_64) pour itérer ; cache des images ; nettoyage garanti (trap + job de balayage) ; le registre de suites décide quelles suites k3d lancer selon les chemins modifiés ; budget de temps et de RAM mesuré.

## Périmètre de fichiers
tools/dev/cluster, tests/registry.yaml, .github/workflows/k3d-integration.yml

## Critères de fin
- [ ] une PR `platform/` lance les suites k3d ; une PR `docs/` ne lance rien (deux runs datés)
- [ ] temps de bout en bout ≤ 15 min et RAM maximale mesurée, consignées
- [ ] aucun cluster ni conteneur résiduel après job échoué (cas négatif : arrêt forcé)

## Notes
La modification de .github/ exige l'approbation de Paul (REVUE). La preuve de référence des images reste le runner arm64.

Proposé par la recherche `harness` (clé HAR-9) ; intégration 2 du 2026-11-18.
