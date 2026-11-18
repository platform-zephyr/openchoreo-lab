---
id: T-331
title: "Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop"
status: todo
phase: P0
adr: [0022]
depends_on: [T-061, T-303, T-330, T-332]
class: REVUE
velocity: true
lane: agents-harness
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-331 — Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop

## Intention
PreToolUse Bash (refus des commandes cluster, curl|sh, --no-verify, push forcé), PreToolUse Edit|Write (refus hors périmètre du ticket, de generated/ et du noyau), PostToolUse (yamllint/appgen validate du fichier touché), Stop (`tools/dev/check --static`, exit 2 avec sortie en stderr), SessionStart (ticket, branche, dernier CI). Type `command` uniquement.

## Périmètre de fichiers
.claude/hooks/, .claude/settings.json (section hooks), tests/hooks/

## Critères de fin
- [ ] tests/hooks/ : une entrée JSON par cas (autorisé et refusé) ; code de sortie attendu ; exécuté en CI
- [ ] le hook Stop bloque sur un yaml invalide et laisse finir sur un dépôt propre (preuve de session)
- [ ] aucun hook `prompt` ou `agent` pour une règle sans exception
- [ ] chaque hook s'exécute en moins de 5 s sur un dépôt propre (mesure datée)

## Notes
PostToolUse ne peut pas bloquer ; Stop est débloqué après 8 blocs consécutifs (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP). Le périmètre vient de la section `Périmètre de fichiers` du ticket.

Proposé par la recherche `harness` (clé HAR-1) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).
