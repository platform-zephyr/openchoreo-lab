---
id: T-505
title: "Suite k3d argo-escalation : CRD Cilium minimales (la synchro de lab-platform échoue sans elles)"
status: in-progress
phase: P1
adr: [0024]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-505 — argo-escalation : CRD Cilium

## Intention
Le job `argo-escalation` de `k3d-integration` échoue à l'étape « Application racine » (`timed out waiting for the
condition`, l'attente du Cluster CNPG `lab-pg`, 180 s). Cause prouvée : `lab-platform` ne se synchronise pas
(« failed to discover server resources for group version cilium.io/v2 »), car T-494 (#145) puis T-006 (#163) ont
mis des `CiliumNetworkPolicy` et `CiliumClusterwideNetworkPolicy` dans les chemins synchronisés, et le cluster k3d
de la suite n'a aucune CRD Cilium. Régression de la suite (pas propre à la PR #169, pas un aléa).
Les runs `merge_group` de main sont « verts » parce que les suites y sont `skipped` (`K3D_REQUIRED` non posée) :
ils ne prouvent rien.

## Périmètre de fichiers
backlog/T-505-argo-escalation-crd-cilium.md, tests/argo-escalation/run.sh, tests/argo-escalation/cilium-crds.yaml, tests/argo-escalation/RESULTS.md, docs/CI-K3D.md

## Critères de fin
- [x] Cause prouvée dans les journaux du job en échec (run 44435032144, tentative 2, 2026-11-19).
- [x] Deux CRD Cilium minimales (schéma permissif) dans `tests/argo-escalation/cilium-crds.yaml`, appliquées avant Argo CD.
- [x] Garde statique `cilium_crds_check` + auto-test négatif (kind inconnue refusée) : exécutés en local, PASS.
- [ ] Dispatch `k3d-integration` sur la branche : `argo-escalation` vert (preuve datée).
- [ ] `docs/CI-K3D.md` et `RESULTS.md` mis à jour avec la preuve.

## Notes
Proposition hors périmètre (workflow) : voir la PR.
