---
id: T-028
title: "Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth »"
status: todo
phase: P2
adr: [0010, 0009]
depends_on: [T-061, T-061b, T-189, T-404]
class: AUTONOME
velocity: false
lane: exposition
stage: I3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
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
- [ ] v1 : application Access wildcard (Tofu, une fois) + routes déclarées

## Notes
Dépend du jalon FINAL0 (T-404) (arbitrage Fable, 2026-11-18) : crée une donnée réelle, une identité réelle ou une exposition publique.
