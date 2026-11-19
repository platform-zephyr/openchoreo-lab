---
id: T-060
title: "Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)"
status: todo
phase: P2
adr: [0006]
depends_on: [T-001, T-061, T-061b]
class: REVUE
velocity: false
lane: socle-oke
stage: I2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-060 — Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL)

## Intention
Fermer le résidu de moindre privilège accepté (STATE.md §1) avant tout credential réel.

## Périmètre de fichiers
platform/install/values/kgateway.yaml, platform/install/manifests/05-kgateway-rbac.yaml, platform/install/manifests/12-gateway-parameters.yaml, platform/install/versions.env, tools/oke/{install,uninstall,verify,render-check}.sh, tools/oke/kgateway_rbac_check.py, tools/k3d/ci-bootstrap.sh, tests/k3d/, tests/kgateway-rbac/

## Critères de fin
- [ ] `verify.sh` : B6-sa-effective PASS daté sur OKE
- [ ] test de non-régression en CI k3d

## Notes
2026-11-18 — La PR #138 (post-traitement RBAC kgateway) est FERMÉE sans fusion. Décision de Paul (Q12, 2026-11-18) : le résidu « kgateway lit et écrit les Secrets de tout le cluster » (B6-sa-effective) est ACCEPTÉ et documenté jusqu'à FINAL0 (OKE jetable). Reprise à FINAL0 avec kgateway v2.5 (`rbac.create=false` + ClusterRole versionné dans Git, PR amont kgateway #14105). Source : docs/research/OPENCHOREO-FIDELITE-ECARTS.md. Aucun critère de fin n'est coché.

2026-11-19 — Revue v2.5 (branche `claude/t-060-kgateway-rbac`) : **v2.5 ne convient pas** (v2.5.0 supprime la CRD
HTTPListenerPolicy rendue par OpenChoreo 1.3.3). Livré : kgateway **v2.4.8** (`rbac.create` présent, CRD gardée),
RBAC versionné sans écriture de Secrets cluster-wide (`B5-rbac`, `T13a-g`, `tests/kgateway-rbac`). La **lecture**
cluster-wide reste inhérente (informer sans namespace, v2.4.8 et v2.5.2) : `B6-sa-effective` reste FAIL ; décision de
Paul requise (résidu lecture accepté et B6 restreint aux SA OpenChoreo, ou kgateway hors `openchoreo-control-plane`).
