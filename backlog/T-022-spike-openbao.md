---
id: T-022
title: "Spike OpenBao : placement, stockage, déscellement, sauvegarde"
status: todo
phase: P2
adr: [0014]
depends_on: [T-061]
class: AUTONOME + MANDAT
velocity: false
lane: secrets
stage: I2
github_issue: null
---
# T-022 — Spike OpenBao : placement, stockage, déscellement, sauvegarde

## Intention
Qualifier OpenBao sur OKE : backend (PostgreSQL plateforme ou Raft), auto-unseal hors cluster, sauvegarde chiffrée hors Oracle, coût.

## Périmètre de fichiers
docs/storage/, platform/ (brouillon), tests/

## Critères de fin
- [ ] installé en `lab-*`, re-mesure CPU/mémoire datée
- [ ] auto-unseal prouvé sur k3d
- [ ] drill perte + restauration
- [ ] backend sans nouveau volume OCI, sinon MANDAT explicite pour le volume
- [ ] MANDAT Paul : clé d'auto-unseal, stockage des clés de récupération (Doppler + hors ligne)
- [ ] pod OpenBao inscrit dans la nomenclature OKE avant installation
- [ ] exercice perte + restauration réussi et daté AVANT toute migration
