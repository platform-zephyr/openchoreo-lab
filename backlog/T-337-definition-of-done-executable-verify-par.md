---
id: T-337
title: "Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée"
status: todo
phase: P0
adr: [0012, 0022]
depends_on: [T-008, T-061, T-332]
class: REVUE
velocity: true
lane: backlog-outils
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-337 — Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée

## Intention
Chaque critère de fin porte une commande `verify:` (code 0 = PASS) ou la mention `manual`. `done.py T-NNN` exécute, écrit backlog/evidence/T-NNN.json (statuts PASS/FAIL/NOT_TESTED/BLOCKED, date, niveau de preuve). La CI refuse `status: done` sans preuve PASS ; un critère `manual` reste NOT_TESTED.

## Périmètre de fichiers
tools/backlog/done.py, tools/backlog/check.py, backlog/README.md, backlog/evidence/

## Critères de fin
- [ ] 3 tickets existants migrés vers `verify:` comme exemples
- [ ] cas négatif : `status: done` sans evidence fait échouer le check
- [ ] le hook Stop de T-331 lance `done.py --dry` quand un ticket est `in-progress`

## Notes
Inspiré de la liste de fonctionnalités JSON d'Anthropic (seul `passes` modifiable). Les critères MANDAT restent manuels.

Proposé par la recherche `harness` (clé HAR-7) ; intégration 2 du 2026-11-18.
