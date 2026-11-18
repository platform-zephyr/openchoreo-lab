---
id: T-364
title: "OpenChoreo CP + DP sur la VM lab (CP définitif, D11) et ClusterDataPlane homelab"
status: todo
phase: P0
adr: [0003, 0020]
depends_on: [T-001, T-061, T-061b, T-360, T-363, T-365, T-366]
class: REVUE + MANDAT
velocity: true
lane: hybride
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-364 — OpenChoreo CP + DP sur la VM lab (CP définitif, D11) et ClusterDataPlane homelab

## Intention
Installer le CP et le DP OpenChoreo sur la VM lab (agent en cluster, aucun chemin réseau externe), enregistrer ClusterDataPlane homelab, créer Environments development et production, livrer une app A.

## Périmètre de fichiers
platform/install/, clusters/homelab/, docs/architecture/MULTI-DATAPLANE.md

## Critères de fin
- [ ] agent connecté, clientCA correct, preuve datée
- [ ] app A Ready + PASS runtime sur le homelab (critère d'échec ADR-0020 §3 : 3 jours)
- [ ] mesure des requests du CP et du DP sur la VM lab pour C2
- [ ] procédure d'ajout d'un data plane OKE distant (T-030) esquissée, non exécutée
- [ ] (repris de T-030) Environments development et production sur le cluster lab, clientCA du cluster-gateway correct
- [ ] (repris de T-003) une app A en development, release de production inchangée, preuve datée

## Notes
Remplace le cœur de T-030 ; T-030 reste pour un DP OKE distant. MANDAT : enrôlement (CA, secrets).

La proposition visait : T-030 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `homelab` (clé HOME-4) ; intégration 2 du 2026-11-18.

D11 tranché par Paul (consensus n°2 et arbitrages de Paul, 2026-11-18) : le control plane OpenChoreo est sur la VM lab du homelab, de façon définitive (ADR-0003 amendé). OKE reste optionnel (T-030).

Remplace le cœur de T-030 (recadré en DP distant, gelé).
