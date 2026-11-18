---
id: T-472
title: "Build périodique du devcontainer hors ci-ok"
status: todo
phase: P0
adr: [0022]
depends_on: [T-470]
class: REVUE
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-472 — Build périodique du devcontainer hors ci-ok

## Intention
Construire le devcontainer en amd64 et arm64 sur un calendrier (workflow `schedule` + `workflow_dispatch`), hors du chemin requis `ci-ok`. Un build rouge produit un signal visible sans bloquer les PR.

## Périmètre de fichiers
.github/workflows/devcontainer-build.yaml, tests/dev-factory/run.sh, tests/dev-factory/lock-concordance.sh, .devcontainer/Dockerfile, tools/dev/toolchain.lock, docs/DEV-FACTORY.md

## Critères de fin
- [x] Nouveau workflow `devcontainer-build.yaml` : `schedule` + `workflow_dispatch`, matrice amd64/arm64, actions épinglées par SHA, permissions minimales, absent de `ci-ok` (preuve statique 2026-11-18 : `tests/dev-factory/run.sh` PASS)
- [x] `actionlint` et `yamllint` : PASS (`tools/dev/check --static --changed`, 2026-11-18, actionlint 0.2s, yamllint 0.4s)
- [x] Premier dispatch réel sur `main` (2026-11-18, run 44365234940) : FAIL en amd64 et arm64 à `apt-get install` (« E: Packages were downgraded and -y was used without --allow-downgrades ») ; cause : paquets épinglés sur l'archive vivante, plus anciens que ceux de l'image de base (xz-utils 5.4.1-1+deb12u1 contre liblzma5 5.4.1-1+deb12u2, etc.) — https://github.com/platform-zephyr/openchoreo-lab/actions/runs/44365234940
- [x] Correctif statique : sources apt réécrites vers snapshot.debian.org à l'instant de l'image de base (`DEBIAN_SNAPSHOT=20261104T212339Z`, lock + Dockerfile), versions de cet instant (ca-certificates 20250419~deb12u2, xz-utils 5.4.1-1+deb12u2) ; `lock-concordance.sh` contrôle l'épinglage, sans réseau — STATIC, 2026-11-18, build non exécuté
- [ ] Un second dispatch daté, après fusion du correctif, construit les deux architectures : run vert en amd64 ET arm64 (lien du run) ; sans ce dispatch : `NOT_TESTED`

## Notes
Ne pas modifier `ci.yaml` ni `.github/workflows/claude-agent.yml`. Prior-art (ADR-0024) avant d'écrire le workflow.
