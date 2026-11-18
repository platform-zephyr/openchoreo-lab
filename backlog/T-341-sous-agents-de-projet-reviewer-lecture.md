---
id: T-341
title: "Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager`"
status: todo
phase: P0
adr: [0022]
depends_on: [T-330, T-337]
class: REVUE
velocity: true
lane: agents-harness
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-341 — Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager`

## Intention
`reviewer` : outils Read/Grep/Glob/Bash lecture seule, contexte neuf, compare le diff aux critères du ticket et aux garde-fous (platform-guardrails) avant l'ouverture de la PR (évaluateur-optimiseur). `ci-triager` (haiku) : lit les journaux d'un job rouge et rend une cause. Pas d'imbrication (Agent absent de leurs outils), maxTurns borné, définis en projet (un sous-agent de plugin ignore hooks et permissionMode).

## Périmètre de fichiers
.claude/agents/, tests/hooks/agents.test.sh

## Critères de fin
- [ ] test statique : frontmatter valide, `tools` sans Write/Edit pour reviewer, Agent exclu
- [ ] essai daté : le reviewer détecte une PR volontairement hors périmètre (cas négatif)
- [ ] le coût d'une revue (tokens, durée) est mesuré et inférieur à 20 % de celui du ticket

## Notes
Répertoire noyau (.claude/). Les sous-agents sont un accélérateur de retour, pas une frontière de sécurité.

Proposé par la recherche `harness` (clé HAR-11) ; intégration 2 du 2026-11-18.
