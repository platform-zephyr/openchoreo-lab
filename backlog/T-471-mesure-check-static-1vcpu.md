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
- [x] `tests/dev-factory/measure-static.sh` existe : lance `check --static` sous limites, imprime durée, code de sortie, pic mémoire ; `shellcheck` PASS ; sans docker il imprime `NOT_TESTED`, jamais `PASS`
- [x] Une mesure exécutée (Paul ou dispatch) : durée et pic mémoire datés consignés dans `## Notes`
- [x] Verdict contre le budget fixé dans `docs/research/SHIFT-LEFT-DEV-ENV.md` §5 : PASS / FAIL : **FAIL** (200,5 s > 90 s), voir `## Notes`
- [ ] Mesure sous `docker run --cpus=1 --memory=1g --memory-swap=1g` dans l'image du devcontainer (démon Docker absent de la VM cloud : `NOT_TESTED`) : geste de Paul ou dispatch k3d
- [ ] Budget L2 tenu (< 90 s sous 1 vCPU) : hors périmètre de T-471 (levier connu : T-451 `CSafeLoader`, `--jobs` n'aide pas à 1 vCPU) ; ticket à ouvrir si aucun autre ne le porte

## Notes
Un agent sans docker livre le script et laisse le deuxième critère à `NOT_TESTED`. Ne pas passer `done` sans la mesure réelle.

Mesure du 2026-11-18 (SHA 0ee6168, VM cloud x86_64, sans démon Docker), `tests/dev-factory/measure-static.sh --mode cgroup` : cgroup v1 créé par le script, quota cpu 100000/100000, mémoire et swap (memsw) 1 GiB, limites relues avant lancement. Deux exécutions : 200,5 s et 200,8 s ; pic mémoire 244 et 228 MiB (cache de pages compris) ; code 0 ; 33 PASS, 0 FAIL, 2 NOT_TESTED (`guard-check` hors conteneur de dev, `identities` absent) ; `RESULT: INCOMPLET`. Verdict contre le budget L2 (`docs/research/SHIFT-LEFT-DEV-ENV.md` §2, le ticket cite §5 par erreur) : FAIL sur la durée, mémoire tenue. Écarts : cgroup équivalent et non `docker run` ; outillage de la VM et non image du devcontainer ; hors limites, `--mode partial` (taskset -c 0) 203,5 s, pic 224 MiB, sans verdict. Sans démon, `--mode docker` imprime `NOT_TESTED` (code 3), vérifié.
