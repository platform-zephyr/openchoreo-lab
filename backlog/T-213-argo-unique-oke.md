---
id: T-213
title: "Un seul Argo CD sur OKE et nomenclature OKE figée (D4)"
status: deferred
phase: P5
adr: [0003]
depends_on: [T-001, T-061]
class: REVUE + MANDAT
velocity: false
lane: socle-oke
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-213 — Un seul Argo CD sur OKE et nomenclature OKE figée (D4)

## Intention
Fusionner les Argo sur OKE (AppProject borné), trancher l'emplacement d'Authentik, sortir Backstage d'OKE, mesurer la nomenclature (≤ 33 pods, ≤ 70 %).

## Périmètre de fichiers
platform/install/argocd/, docs/architecture/

## Critères de fin
- [ ] un seul Argo sur OKE, preuve datée
- [ ] nomenclature mesurée et versionnée
- [ ] emplacement d'Authentik décidé par Paul

## Notes
Intégration 2 : plus bloquant du MVP (CP sur la VM lab pendant la porte ; lab-argocd devient l'Argo du lab, D4). Dégel si OKE héberge le CP ou des apps (D11). L'emplacement d'Authentik passe à T-211.

(consensus n°2 et arbitrages de Paul, 2026-11-18) : D11 tranché (CP sur le homelab) ; dégel seulement si OKE héberge des apps.

(arbitrages de Paul n°3, 2026-11-18) : pour le POC, OKE est recréé vierge avec le seul Argo du labo (T-490, T-487) ; la cible « un seul Argo par cluster, amorcé par kube-ops » est T-492.
