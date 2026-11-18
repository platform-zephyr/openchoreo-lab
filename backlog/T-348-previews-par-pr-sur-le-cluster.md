---
id: T-348
title: "Previews par PR sur le cluster dev homelab (TTL, frugalité, preuve publiée)"
status: todo
phase: P2
adr: [0004, 0022]
depends_on: [T-004, T-005, T-061, T-342, T-343]
class: AUTONOME + REVUE
velocity: true
lane: hybride
stage: I1
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-348 — Previews par PR sur le cluster dev homelab (TTL, frugalité, preuve publiée)

## Intention
Une PR d'app peut demander une preview : instance isolée sur N2 (selon la décision de T-342), au plus 2 simultanées, TTL 24 h, suppression à la fermeture de la PR, preuve runtime publiée comme statut de commit (app-status.v1). Les agents lisent la preuve, jamais le cluster.

## Périmètre de fichiers
platform/ (ApplicationSet previews), tools/appgen/ (label preview), tests/dev-cluster/

## Critères de fin
- [ ] preview créée à l'ouverture, détruite à la fermeture et à l'expiration (essais datés)
- [ ] la troisième preview simultanée est refusée (cas négatif)
- [ ] le statut de commit cite le niveau RUNTIME (homelab) et l'architecture x86_64

## Notes
Ne remplace pas la preuve OKE de T-005. Aucune app B ou C en preview (règle de frugalité ADR-0004).

Proposé par la recherche `harness` (clé HAR-18) ; intégration 2 du 2026-11-18.
