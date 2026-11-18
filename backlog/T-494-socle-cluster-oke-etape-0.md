---
id: T-494
title: "Étape 0 de tools/oke/install.sh : Cilium en chaînage OCI, VAP baseline-* et CCNP deny-imds/allow-egress-unisolated depuis Git"
status: in-progress
phase: P1
adr: [0025, 0003, 0024]
depends_on: []
class: REVUE
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-494 — Socle cluster OKE (étape 0) depuis Git

## Intention
Sur l'OKE recréé vierge, `tools/oke/preflight.sh` est NO-GO (T-487, `backlog/evidence/T-487-2026-11-18T2206Z-preflight.md`,
PR #144) : Cilium, les CCNP `deny-imds` et `allow-egress-unisolated` et les trois VAP `baseline-*` venaient de kube-ops
(#1620, correctif #1629) et `install.sh` ne les pose pas. Décisions de Paul (2026-11-18) : OKE jetable, vitesse d'abord,
s'appuyer sur ce que kube-ops a déjà, UN SEUL Argo CD sur OKE (`lab-argocd`), kube-ops non modifié.

Livré : une étape `0` de `install.sh`, lancée seule AVANT le préflight, qui installe depuis Git et de façon
reproductible :
1. Cilium 1.20.4 (chart officiel `https://helm.cilium.io`, sha256 du .tgz épinglé dans `versions.env`), values de
   kube-ops (`cni.chainingTarget=oci`, `cni.exclusive=false`, routage natif, sans masquerade, kube-proxy conservé :
   guide amont « Oracle Kubernetes Engine (OKE) VCN-Native Pod Networking », docs.cilium.io v1.20), dans `kube-system` ;
   puis recréation des pods antérieurs à Cilium (même guide, « Restart existing pods ») ;
2. `platform/baseline/` : VAP + VAPB `baseline-pod-hardening`, `baseline-automount-token`, `baseline-image-digest`
   (kube-ops #1620) et CCNP `deny-imds` + `allow-egress-unisolated` corrigée (kube-ops #1629 : exclut
   `platform.smadja.dev/egress-isolated=true`). Copies NON modifiées sous un en-tête de 5 lignes (dépôt, commit,
   licence MIT), prouvées par `tools/oke/baseline-source.sh` (sha256 épinglés, `--online` recalcule depuis GitHub).

Argo CD du labo : `lab-platform` synchronise aussi `platform/baseline/*.yaml` (synchro MANUELLE) et l'AppProject
`lab-platform` admet ces 8 objets cluster-scoped par nom exact, rien d'autre. Cilium reste hors Argo (comme dans
kube-ops : le CNI existe avant tout pod d'Argo).

## Périmètre de fichiers
platform/baseline/, platform/install/values/cilium.yaml, platform/install/versions.env, platform/install/argocd/project-lab.yaml, platform/install/argocd/apps/lab-platform.yaml, tools/oke/install.sh, tools/oke/preflight.sh, tools/oke/verify.sh, tools/oke/baseline-source.sh, tools/oke/kubeconform-platform.sh, tools/appgen/fetch-ext-schemas.sh, tests/argo-guard/run.sh, clusters/oke/capabilities.yaml, NOTICE, LICENSES/MIT-kube-ops.txt, backlog/T-494-socle-cluster-oke-etape-0.md

## Critères de fin
- [x] `tools/oke/baseline-source.sh --online` : 5 PASS (copies identiques à kube-ops@1ecb02f et @98a263f) (STATIC, 2026-11-18)
- [x] `tools/oke/kubeconform-platform.sh` : 115/115 valides, dont `platform/baseline/*.yaml` et le rendu du chart Cilium (STATIC, 2026-11-18)
- [x] `python3 -I tools/oke/argo_guard.py .` : 0 écart, 13 fichiers par lab-platform ; `tests/argo-guard/run.sh` 47 PASS (3 cas nouveaux : CCNP et VAPB hors liste refusées, CCNP `deny-imds` dans `generated/` refusée) ; `python3 -m unittest discover -s tests/argo-guard` OK (STATIC, 2026-11-18)
- [x] `helm template` du chart Cilium 1.20.4 avec `platform/install/values/cilium.yaml` : `cni-chaining-mode: generic-veth`, `cni-chaining-target: oci`, `cni-exclusive: "false"`, images par digest (STATIC, 2026-11-18)
- [x] `tools/dev/check --static --changed` : INCOMPLET (22 PASS, 0 FAIL, 2 NOT_TESTED : `guard-check` hors conteneur de dev, `identities` absent du dépôt), niveau `static-changed`, reçu sha 95df3dd non dirty, 2026-11-18T22:21:13Z ; à reporter dans la PR
- [ ] RUNTIME OKE (session locale) : `tools/oke/install.sh --step 0` (dry-run) puis `--step 0 --apply` sur le cluster vierge, durée mesurée
- [ ] RUNTIME OKE (session locale) : `tools/oke/verify.sh --step 0` sans FAIL (B0-cilium, B0-cilium-chaining, B0-vap*/B0-vapb*, B0-ccnp*, B0-c1, B0-git, B0-vap-deny, B0-cep), journal daté
- [ ] RUNTIME OKE (session locale) : `tools/oke/preflight.sh` GO, preuve datée sous `backlog/evidence/`
- [ ] RUNTIME OKE (session locale) : après l'étape 11, synchro manuelle de `lab-platform` : les 8 objets du socle Synced, `verify.sh --step 0` toujours sans FAIL (B0-git)

## Notes
- Exécution : la session locale (Mac), seul exécutant sur OKE. Ordre : `install.sh --step 0 --apply` →
  `verify.sh --step 0` → `preflight.sh` → `install.sh --apply` (étapes 1 à 11). L'étape 0 est hors de la plage par
  défaut ; elle est idempotente (`helm upgrade --install`, `kubectl apply --server-side`).
- Écriture dans `kube-system` (Cilium) et cluster-wide (VAP, CCNP) : `missions/MISSION.md` l'interdit sans
  autorisation écrite de Paul ; l'autorisation est la décision de Paul consignée dans T-487 (« T-487 réinstalle Cilium
  et `deny-imds` »). Le chart crée aussi le namespace `cilium-secrets` (sans pod).
- Sécurité : aucune règle plus laxiste que kube-ops (copie à l'identique, diff nul prouvé) ; aucune VAP, PSA ou
  NetworkPolicy désactivée ; `baseline-pod-hardening` exempte `kube-system` (Cilium y tourne) et `cloudflared`, comme
  dans kube-ops.
- `preflight.sh` : contrôle en plus les trois VAPB, l'état prêt de Cilium et le chaînage OCI ; l'inventaire
  `crds-before.txt` ignore l'étape 0 (CRD Cilium conservées par `uninstall.sh --delete-crds`). `uninstall.sh` ne
  retire pas le socle (CNI du cluster).
- Écart connu, hors périmètre (à traiter dans un ticket dédié) : `verify.sh --step 1` attend un refus
  `B1-vap-digest` par `baseline-image-digest` dans `openchoreo-control-plane`, alors que le binding de kube-ops est
  `Warn/Audit` sur `auth`, `backstage`, `hindsight` seulement (export OKE identique,
  `tests/vap/fixtures/baseline-oke-export.json`). Ce contrôle échouera ; le binding n'a pas été modifié ici (pas de
  divergence avec kube-ops sans décision).
- Version : 1.20.4 (prouvée sur OKE le 2026-11-17 par kube-ops, identique au homelab) ; le guide amont documente
  1.20.5 (même mineure). Montée = PR sur `versions.env`.
