---
id: T-436
title: "Labels as-code et formulaires d'issue : issues vides coupées, proposition de ticket"
status: todo
phase: P0
adr: [0012]
depends_on: [T-431]
class: REVUE
velocity: false
lane: gouvernance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-436 — Labels as-code et formulaires d'issue : issues vides coupées, proposition de ticket

## Intention
Synchroniser les labels (agent:dev, needs-paul, k3d, dependencies, stage:*, lane:*, class:*) par gh label create --force ; interdire les issues vides ; lien de contact vers le signalement privé ; formulaire « proposition de ticket » aligné sur backlog/proposals/FORMAT.md.

## Périmètre de fichiers
.github/labels.yml, .github/ISSUE_TEMPLATE/config.yml, .github/ISSUE_TEMPLATE/, tools/github/apply.sh

## Critères de fin
- [ ] labels.yml appliqué, --check sans dérive
- [ ] config.yml : blank_issues_enabled false, lien vers le signalement privé
- [ ] yamllint vert (CI), formulaire existant agent-task.yml inchangé

## Notes
Proposition GH-7 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Les issues publiques restent une entrée non fiable : seul le contenu relu par Paul avant le label agent:dev est suivi (docs/AGENT-RUNNERS.md).
