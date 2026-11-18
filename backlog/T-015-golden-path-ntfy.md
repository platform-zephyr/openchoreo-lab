---
id: T-015
title: "Golden path n°2 (ntfy interne) : development puis production"
status: todo
phase: P1
adr: [0004, 0011]
depends_on: [T-003, T-005]
class: AUTONOME
velocity: false
lane: apps
github_issue: 53
---
# T-015 — Golden path n°2 (ntfy interne) : development puis production

## Intention
Premier cycle complet du modèle : dev, preuve auto, promotion, rollback.

## Périmètre de fichiers
apps/ntfy/, generated/**, lab-apps.yaml

## Critères de fin
- [ ] dev : PASS daté automatique
- [ ] promotion par PR, PASS en production
- [ ] rollback par `git revert` prouvé
