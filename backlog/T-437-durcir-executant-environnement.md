---
id: T-437
title: "Durcir l'exécutant claude-agent : environnement agent-runner, author_association, politique d'acteurs"
status: todo
phase: P0
adr: [0002, 0021]
depends_on: [T-313, T-431]
class: REVUE + MANDAT
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-437 — Durcir l'exécutant claude-agent : environnement agent-runner, author_association, politique d'acteurs

## Intention
Fermer l'exfiltration par un workflow poussé sur une branche : le secret CLAUDE_CODE_OAUTH_TOKEN passe dans l'environnement agent-runner limité à main. Ajouter le contrôle author_association de l'issue et la lecture du corps au moment du label. Politique d'exécution d'Actions : seuls Paul et les Apps déclenchent les workflows (si disponible en plan Free).

## Périmètre de fichiers
.github/workflows/claude-agent.yml, docs/AGENT-RUNNERS.md, docs/state/identities.yaml

## Critères de fin
- [ ] secret déplacé dans l'environnement ; un workflow de test poussé sur une branche ne le lit pas (essai négatif daté)
- [ ] un label posé sur une issue d'un auteur externe ne lance aucun job (essai négatif)
- [ ] politique d'acteurs : essai ou NOT_AVAILABLE consigné avec la raison

## Notes
Proposition GH-8 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Même fichier que T-313 : à faire après lui (un seul agent par fichier). MANDAT : Paul crée l'environnement et déplace le secret, sans le copier dans le chat. Inscrire le nom du secret dans le registre T-306.

Complète T-313 sans le dupliquer : T-313 livre l'exécutant minimal et reste prérequis du pilote (non alourdi) ; ici le secret passe dans l'environnement `agent-runner` limité à `main` et l'auteur de l'issue est contrôlé. Un seul agent par fichier : après T-313.
