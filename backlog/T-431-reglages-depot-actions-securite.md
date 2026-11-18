---
id: T-431
title: "Réglages du dépôt, d'Actions et de sécurité as-code (repo, actions, security JSON)"
status: todo
phase: P0
adr: [0002, 0006]
depends_on: [T-430]
class: REVUE + MANDAT
velocity: true
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-431 — Réglages du dépôt, d'Actions et de sécurité as-code (repo, actions, security JSON)

## Intention
Versionner et appliquer : squash seul, auto-merge, suppression des branches fusionnées, wiki/Discussions/Pages coupés ; GITHUB_TOKEN en lecture, PR par Actions interdites, allowlist d'actions, SHA complet obligatoire, approbation des workflows de forks pour tous les externes ; secret scanning, push protection, Dependabot alerts et security updates, signalement privé, CodeQL default setup (python, actions).

## Périmètre de fichiers
.github/settings/repo.json, .github/settings/actions.json, .github/settings/security.json, tools/github/apply.sh

## Critères de fin
- [ ] --check dev PASS après application par Paul (lecture datée, sans jeton affiché)
- [ ] champs sha_pinning_required et fork-pr-contributor-approval validés sur l'API réelle, sinon repli documenté (NOT_TESTED levé)
- [ ] CodeQL default setup actif sur python et actions ; une alerte factice ou un run vert prouvé
- [ ] un workflow qui utilise une action hors allowlist échoue (essai daté)
- [ ] aucun dependabot.yml de version updates (Renovate seul)

## Notes
Proposition GH-2 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). MANDAT : exécution par Paul. L'allowlist liste actions/*, github/codeql-action/*, anthropics/claude-code-action ; tout ajout passe par le noyau.
