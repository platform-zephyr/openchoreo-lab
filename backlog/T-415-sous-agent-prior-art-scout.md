---
id: T-415
title: "Sous-agent `prior-art-scout` (lecture seule, budget borné)"
status: todo
phase: P0
adr: [0024]
depends_on: [T-411, T-330, T-341]
class: REVUE
velocity: false
lane: agents-harness
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-415 — Sous-agent `prior-art-scout` (lecture seule, budget borné)

## Intention
Isoler la recherche hors du contexte principal : outils `Read, Grep, Glob, WebFetch, Bash(gh api search/*), Bash(gh api repos/*)` seulement, `maxTurns` 12, retour ≤ 30 lignes au format de la section de PR, plafond de 8 requêtes.

## Périmètre de fichiers
.claude/agents/prior-art-scout.md, tests/hooks/

## Critères de fin
- [ ] aucune permission d'écriture ni de `kubectl`/`curl` libre dans le fichier (test statique)
- [ ] essai daté : retour ≤ 30 lignes et ≤ 2 k tokens sur 3 tickets `complet` ; tokens du sous-agent consignés

## Notes
Proposition QA-5 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Un sous-agent de plugin ignore hooks et permissionMode : le définir au niveau du projet (AGENT-HARNESS §2.4).

Même dossier `.claude/agents/` que T-341 : sérialisé après lui.
