---
id: T-519
title: "Orchestration consolidée : le rôle une seule fois"
status: todo
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-519 — Orchestration consolidée : le rôle une seule fois

## Intention
Décision de Paul (2026-11-19, « je suis tes recommandations ») : le rôle de l'orchestrateur n'est décrit qu'une fois (`docs/ORCHESTRATION.md`) ; le skill se réduit aux commandes. Aucune règle de fond ne change.

## Périmètre de fichiers
docs/ORCHESTRATION.md, .agents/skills/orchestrate-backlog/SKILL.md, .agents/skills/read-app-status/SKILL.md, AGENTS.md, backlog/T-519-orchestration-consolidee.md

## Critères de fin
- [x] Rôle décrit une fois ; skill réduit aux commandes et renvois ; moins de lignes qu'avant
- [x] Contradiction corrigée : la preuve OKE est déléguée à un opérateur ; double numéro 5 renuméroté
- [x] `read-app-status` : `gh` exige une session authentifiée (plus de « aucun identifiant »)
- [x] `AGENTS.md` : périmètre cluster `openchoreo-*`, `lab-*`, `svc-<app>` du bras K, noms explicites (E1)
- [x] Skill : section « Comportement attendu » ; ORCHESTRATION.md : section « Lancement » (prompt versionné, sans autorisation) ; AGENTS.md : renvoi vers le skill d'orchestration
- [ ] `tools/dev/check --static --changed` et `python3 tools/backlog/check.py` : verdict reporté dans la PR

## Notes
Documentation seulement. Hors périmètre : `tools/appgen/`, `tools/oke/argo_guard*`, ADR.
