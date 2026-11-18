---
id: T-332
title: "Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée"
status: todo
phase: P0
adr: [0022]
depends_on: []
class: AUTONOME
velocity: true
lane: dev-factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-332 — Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée

## Intention
Une seule entrée pour la definition of done technique, sans Docker ni cluster pour --static (yamllint, appgen validate/check/unittest, kubeconform, gitleaks, shellcheck, tests unitaires). Un fichier toolchain.lock (versions + sha256) lu par le Dockerfile, ci.yaml et le script de l'environnement cloud.

## Périmètre de fichiers
tools/dev/check, tools/dev/toolchain.lock, tests/dev-factory/

## Critères de fin
- [ ] `tools/dev/check --static` passe sur main, en moins de 3 min, sans Docker (temps daté)
- [ ] test de concordance : toolchain.lock = Dockerfile = ci.yaml (cas négatif : une version modifiée fait échouer)
- [ ] le conteneur de dev, le job CI et la VM cloud appellent la même commande

## Notes
Remplace la dépendance de `dev test` à Colima/Mac. La VM cloud est x86_64, la CI arm64 : --static doit être indépendant de l'architecture.

Proposé par la recherche `harness` (clé HAR-2) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).
