---
id: T-052
title: "Retrait progressif des chemins kube-ops, app par app"
status: todo
phase: P5
adr: [0001, 0008]
depends_on: [T-050, T-051]
class: MANDAT
velocity: false
lane: migration
github_issue: null
---
# T-052 — Retrait progressif des chemins kube-ops, app par app

## Intention
Basculer chaque app migrée, puis retirer l'ancien chemin sans perte de données.

## Périmètre de fichiers
kube-ops (PR séparées), apps/

## Critères de fin
- [ ] export + restauration prouvés avant bascule
- [ ] suppression de données = MANDAT
- [ ] kube-ops à jour
