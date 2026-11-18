---
id: T-364
title: "OpenChoreo CP + DP co-localisés sur la VM lab et ClusterDataPlane homelab"
status: todo
phase: P0
adr: [0003, 0020]
depends_on: [T-061, T-360, T-363, T-365]
class: REVUE + MANDAT
velocity: true
lane: hybride
stage: S1
model: claude-opus-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-364 — OpenChoreo CP + DP co-localisés sur la VM lab et ClusterDataPlane homelab

## Intention
Installer le CP et le DP OpenChoreo sur la VM lab (agent en cluster, aucun chemin réseau externe), enregistrer ClusterDataPlane homelab, créer Environments development et production, livrer une app A.

## Périmètre de fichiers
platform/install/, clusters/homelab/, docs/architecture/MULTI-DATAPLANE.md

## Critères de fin
- [ ] agent connecté, clientCA correct, preuve datée
- [ ] app A Ready + PASS runtime sur le homelab (critère d'échec ADR-0020 §3 : 3 jours)
- [ ] mesure des requests du CP et du DP sur la VM lab pour C2
- [ ] procédure de déplacement du CP vers OKE (nouvelle URL d'agent, nouveau clientCA) rédigée, non exécutée
- [ ] (repris de T-030) Environments development et production sur le cluster lab, clientCA du cluster-gateway correct
- [ ] (repris de T-003) une app A en development, release de production inchangée, preuve datée

## Notes
Remplace le cœur de T-030 ; T-030 reste pour un DP OKE distant. MANDAT : enrôlement (CA, secrets).

La proposition visait : T-030 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `homelab` (clé HOME-4) ; intégration 2 du 2026-11-18.

Emplacement DÉFINITIF du control plane NON tranché : décision de Paul à la porte (D11, T-211). Le CP est sur la VM lab pendant la porte seulement (recommandation homelab, ADR-0003 amendé par T-061).

Remplace le cœur de T-030 (recadré en DP distant, gelé).
