---
id: T-363
title: "Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stockage)"
status: todo
phase: P0
adr: [0003, 0014]
depends_on: [T-001, T-061, T-061b, T-361, T-362]
class: REVUE + MANDAT
velocity: true
lane: socle-lab
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-363 — Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stockage)

## Intention
Installer par Git le socle lab : Gateway API épinglée à la version exigée par Cilium (relire la compatibilité kgateway), ESO avec ClusterSecretStore propre (jamais doppler-cluster), Kyverno et VAP en `enforce` avant la première app, Argo CD lab, stockage local sans Longhorn, CNPG.

## Périmètre de fichiers
platform/lab-bootstrap/, clusters/homelab/

## Critères de fin
- [ ] Argo lab Synced/Healthy, preuve datée
- [ ] une ExternalSecret vers un store autre que lab-store est refusée (test)
- [ ] versions épinglées, compatibilité Gateway API / Cilium / kgateway documentée
- [ ] amorçage fail-closed (même exigence que T-001)
- [ ] VAP et Kyverno (règles de base) en `enforce` sur le lab avant le déploiement de la première app ; jamais en audit seul (preuve datée)

## Notes
MANDAT : amorçage Argo par un humain (jeton ESO) comme sur OKE. Réutilise l'Argo d'essai lab-argocd (D4).

La proposition visait : T-213 (décision d'intégration : INTEGRATION-2.md).

Proposé par la recherche `homelab` (clé HOME-3) ; intégration 2 du 2026-11-18.

Constat F4 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).
