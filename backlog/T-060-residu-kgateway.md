---
id: T-060
title: "Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)"
status: todo
phase: P2
adr: [0006]
depends_on: [T-001, T-061, T-061b]
class: REVUE
velocity: false
lane: socle-oke
stage: I2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-060 — Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)

## Intention
Fermer le résidu de moindre privilège accepté (STATE.md §1) avant tout credential réel.

## Périmètre de fichiers
platform/install/values/, tools/oke/, tests/

## Critères de fin
- [ ] `verify.sh` : B6-sa-effective PASS daté sur OKE
- [ ] test de non-régression en CI k3d
