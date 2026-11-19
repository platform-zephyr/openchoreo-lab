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
- [x] Dispatch `k3d-integration` sur la branche : `argo-escalation` vert (run 44501238351, 2026-11-19, niveau CI).
- [x] `docs/CI-K3D.md` et `RESULTS.md` mis à jour avec la preuve.

## Notes
Proposition hors périmètre (workflow) : voir la PR.

### Reprise (2026-11-19)
- Fait : cause prouvée (main@0fc7412, run 44495170272, et #169 run 44435032144) ; CRD Cilium minimales + garde `cilium_crds_check` ; PR #173 ; dispatch de la branche, run 44501238351 (résultat par suite dans le corps de la PR).
- Reste : (argo-escalation vert, cases cochées) sortir #173 du brouillon, attendre `ci-ok` sur la tête courante, fusion squash. Sinon lire `_temp/diagnostic.txt` de l'artefact `k3d-argo-escalation`.
- Commandes : `gh api repos/<o>/<r>/actions/runs/<id>/jobs` ; artefact : `gh api repos/<o>/<r>/actions/artifacts/<id>/zip`.
- Pièges : les runs `merge_group` sautent les suites (vert sans preuve) ; un seul run k3d à la fois (un autre run relancé peut occuper le dépôt) ; la tentative 2 d'un run réutilise le même numéro.
- K3D_REQUIRED (repris par T-513, non fait ici) : proposer qu'en `merge_group`, si le groupe touche platform/ ou tests/{k3d,argo-escalation,vap,gitops-k3d}/ et que `K3D_REQUIRED` n'est pas `true`, `k3d-ok` écrive « suites NON lancées » en avertissement visible au lieu d'un vert muet ; Paul pose `K3D_REQUIRED=true` à FINAL0 (docs/CI-K3D.md §6).
