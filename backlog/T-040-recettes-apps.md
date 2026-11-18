---
id: T-040
title: "Catalogue de recettes d'apps homelab vérifiées"
status: todo
phase: P1
adr: [0013]
depends_on: [T-010, T-061, T-061b]
class: AUTONOME
velocity: false
lane: intention
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-040 — Catalogue de recettes d'apps homelab vérifiées

## Intention
Faits vérifiés pour les apps courantes (image multi-arch par digest, port, santé, OIDC, base, volume, classe suggérée).

## Périmètre de fichiers
recipes/, tools/, tests/

## Critères de fin
- [ ] format + 5 recettes
- [ ] CI : digest existant et arm64
