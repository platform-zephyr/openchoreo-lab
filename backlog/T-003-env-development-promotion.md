---
id: T-003
title: "Environment `development`, promotion vers `production`, pins de release par environnement"
status: todo
phase: P0
adr: [0004]
depends_on: [T-001, T-002]
class: AUTONOME
github_issue: 49
---
# T-003 — Environment `development`, promotion vers `production`, pins de release par environnement

## Intention
Deux Environments sur le même data plane ; `appgen promote <app>` épingle en production la release validée en dev (corrige G3).

## Périmètre de fichiers
platform/install/manifests/40-openchoreo-env.yaml, tools/appgen/, tests/appgen/

## Critères de fin
- [ ] tests appgen verts (pins par env, promote, rollback)
- [ ] CI k3d verte
- [ ] preuve OKE datée : une app A en development, release prod inchangée
- [ ] le bootstrap CI k3d n'invente plus `development` (suppression du `yq`)
