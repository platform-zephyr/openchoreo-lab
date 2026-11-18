---
id: T-067
title: "`appgen retire` : retrait d'une app avec export des données"
status: todo
phase: P2
adr: [0001, 0008, 0013]
depends_on: [T-025, T-026]
class: AUTONOME
velocity: false
lane: contrat-appgen
github_issue: null
---
# T-067 — `appgen retire` : retrait d'une app avec export des données

## Intention
« Supprime X » : retrait par PR, export et `Retain` des données ; la suppression effective de données `useful`/`irreplaceable` reste MANDAT.

## Périmètre de fichiers
tools/appgen/, .agents/skills/

## Critères de fin
- [ ] commande + tests
- [ ] preuve k3d : app retirée, données exportées et conservées
