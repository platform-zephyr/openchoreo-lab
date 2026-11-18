---
id: T-030
title: "Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4)"
status: todo
phase: P1
adr: [0003]
depends_on: [T-001, T-061]
class: REVUE + MANDAT
velocity: false
lane: hybride
stage: S2
github_issue: null
---
# T-030 — Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4)

## Intention
Agent homelab sortant vers le cluster-gateway d'OKE, mTLS de bout en bout, capacités homelab déclarées.

## Périmètre de fichiers
platform/install/, clusters/homelab/, docs/architecture/MULTI-DATAPLANE.md

## Critères de fin
- [ ] agent connecté, preuve datée
- [ ] SAN du cluster-gateway correct
- [ ] Environments development et production sur le homelab
- [ ] MANDAT Paul : ACL NetBird, accès Talos

## Notes
À lancer tôt : la latence est humaine (MANDAT).
