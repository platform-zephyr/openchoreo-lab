---
id: T-457
title: "Classer B-09 KNOWN_FAIL au niveau du cas dans tests/vap/run.sh"
status: done
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
- [x] B-09 classé KNOWN_FAIL, le cas reste exécuté et son verdict visible (`tests/vap/known-fail.sh` ; `t()` exécute toujours le cas, verdict `KNOWN_FAIL` écrit dans `results.tsv`, la ligne et la preuve ; test `bash tests/vap/known-fail.test.sh` 12 PASS dont négatifs, 2026-11-18, STATIC)
- [x] la suite rend 0 sans autre FAIL et annonce un passage inattendu (simulation de `t()` extrait de run.sh : B-09 KNOWN_FAIL ne compte pas, B-10 FAIL compte, B-09 qui passe = ligne `ANNONCE` + `UNEXPECTED_PASS`, 2026-11-18 ; runtime sur cluster NOT_TESTED)
- [x] dispatch manuel de vap : vert, preuve datée (RUNTIME, 2026-11-18, run 44313410652 sur main : 91 PASS, 0 FAIL, 1 KNOWN_FAIL (B-09), 0 UNEXPECTED_PASS, RESULTAT PASS)

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.

## Reste
- Dispatch manuel de `k3d-integration` (suite vap) sur la branche : vert avec B-09 `KNOWN_FAIL`, preuve datée. Geste de Paul (ou d'un agent avec droit `gh workflow run`) ; non fait ici.
