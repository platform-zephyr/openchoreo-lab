---
id: T-020
title: "Kyverno en Enforce sur le golden path, exceptions générées"
status: todo
phase: P2
adr: [0006]
depends_on: [T-002, T-009]
class: AUTONOME
github_issue: null
---
# T-020 — Kyverno en Enforce sur le golden path, exceptions générées

## Intention
Porter les règles Deny du golden path kube-ops ; `securityExceptions` → PolicyException générée.

## Périmètre de fichiers
platform/kyverno/, tests/kyverno/, tools/appgen/

## Critères de fin
- [ ] suites de refus en CI k3d
- [ ] homelab : Enforce ; OKE : selon T-009 (sinon VAP seules)
- [ ] namespaces plateforme exclus, restauration non bloquée
