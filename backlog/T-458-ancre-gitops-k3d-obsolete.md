---
id: T-458
title: "Réparer l'ancre obsolète de gitops-k3d (correction G1 déjà dans main)"
status: in-progress
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

# T-458 — Réparer l'ancre obsolète de gitops-k3d (correction G1 déjà dans main)

## Intention
La suite gitops-k3d s'arrête après 77 s sur une ancre périmée alors que la correction G1 est dans main. Réparer l'ancre ; les FAIL déjà connus qui réapparaissent sont classés un par un (état réel NOT_TESTED aujourd'hui).

## Périmètre de fichiers
tests/gitops-k3d/, tools/k3d/

## Critères de fin
- [ ] ancre réparée, la suite va au-delà de T-DEPLOY
- [ ] chaque FAIL réapparu est classé (corrigé ou KNOWN_FAIL motivé)
- [ ] dispatch manuel de gitops-k3d : résultat daté

## Notes
Issu de l'étude T-452 (`docs/research/K3D-REACTIVATION.md` §2) et de la décision de Paul du 2026-11-18. Mode dev : merge après `ci-ok` ; preuve par dispatch manuel de `k3d-integration` sur la branche.

## Avancement (2026-11-18)
- Fait (STATIC) : `tests/gitops-k3d/patch_env.py` remplace l'ancre de texte (idempotent, `added|updated|noop`) ; `run.sh` l'utilise ; 13 tests dont 5 négatifs (`python3 -m unittest discover -s tests/gitops-k3d`). Détail : `tests/gitops-k3d/RESULTS.md`.
- Reste (aucune des 3 cases n'est cochée, preuve runtime absente) :
  - dispatch manuel de `k3d-integration` (suite `gitops-k3d`) sur la branche : la suite doit dépasser T-DEPLOY (NOT_TESTED) ;
  - classer chaque FAIL réapparu (T-ARGO-HEALTH, T-PRUNE-STATUS, T-PIN-STALE, T-STRATEGY, T-RETRAIT-1) : corrigé ou `KNOWN_FAIL` motivé ;
  - noter le résultat daté ; retirer `known_fail` de la matrice (`.github/workflows/k3d-integration.yml`, hors périmètre) seulement si la suite passe ;
  - brancher `tests/gitops-k3d` dans la CI unitaire (`ci.yaml`, autre agent) : non fait.

Preuve runtime partielle (2026-11-18, run 44313410652 sur main) : la suite `gitops-k3d` dépasse désormais l'ancre mais rend encore `RESULTAT: KNOWN_FAIL` (job vert car la suite est classée `known_fail`). Reste : lire `results.tsv` de l'artefact, classer chaque FAIL (corrigé ou KNOWN_FAIL motivé), puis cocher les trois cases.
