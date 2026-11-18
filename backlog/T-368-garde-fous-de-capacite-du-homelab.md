---
id: T-368
title: "Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné"
status: todo
phase: P1
adr: [0017]
depends_on: [T-061, T-360, T-363]
class: AUTONOME + REVUE
velocity: false
lane: coût
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-368 — Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné

## Intention
Un ResourceQuota par namespace lab-*, une alerte ntfy à 80 % (RAM VM, NVMe, Tctl) et une sortie JSON homelab-capacity.v1 PASS/FAIL/NOT_TESTED lue par le lint.

## Périmètre de fichiers
docs/state/homelab-capacity.yaml, platform/lab-bootstrap/quotas/, tools/cost/

## Critères de fin
- [ ] dépassement simulé = FAIL typé et alerte ntfy
- [ ] un agent ne relève jamais un plafond (ADR-0017 §7) : test de refus

## Notes
Proposé par la recherche `homelab` (clé HOME-8) ; intégration 2 du 2026-11-18.
