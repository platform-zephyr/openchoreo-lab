---
id: T-475
title: "Consolidation CI : fraîcheur de STATUS.md, --only partout, historique quality post-merge, tests de l'usine"
status: in-progress
phase: P0
adr: [0022, 0024]
depends_on: [T-460, T-473]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-475 — Consolidation CI : fraîcheur de STATUS.md, --only partout, historique quality post-merge, tests de l'usine

## Intention
Regrouper en une PR les suites CI de T-473, T-460, T-421, T-325, T-331 et T-467 (`ci.yaml` est un fichier chaud : un
seul agent l'écrit dans la vague) :
1. T-473 : `python3 tools/backlog/status.py --check` devient l'étape `backlog-status` de `tools/dev/check`, appelée par
   le job `backlog`.
2. T-460 critère 2 : `tools/dev/check --only <étapes>` (non hérité par les processus enfants) ; tous les jobs de mode
   `check` l'appellent, `hooks` et `quality-coverage` compris ; `CHECK_ONLY=` est refusé dans `ci.yaml`.
3. T-421 : après chaque merge sur `main`, une ligne `quality.v1` publiée en artefact `quality-history-<sha>` (90 jours),
   sans écriture sur `main`, sans effet sur le verdict.
4. Tests de l'usine jamais exécutés en CI (`tests/factory/*-test.sh`) : étape `factory` de `check`, job `dev-factory` ;
   `tests/dev-factory/ci-parity.sh` devient l'étape `ci-parity`.

## Périmètre de fichiers
.github/workflows/ci.yaml, tools/dev/check, tools/dev/check-paths.tsv, tools/dev/ci-map.tsv, tests/dev-factory/ci-parity.sh, tests/dev-factory/check-test.sh, tests/factory/run-ticket-test.sh, tests/factory/ledger-test.sh, tests/factory/overlap-test.sh, tools/factory/overlap.py, backlog/T-475-ci-consolidation-status-historique-tests-usine.md, backlog/T-460-parite-ci-check.md, backlog/T-473-vue-status-du-backlog.md, backlog/T-421-indicateurs-quality-v1.md, backlog/T-325-assistant-des-gestes-humains-une-seance.md, backlog/T-331-hooks-deterministes-garde-de-perimetre-garde.md, backlog/T-467-garde-de-recouvrement-et-disjoncteur-de-quota.md, backlog/STATUS.md

## Critères de fin
- [x] `tools/dev/check --static --only backlog-unittest,backlog,backlog-status --strict` PASS en local ; `backlog-status`
  dans le job `backlog` et dans `ci-map.tsv` — STATIC PASS 2026-11-18 (`tests/dev-factory/ci-parity.sh`)
- [x] `--only` : sélection, priorité sur `CHECK_ONLY`, forme `--only=`, usage sans liste (rc 2), non-héritage par un
  `check` enfant — STATIC PASS 2026-11-18 (`tests/dev-factory/check-test.sh`, cas ajoutés)
- [x] aucun `CHECK_ONLY=` ni `if` de job dans `ci.yaml` (hors `ci-ok`) ; toute étape réservée au push a
  `continue-on-error: true` ; cas négatifs — STATIC PASS 2026-11-18 (`tests/dev-factory/ci-parity.sh`, 19 PASS)
- [x] `hooks` et `quality-coverage` en mode `check` (plus aucun `miroir` dans `ci-map.tsv`) — STATIC PASS 2026-11-18
- [x] `tests/factory/*-test.sh` (6 scripts) tournent par l'étape `factory` (rc 125 si un test se déclare NOT_TESTED) —
  STATIC PASS 2026-11-18, 10,0 s en local
- [ ] run CI de la PR : 18 jobs verts dont `ci-ok`, durées de `dev-factory`, `hooks`, `backlog`, `quality-coverage`
  relevées, chemin critique (`platform-render`, ~53 s) inchangé
- [ ] premier push sur `main` après merge : artefact `quality-history-<sha>` présent, job `quality-coverage` vert

## Notes
Choix pour T-421 (historique) : artefact plutôt que PR automatique. Une ligne par merge n'a pas besoin d'être dans Git
avant le rapport T-323 (différé après la porte) ; 90 jours de rétention couvrent la tendance de 4 semaines. Une PR
automatique par merge (jeton d'App, comme `breaker`) doublerait le nombre de PR et de runs CI, et écrirait dans un
fichier partagé à chaque merge (conflits). L'étape vit dans `quality-coverage`, qui calcule déjà `quality.v1.json` :
aucun calcul en double. `shellcheck_issues` vient du shellcheck de l'image du runner (0.9.0, non épinglé dans ce job) :
indicatif. Suite : la consolidation des artefacts dans `docs/state/quality-history.jsonl` relève de T-323.

Pourquoi pas un job post-merge séparé : sur une PR il serait `skipped` ; hors de `needs` de `ci-ok`, la règle de
parité (tout job dans `needs`) l'interdirait ; dedans, il ferait échouer `ci-ok`. Une étape conditionnelle à
`continue-on-error` garde un job jamais `skipped` et un verdict inchangé.

Pourquoi `dev-factory` pour `factory` : le job a déjà Python et shellcheck ; il reçoit PyYAML et gitleaks (épinglé,
sha256, même version que `secrets`). Durées locales (x86_64, 2026-11-18) : `dev-factory-static` 10,1 s, `ci-parity`
1,5 s, `factory` 10,0 s ; `hooks` 10,3 s ; `coverage` 17,5 s. Durées CI avant ce ticket (run 44329062124, push
`main`) : `dev-factory` 13 s, `hooks` 16 s, `backlog` 7 s, `quality-coverage` 38 s, `platform-render` 53 s (chemin
critique). Attendu : `dev-factory` ~30 s, sous le chemin critique.

`tests/identities` et `tests/quality` tournaient déjà en CI (`identities-lint` du job `appgen`, `coverage` ;
`quality` du job `quality`) : rien à raccorder. L'étape `identities` (script `tests/identities/run.sh` absent) reste
LOCAL-ONLY. `ledger-test.sh` et `overlap-test.sh` passent en `python3 -I -B` : `-I` ignore
`PYTHONDONTWRITEBYTECODE` et laissait un `__pycache__` sous `tools/factory/` ; `overlap.py` pose `sys.dont_write_bytecode` avant
d'importer `tools/backlog/admission.py` (même cause, `tools/backlog/__pycache__`).

Implémentations publiques consultées :
- https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/action.yml | MIT | adopté |
  entrées `retention-days` et `if-no-files-found` de l'action déjà épinglée (v7.0.2).
- https://github.com/pre-commit/pre-commit/blob/ba5c4209a6d561b0dff5db24620778d2133d068e/pre_commit/main.py | MIT |
  adapté (idée) | `pre-commit run <hook>` sélectionne par argument et `SKIP` exclut par variable : `--only` reprend la
  sélection par argument, `CHECK_SKIP` reste une variable.
