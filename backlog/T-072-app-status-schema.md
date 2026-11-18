---
id: T-072
title: "Schéma `app-status.v1` et `_checks` en sortie JSON stable"
status: done
phase: P0
adr: [0011]
depends_on: []
class: AUTONOME
velocity: true
lane: preuve
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-072 — Schéma `app-status.v1` et `_checks` en sortie JSON stable

## Intention
Préparer la preuve automatique : format de statut versionné (repris de kube-ops) et checks qui l'émettent.

## Périmètre de fichiers
docs/schema/, golden-paths/_checks/, tests/

## Critères de fin
- [x] schéma JSON versionné + exemples (`docs/schema/app-status-v1.schema.json`, `*.example.json`, `*.example-not-tested.json` ; validés par `tests/checks`)
- [x] `_checks` émet ce format, tests (`run-all.sh --format json`, `status_json.py` ; `python3 -m unittest discover -s tests/checks -v` : 20 tests OK, 2026-11-18 ; mode sans cluster = NOT_TESTED, jamais PASS ; NOT_TESTED/STATIC seulement, aucun PASS runtime réel : k3d ≠ OKE)

## Notes
Dépendance T-001 retirée (arbitrage Fable, 2026-11-18) : aucun fichier commun avec la PR #8 (tools/oke/, security/), aucun cluster ; entre dans la liste figée du pilote.
