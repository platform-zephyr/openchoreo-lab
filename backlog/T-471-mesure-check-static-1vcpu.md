---
id: T-471
title: "Mesure de check --static sous 1 vCPU et 1 GiB"
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

# T-471 — Mesure de check --static sous 1 vCPU et 1 GiB

## Intention
Mesurer la durée et le pic mémoire de `tools/dev/check --static` sous 1 vCPU et 1 GiB (`docker run --cpus=1 --memory=1g --memory-swap=1g` ou cgroup équivalent), et consigner le résultat daté. Le script de mesure s'écrit sans docker ; son exécution demande docker : geste de Paul ou dispatch k3d.

## Périmètre de fichiers
tests/dev-factory/measure-static.sh, docs/research/SHIFT-LEFT-DEV-ENV.md, backlog/T-471-mesure-check-static-1vcpu.md

## Critères de fin
- [ ] `tests/dev-factory/measure-static.sh` existe : lance `check --static` sous limites, imprime durée, code de sortie, pic mémoire ; `shellcheck` PASS ; sans docker il imprime `NOT_TESTED`, jamais `PASS`
- [ ] Une mesure exécutée (Paul ou dispatch) : durée et pic mémoire datés consignés dans `## Notes`
- [ ] Verdict contre le budget fixé dans `docs/research/SHIFT-LEFT-DEV-ENV.md` §5 : PASS / FAIL

## Notes
Un agent sans docker livre le script et laisse le deuxième critère à `NOT_TESTED`. Ne pas passer `done` sans la mesure réelle.
