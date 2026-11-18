---
id: T-462
title: "Devcontainer multi-architecture et mesure de check --static sous 1 vCPU (SL-8)"
status: blocked
phase: P0
adr: [0022]
depends_on: [T-454, T-332, T-470, T-471, T-472]
class: REVUE
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 67
---

# T-462 — Devcontainer multi-architecture et mesure de check --static sous 1 vCPU (SL-8)

## Intention
Aligner le devcontainer sur la VM cloud (TARGETARCH, outils du lock, postCreateCommand), mesurer `check --static` sous 1 vCPU et 1 GiB, build périodique hors `ci-ok`.

## Périmètre de fichiers
.devcontainer/, tests/dev-factory/, .github/workflows/devcontainer-build.yaml (parent : le travail se fait dans T-470, T-471, T-472)

## Critères de fin
- [ ] devcontainer qui se construit en amd64 et arm64
- [ ] `check --static` mesuré sous 1 vCPU / 1 GiB (durée datée)
- [ ] build périodique hors `ci-ok`

## Notes
Issu de `docs/research/SHIFT-LEFT-DEV-ENV.md` §5. Mode dev : merge après `ci-ok`.
Bloqué par : T-470 (fichiers `.devcontainer/` alignés sur le lock), T-471 (mesure sous 1 vCPU / 1 GiB), T-472 (build périodique hors `ci-ok`). T-462 est le ticket parent : il passe `done` quand les trois sont `done`, sans travail propre.
