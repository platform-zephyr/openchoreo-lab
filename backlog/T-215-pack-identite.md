---
id: T-215
title: "Pack identité : compte agent (rôle Write) et GitHub App plateforme"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: MANDAT
velocity: true
lane: gouvernance
stage: S0
github_issue: null
---
# T-215 — Pack identité : compte agent (rôle Write) et GitHub App plateforme

## Intention
Une identité agent sans droit d'admin et une seule GitHub App (statut de commit, Renovate, dispatch, remédiation). Aucun agent n'agit avec le compte admin de Paul.

## Périmètre de fichiers
docs/AGENT-IDENTITY.md, .github/

## Critères de fin
- [ ] compte agent rôle Write créé par Paul
- [ ] GitHub App plateforme installée sur ce dépôt seulement, permissions minimales listées
- [ ] essai réel : une PR du noyau ouverte par l'agent n'est pas fusionnable

## Notes
Absorbe les parties GitHub de T-005, T-106, T-121, T-164 et T-210.
