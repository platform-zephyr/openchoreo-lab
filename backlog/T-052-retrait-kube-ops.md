---
id: T-052
title: "Retrait progressif des chemins kube-ops, app par app"
status: deferred
phase: P5
adr: [0001, 0008]
depends_on: [T-050, T-051]
class: MANDAT
velocity: false
lane: migration
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
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
- [ ] ordre suivi : A (`it-tools`, `searxng`, `idp-e2e`), puis C (après T-075), puis B (après T-026, T-027 et FINAL0) ; une app en vol par archétype
- [ ] bascule d'une app seulement après `app-status.v1` PASS 7 jours en parallèle de l'ancien chemin ; ancien chemin retiré par PR dans kube-ops 14 jours après
- [ ] retour arrière écrit par app (route rendue à kube-ops, `git revert`) et répété une fois

## Notes
Ordre et critères de bascule : `docs/research/POC-OPENCHOREO-STRATEGY.md` §4 phase 5 (ADR-0025). Ne démarre qu'après la porte 2 (T-211).

Différé après la porte OpenChoreo (ADR-0020, consensus du 2026-11-18).
