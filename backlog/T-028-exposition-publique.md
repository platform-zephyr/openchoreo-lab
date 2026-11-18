---
id: T-028
title: "Exposition `private | internal | public` : route par hôte (G6) et Access par app"
status: todo
phase: P2
adr: [0010, 0009]
depends_on: [T-029]
class: AUTONOME
github_issue: null
---
# T-028 — Exposition `private | internal | public` : route par hôte (G6) et Access par app

## Intention
Une app `public` avec auth est publiée sans geste ; sans auth, refus.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/

## Critères de fin
- [ ] CI : public sans auth → refus
- [ ] sonde externe : sans session → 302/403
- [ ] `git revert` retire la publication
