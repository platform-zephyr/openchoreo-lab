---
id: T-029
title: "Spike Crossplane sur le homelab (provider Cloudflare pour Access)"
status: todo
phase: P2
adr: [0009]
depends_on: [T-030]
class: AUTONOME + MANDAT
github_issue: null
---
# T-029 — Spike Crossplane sur le homelab (provider Cloudflare pour Access)

## Intention
Qualifier un provider Cloudflare maintenu, `deletionPolicy: Orphan`, coût ; sinon repli Tofu via ARC.

## Périmètre de fichiers
docs/, platform/ (brouillon homelab)

## Critères de fin
- [ ] provider choisi ou rejeté avec preuves
- [ ] app `public` → application Access créée, `git revert` → retirée
- [ ] MANDAT Paul : jeton Cloudflare limité à Access
