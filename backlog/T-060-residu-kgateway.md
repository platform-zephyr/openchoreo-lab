---
id: T-060
title: "Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)"
status: todo
phase: P0
adr: [0006]
depends_on: [T-001]
class: REVUE
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
