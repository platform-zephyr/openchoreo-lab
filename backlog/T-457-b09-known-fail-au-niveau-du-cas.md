---
id: T-457
title: "Classer B-09 KNOWN_FAIL au niveau du cas dans tests/vap/run.sh"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: false
lane: agents
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-457 — Classer B-09 KNOWN_FAIL au niveau du cas dans tests/vap/run.sh

## Intention
B-09 (conteneur éphémère privileged hors dp-* admis) est un écart de la baseline kube-ops hors de ce dépôt. Le classer KNOWN_FAIL au niveau du cas : le cas reste exécuté et visible, la suite annonce s'il passe un jour. Aucune politique désactivée. La vraie correction est dans la baseline de la VM lab (T-363).

## Périmètre de fichiers
tests/vap/run.sh, tests/vap/

## Critères de fin
- [ ] B-09 classé KNOWN_FAIL, le cas reste exécuté et son verdict visible
- [ ] la suite rend 0 sans autre FAIL et annonce un passage inattendu
- [ ] dispatch manuel de vap : vert, preuve datée

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.
