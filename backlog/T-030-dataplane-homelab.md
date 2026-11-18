---
id: T-030
title: "Data plane distant entre le cluster lab et OKE (selon la décision D11)"
status: deferred
phase: P5
adr: [0003]
depends_on: [T-001, T-061]
class: REVUE + MANDAT
velocity: false
lane: hybride
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-030 — Data plane distant entre le cluster lab et OKE (selon la décision D11)

## Intention
Seulement si Paul demande une app sur OKE ou déplace le CP (D11) : CP sur lab ⇒ DP OKE (exception de flux OKE → homelab, D13) ; CP sur OKE ⇒ DP lab par NetBird L4.

## Périmètre de fichiers
platform/install/, clusters/homelab/, docs/architecture/MULTI-DATAPLANE.md

## Critères de fin
- [ ] agent du DP distant connecté au CP, mTLS et clientCA corrects, preuve datée
- [ ] flux réseau conforme à la décision D11/D13, ACL limitée au port de la cluster-gateway
- [ ] (repris de T-031) même app déplacée oke ↔ homelab par changement de `cluster`
- [ ] MANDAT Paul : ACL NetBird, enrôlement

## Notes
À lancer tôt : la latence est humaine (MANDAT).

Recadré par l'intégration 2 : le cœur (DP homelab, Environments, app A) est passé à T-364 (S1).

Différé après la porte OpenChoreo (D11).
