---
id: T-065
title: "CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107)"
status: todo
phase: P1
adr: [0011, 0002]
depends_on: [T-005, T-015]
class: AUTONOME + MANDAT
velocity: false
lane: preuve
github_issue: null
---
# T-065 — CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107)

## Intention
Une régression entre deux syncs (CrashLoop, preuve de restauration périmée) est vue : statut périodique, PR de revert automatique, notification ntfy ; `observability` rendu (G5).

## Périmètre de fichiers
platform/, golden-paths/_checks/, tools/appgen/

## Critères de fin
- [ ] CronJob de statut ≤ 30 min d'intervalle
- [ ] régression simulée → PR de revert ouverte et notification reçue
- [ ] G5 rendu ou déclassé dans SCHEMA-GAPS
