---
id: T-009
title: "Mesurer le budget réel d'OKE avec OpenChoreo, dev et futurs composants"
status: todo
phase: P0
adr: [0003, 0004]
depends_on: [T-001]
class: AUTONOME
github_issue: null
---
# T-009 — Mesurer le budget réel d'OKE avec OpenChoreo, dev et futurs composants

## Intention
Savoir ce qui tient sur le nœud A1 (seuil 70 %) avant d'ajouter OpenBao, Kyverno, Crossplane ou des apps.

## Périmètre de fichiers
tools/oke/verify.sh (lecture), docs/

## Critères de fin
- [ ] mesure datée (requests, usage, pods, IP)
- [ ] tableau : composant → cluster recommandé
- [ ] mise à jour de D1 dans DECISIONS-OPEN si besoin
