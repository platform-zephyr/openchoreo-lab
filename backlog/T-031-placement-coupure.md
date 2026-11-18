---
id: T-031
title: "Règle de placement et test de coupure du homelab"
status: todo
phase: P1
adr: [0003]
depends_on: [T-030, T-061]
class: AUTONOME + MANDAT
velocity: false
lane: hybride
stage: S3
github_issue: null
---
# T-031 — Règle de placement et test de coupure du homelab

## Intention
L'agent place l'app selon ADR-0003 §4 ; une coupure homelab de 10 min ne casse ni le CP ni les apps.

## Périmètre de fichiers
tools/appgen/, .agents/skills/add-app/, tests/

## Critères de fin
- [ ] règle codée et testée
- [ ] preuve de coupure datée
- [ ] même app déplacée oke ↔ homelab par changement de `cluster`
