---
id: T-064
title: "Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s"
status: dropped
phase: P1
adr: [0006, 0004, 0012]
depends_on: [T-003, T-005]
class: REVUE
velocity: false
lane: exploitation
stage: —
github_issue: null
---
# T-064 — Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s

## Intention
Les images épinglées par digest sont mises à jour par PR, testées en dev avant prod ; procédure de montée OpenChoreo (bundle de sécurité, CRD, référence doc) et OKE (nœud unique).

## Périmètre de fichiers
.github/renovate.json, docs/runbooks/, tools/

## Critères de fin
- [ ] Renovate ouvre des PR de digest, dev avant prod
- [ ] runbook de montée OpenChoreo d'une mineure, avec mise à jour de docs/reference/openchoreo/
- [ ] runbook de montée OKE

## Notes
Absorbé par T-120 (intégration des recherches du 2026-11-18).
