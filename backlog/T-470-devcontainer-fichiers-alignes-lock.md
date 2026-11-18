---
id: T-470
title: "Devcontainer : fichiers alignés sur le lock (sans build)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-454, T-332]
class: REVUE
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 74
---

# T-470 — Devcontainer : fichiers alignés sur le lock (sans build)

## Intention
Aligner `.devcontainer/Dockerfile` et `.devcontainer/devcontainer.json` sur la VM cloud : `TARGETARCH` (amd64 et arm64, sans `--platform=linux/arm64` imposé), outils et empreintes de `tools/dev/toolchain.lock`, `postCreateCommand`. Aucun build docker : la preuve est statique.

## Périmètre de fichiers
.devcontainer/Dockerfile, .devcontainer/devcontainer.json, tests/dev-factory/lock-concordance.sh, tests/dev-factory/run.sh

## Critères de fin
- [ ] Dockerfile : `ARG TARGETARCH`, chaque binaire choisit son archive et son sha256 par architecture depuis le lock
- [ ] `tests/dev-factory/lock-concordance.sh` : PASS pour amd64 et arm64 (preuve : sortie datée)
- [ ] `tests/dev-factory/run.sh` : PASS
- [ ] `tools/dev/check --static --changed` : verdict reporté dans la PR

## Notes
Sans docker : le build réel est T-472, la mesure de ressources est T-471. Ne pas modifier `tools/dev/check`, `tools/dev/toolchain.lock` ni `.github/workflows/`. Si le lock manque une empreinte, le dire (BLOCKED) au lieu de l'inventer.
