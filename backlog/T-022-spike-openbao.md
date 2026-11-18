---
id: T-022
title: "OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill"
status: todo
phase: P2
adr: [0014]
depends_on: [T-061, T-061b, T-404]
class: AUTONOME + MANDAT
velocity: false
lane: secrets
stage: I2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-022 — OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill

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
- [ ] pod OpenBao inscrit dans le budget du cluster lab (T-360) avant installation ; OKE, s'il sert, lit Doppler
- [ ] exercice perte + restauration réussi et daté AVANT toute migration
- [ ] (repris de HOME-10) Raft local sur un seul volume du cluster lab, snapshot chiffré hors site (hors Oracle)
- [ ] option backend PostgreSQL (production ready, HA depuis 2.7.0) comparée à Raft ; dépendance circulaire CNPG ↔ OpenBao tranchée et écrite (vérification du 2026-11-18)

## Notes
Intégration 2 : absorbe HOME-10 (variante lab prioritaire). Seal statique : décision de Paul (CONSENSUS).

Dépend du jalon FINAL0 (T-404) (arbitrage Fable, 2026-11-18) : crée une donnée réelle, une identité réelle ou une exposition publique.
