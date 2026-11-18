---
id: T-008
title: "Check CI des tickets `backlog/`"
status: todo
phase: P0
adr: [0012]
depends_on: []
class: AUTONOME
github_issue: null
---
# T-008 — Check CI des tickets `backlog/`

## Intention
Valider l'en-tête des tickets : id unique, statut connu, dépendances existantes et sans cycle, ADR existant.

## Périmètre de fichiers
tools/, tests/, backlog/README.md

## Critères de fin
- [ ] script + tests
- [ ] job ajouté à la CI (PR REVUE pour `.github/`)
