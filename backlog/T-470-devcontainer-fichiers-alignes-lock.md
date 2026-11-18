---
id: T-470
title: "Devcontainer : fichiers alignés sur le lock (sans build)"
status: done
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
- [x] Dockerfile : `ARG TARGETARCH`, chaque binaire choisit son archive et son sha256 par architecture depuis le lock — STATIC, PR #81 ; `.devcontainer/Dockerfile` (`ARG TARGETARCH`, `case "${TARGETARCH}"`)
- [x] `tests/dev-factory/lock-concordance.sh` : PASS pour amd64 et arm64 (preuve : sortie datée) — STATIC, 2026-11-18, après T-332 (#106, empreintes linux-amd64 de kubectl, jq et gh dans le lock) : `TOOLCHAIN-LOCK: PASS (34 clés)`, `ARCH arm64: PASS (9 outils)`, `ARCH amd64: PASS (9 outils)`
- [x] `tests/dev-factory/run.sh` : PASS — STATIC, 2026-11-18 : `DEV-FACTORY-STATIC: PASS`
- [x] `tools/dev/check --static --changed` : verdict reporté dans la PR — PR #81 : `RESULT: FAIL` (STATIC, PASS=4 FAIL=2 NOT_TESTED=4, INCOMPLET), les 2 FAIL (`shellcheck` sur `tools/dev/check`, `check-selftest`) viennent de `main`/de l'environnement, hors de ce diff ; reçu non produit

## Notes
Sans docker : le build réel est T-472, la mesure de ressources est T-471. Ne pas modifier `tools/dev/check`, `tools/dev/toolchain.lock` ni `.github/workflows/`. Si le lock manque une empreinte, le dire (BLOCKED) au lieu de l'inventer.

Avancement (2026-11-18) : PR #81 fusionnée par l'orchestrateur (agent de l'usine, run 44331128791) : Dockerfile multi-arch (`ARG TARGETARCH`) et `lock-concordance.sh` pour les deux architectures. Au moment de la PR, amd64 était BLOCKED pour kubectl, jq et gh (empreinte absente de `toolchain.lock`) ; levé par T-332 (#106), concordance amd64 PASS vérifiée le 2026-11-18.
