---
id: T-023
title: "Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing`"
status: todo
phase: P2
adr: [0014, 0011]
depends_on: [T-022, T-005, T-060]
class: AUTONOME + REVUE + MANDAT
github_issue: null
---
# T-023 — Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing`

## Intention
Aucun secret applicatif posé à la main avant déploiement ; un secret tiers manquant donne BLOCKED typé.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/, tests/

## Critères de fin
- [ ] k3d : app `generate` démarre sans geste, valeur stable après recréation du namespace
- [ ] app `provided` BLOCKED puis Ready
- [ ] agents sans lecture de valeur (test de politique)
- [ ] CI : aucune cellule d'app ne référence le store Doppler
