---
id: T-419
title: "Retirer `tools/backlog/seed.py` (1 201 lignes de données, vestige) et le code mort ≥ 80 %"
status: todo
phase: P0
adr: [0024]
depends_on: [T-412, T-414, T-415, T-418, T-214]
class: AUTONOME
velocity: false
lane: backlog
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-419 — Retirer `tools/backlog/seed.py` (1 201 lignes de données, vestige) et le code mort ≥ 80 %

## Intention
Le README du backlog le dit « à remplacer par l'édition directe » ; il pèse 1 201 lignes à indice de maintenabilité 0. Vérifier qu'aucun outil ni document ne le référence, le supprimer, ajouter `vulture --min-confidence 80` en CI (1 trouvaille aujourd'hui : import inutile).

## Périmètre de fichiers
tools/backlog/seed.py, backlog/README.md, tools/README.md, .github/workflows/ci.yaml (vulture)

## Critères de fin
- [ ] `grep -r seed.py` ne trouve plus de référence ; `check.py` et `roadmap.py` passent sur le backlog réel
- [ ] `vulture tools tests --min-confidence 80` : 0 trouvaille, job CI
- [ ] les 7 candidats à 60 % examinés, supprimés ou listés dans une liste blanche motivée
- [ ] `seed.py` génère le backlog par patchs successifs : avant suppression, un diff de `rm -f backlog/T-*.md && seed.py` contre `backlog/` ne montre aucune différence utile (statuts et cases cochées déjà portés par les fichiers)
- [ ] à la réalisation : `check.py`, `roadmap.py` et `identities_lint.py` restent ; `seed.py` disparaît ; les tickets deviennent la source, édités directement (`backlog/README.md` : plus de procédure de régénération)

## Notes
Proposition QA-9 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Vérifier avant suppression que seed.py ne génère plus aucun fichier encore utile (diff du backlog).

Placé APRÈS tous les autres tickets QA de S1 (T-412, T-414, T-415, T-418) et T-214 : tant que des intégrations de propositions passent par seed.py, il reste l'outil de génération. Toute nouvelle intégration de propositions après ce ticket se fait par édition directe des fichiers de tickets suivie de `check.py` et `roadmap.py`. Statuts et cases cochées sont déjà dans les fichiers : rien à migrer.
