---
id: T-003
title: "Environment `development`, promotion vers `production`, pins de release par environnement"
status: in-progress
phase: P0
adr: [0004]
depends_on: [T-001, T-002, T-061, T-061b]
class: AUTONOME
velocity: true
lane: contrat-appgen
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 49
---
# T-003 — Environment `development`, promotion vers `production`, pins de release par environnement

## Intention
Deux Environments sur le même data plane ; `appgen promote <app>` épingle en production la release validée en dev (corrige G3).

## Périmètre de fichiers
platform/install/manifests/40-openchoreo-env.yaml, tools/appgen/, tests/appgen/, tools/k3d/ci-bootstrap.sh (critère 3), docs/CI-K3D.md (contournement retiré)

## Critères de fin
- [x] tests appgen verts (pins par env, promote, rollback) — 2026-11-18, STATIC : `python3 -m unittest discover -s tests/appgen` 198 tests OK (8 sautés), dont `tests/appgen/test_promotion.py` (17) ; `appgen check --base origin/main` : aucune dérive
- [ ] CI k3d verte
- [x] le bootstrap CI k3d n'invente plus `development` (suppression du `yq`) — 2026-11-18, STATIC : bloc `yq` et `need … yq` retirés de `tools/k3d/ci-bootstrap.sh`, vérifié par `test_promotion.K3dBootstrapNoInvention` ; `development` vient de `40-openchoreo-env.yaml`
- [ ] preuve k3d CI : une app A en development, release de production inchangée (la preuve runtime est dans T-364)
- [ ] Environment `development` et `promotionPaths` réconciliés par Argo `lab-platform` sur OKE (lecture `kubectl get environment,deploymentpipeline -n default`, datée)

## Notes
- Pins : `pins/component-releases.yaml`, clé `<composant>/<env>`. `development` suit la release courante ; `production` suit
  son pin. Sans pin, une app `production` seule garde la release courante (aucun changement de `generated/`). Une app
  déclarée en `development` et `production` sans pin de production est refusée au rendu.
- `appgen promote <app>` lit le ReleaseBinding `development` de `generated/` (état mergé) ; `appgen rollback <app> <release>`
  repointe une release conservée. Retour arrière d'une promotion : `git revert` de la PR du pin.
- Écart de périmètre justifié : `tools/k3d/ci-bootstrap.sh` (critère 3) et `docs/CI-K3D.md` §2 (contournement décrit).
- La preuve k3d du critère 4 exige un cas dans `tests/k3d/run.sh` (hors périmètre de ce ticket) : NOT_TESTED.
