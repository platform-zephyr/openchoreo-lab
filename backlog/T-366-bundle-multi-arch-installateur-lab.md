---
id: T-366
title: "Bundle de sécurité multi-arch et installateur pour le cluster lab"
status: todo
phase: P0
adr: [0003, 0020]
depends_on: [T-001, T-061, T-061b]
class: REVUE + MANDAT
velocity: true
lane: socle-lab
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-366 — Bundle de sécurité multi-arch et installateur pour le cluster lab

## Intention
Le contrôleur corrigé n'existe qu'en arm64 et le cluster lab est x86_64 ; l'installation sécurisée (Helm 4 avec post-rendu) n'est pas exécutable par Argo. Construire l'image pour les deux architectures et un installateur lab exécuté par un détenteur du kubeconfig lab.

## Périmètre de fichiers
security/bundle.lock, tools/oke/security-bundle.sh, tools/lab/install.sh, docs/SECURITY-BUNDLE.md, dépôt privé du bundle (hors de ce dépôt)

## Critères de fin
- [ ] image corrigée publiée en manifest list amd64 + arm64, digest épinglé dans security/bundle.lock
- [ ] installateur lab : dry-run par défaut, arrêt avant toute écriture si le bundle manque ou ne correspond pas au lock (test de refus)
- [ ] l'installateur passe par le harness d'accès de homelab-infra (kubeconfig lab distribué par Doppler), jamais par Argo ni par un agent
- [ ] installation à blanc datée sur un cluster amd64 jetable

## Notes
Décision 4 (consensus n°2 et arbitrages de Paul, 2026-11-18). MANDAT : publication dans le dépôt privé du bundle et lecture du package. Aucun détail de la faille dans ce dépôt public.

Retardé par ADR-0025 (2026-11-18) : dépend de la porte 1 (T-488) ; le bundle arm64 suffit au banc sur OKE et sur un MacBook Apple Silicon.

Hors chemin critique jusqu'à la porte 2 (arbitrages de Paul n°3, 2026-11-18) : Mac Apple Silicon M1 et OKE sont arm64.
- 2026-11-19 (T-521) : dépendance au banc A/B retirée, le banc est abandonné ; la décision se prendra sur le test d'usage de Paul (T-520).
