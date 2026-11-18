---
id: T-402
title: "Garde d'image multi-arch pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64)"
status: todo
phase: P4
adr: [0003, 0006]
depends_on: [T-123, T-365]
class: AUTONOME
velocity: false
lane: contrat-appgen
stage: FINAL
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-402 — Garde d'image multi-arch pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64)

## Intention
Une app qui peut aller sur les deux clusters exige une image multi-arch (manifest list amd64 + arm64) ; une app limitée au homelab n'exige que amd64.

## Périmètre de fichiers
tools/appgen/, tests/appgen/, clusters/*/capabilities.yaml

## Critères de fin
- [ ] appgen refuse une app `cluster: oke` (ou éligible aux deux) dont le digest n'a pas les deux architectures (test négatif)
- [ ] une app homelab seule passe avec amd64 (test positif)

## Notes
Décision 11 du consensus n°2, placée en FINAL (consensus n°2 et arbitrages de Paul, 2026-11-18). Sans objet tant qu'aucune app OKE n'est demandée par Paul : passer `dropped` à la revue finale si c'est toujours le cas.
