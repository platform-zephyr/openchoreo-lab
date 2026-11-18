---
id: T-008
title: "Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort`"
status: todo
phase: P0
adr: [0012]
depends_on: []
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-008 — Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort`

## Intention
Valider l'en-tête des tickets : id unique, statut connu, dépendances existantes et sans cycle, ADR existant. Valide aussi `stage`, `model` (ID complet épinglé ou `human`) et `effort`, et leur cohérence avec la règle de routage (ADR-0023 : 3 règles).

## Périmètre de fichiers
tools/backlog/check.py, tests/backlog/, backlog/README.md, backlog/proposals/FORMAT.md, .github/workflows/ci.yaml (REVUE)

## Critères de fin
- [ ] script + tests
- [ ] job ajouté à la CI (PR REVUE pour `.github/`)
- [ ] (repris de FAC-15) check.py refuse un modèle inconnu ; un ticket REVUE sur le noyau sans model opus déclenche un avertissement
- [ ] (repris de FAC-15) backlog/README.md décrit le champ
- [ ] (repris de MOD-2) backlog/README.md documente les deux champs ; FORMAT.md reste compatible
- [ ] (repris de MOD-2) test : `model: claude-unknown` → check.py rouge ; effort `max` sur Sonnet → avertissement (plafond xhigh)
- [ ] (repris de HAR-5) T-008 refuse un ticket sans globs exploitables

## Notes
Intégration 2 : la présence de `model`/`effort` est déjà vérifiée par tools/backlog/check.py (2026-11-18) ; restent les tests, le job CI requis et le refus des valeurs inconnues en CI.
