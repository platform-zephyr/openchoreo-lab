---
id: T-334
title: "Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets réseau"
status: todo
phase: P0
adr: [0022]
depends_on: [T-061, T-332]
class: AUTONOME + MANDAT
velocity: true
lane: agents-harness
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-334 — Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets réseau

## Intention
Documenter et écrire le script d'installation de l'environnement (outils depuis toolchain.lock en moins de 5 min pour être mis en cache, aucun secret), la liste d'hôtes autorisés minimale (GitHub, registres, docs Anthropic), les variables BASH_DEFAULT_TIMEOUT_MS et BASH_MAX_TIMEOUT_MS. Paul crée l'environnement dans l'interface ; aucun secret dans les variables (lisibles par tout utilisateur).

## Périmètre de fichiers
docs/AGENT-ENVIRONMENTS.md, tools/dev/cloud-setup.sh

## Critères de fin
- [ ] script idempotent, shellcheck vert, durée mesurée < 5 min (daté)
- [ ] session cloud de preuve : `tools/dev/check --static` passe, `check-tools` joint à la PR
- [ ] la PR décrit le geste exact de Paul (nom de l'environnement, hôtes), sans valeur
- [ ] limite écrite : la VM est x86_64, la preuve arm64 reste en CI

## Notes
Le script ne tourne pas à la reprise d'une VM inactive ; les processus lancés ne survivent pas à l'expiration.

Proposé par la recherche `harness` (clé HAR-4) ; intégration 2 du 2026-11-18.
