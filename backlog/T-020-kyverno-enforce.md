---
id: T-020
title: "Kyverno en Enforce sur le golden path, exceptions générées"
status: todo
phase: P2
adr: [0006]
depends_on: [T-002, T-061, T-061b, T-364]
class: AUTONOME
velocity: false
lane: securite
stage: I3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-020 — Kyverno en Enforce sur le golden path, exceptions générées

## Intention
Porter les règles Deny du golden path kube-ops ; `securityExceptions` → PolicyException générée.

## Périmètre de fichiers
platform/kyverno/, tests/kyverno/, tools/appgen/

## Critères de fin
- [ ] suites de refus en CI k3d
- [ ] installé en `lab-*` ; homelab : Enforce
- [ ] OKE seulement si Kyverno ≤ 400 Mi de requests et total < 70 % (re-mesure datée), sinon VAP seules
- [ ] namespaces plateforme exclus, restauration non bloquée
