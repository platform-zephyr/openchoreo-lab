---
id: T-028
title: "Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth »"
status: todo
phase: P2
adr: [0010, 0009]
depends_on: [T-024, T-061]
class: AUTONOME
github_issue: null
---
# T-028 — Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth »

## Intention
Une app `public` avec auth est publiée sans geste ; sans auth, refus.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/

## Critères de fin
- [ ] CI : public sans auth → refus
- [ ] route par hôte rendue
- [ ] sonde externe : sans session → 302/403
