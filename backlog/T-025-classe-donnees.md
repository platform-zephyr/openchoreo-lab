---
id: T-025
title: "Classe de donnée dans le contrat et labels `data-class` (G8)"
status: todo
phase: P2
adr: [0008]
depends_on: [T-002, T-072, T-214]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: I1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-025 — Classe de donnée dans le contrat et labels `data-class` (G8)

## Intention
`data.class: ephemeral | rebuildable | useful | irreplaceable`, propagée en label ; `Retain` et pas de prune sur les données.

## Périmètre de fichiers
docs/schema/, tools/appgen/, platform/

## Critères de fin
- [x] schéma + migration des apps existantes — STATIC 2026-11-18 : `spec.data.class` dans `docs/schema/app.schema.json` ; 5 apps avec base ou volume migrées (4 `rebuildable`, `mealie` `useful` : données réelles, aucune sauvegarde) ; `appgen validate` 11 apps OK, `appgen check` sans dérive (86 fichiers)
- [x] CI : base/volume sans classe → refus — STATIC 2026-11-18 : règle `_data_errors` (`semantic.py`), exécutée par `appgen validate` (job CI `appgen`, à confirmer à la PR) ; tests `test_database_without_data_class_refused`, `test_volume_without_data_class_refused`, `test_irreplaceable_data_class_refused` ; `unittest discover -s tests/appgen` : 207 OK
- [ ] labels présents sur namespace, PVC, base — NON COCHÉ : modèles posés (paramètre `dataClass` du CPT `cell-restricted`, du ClusterTrait `persistent-volume-claim`, du CRT `cnpg-lab-db`, label sur la Resource) et paramètres rendus sous `generated/` (STATIC) ; label réel sur namespace, PVC et base NOT_TESTED (aucun rendu OpenChoreo ; la base existante exige un nouveau pin `pin-resource`)

## Notes
Dans la liste figée du pilote (arbitrage Fable, 2026-11-18) : contrat seulement, aucune donnée réelle ; sérialisé après T-214 (couloir contrat-appgen) et T-072 (docs/schema/).
