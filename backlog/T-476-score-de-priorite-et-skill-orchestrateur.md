---
id: T-476
title: "Score de priorité du backlog (priority.py) et skill orchestrate-backlog"
status: in-progress
phase: P0
adr: [0012]
depends_on: []
class: REVUE
velocity: true
lane: backlog
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-476 — Score de priorité du backlog et skill orchestrateur

## Intention
Donner un ordre simple aux tickets prêts et permettre à un orchestrateur sans mémoire de reprendre seul. Score = nombre de tickets non `done` ni `dropped` débloqués directement ou transitivement (descendants dans `depends_on`). Tie-break : étape, périmètre le plus petit, id ; un ticket `human` ou MANDAT passe après les tickets exécutables. Le skill `orchestrate-backlog` rassemble la procédure de reprise, de choix, de dispatch et de fusion.

## Périmètre de fichiers
tools/backlog/priority.py, tools/backlog/status.py, tools/backlog/next.py, tests/backlog/test_priority.py, tests/backlog/test_next.py, backlog/STATUS.md, .agents/skills/orchestrate-backlog/SKILL.md, AGENTS.md, backlog/T-476-score-de-priorite-et-skill-orchestrateur.md

## Critères de fin
- [x] `tools/backlog/priority.py` : fonction réutilisable, CLI `--top N`, `--json`, `--all` ; dépendance inconnue ou cycle = `PriorityError` (code 2)
- [x] tests avec cas négatifs : cycle, dépendance inconnue, ticket isolé, chaîne, diamant, tickets `done` et `dropped` ignorés, rétrogradation `human`
- [x] `status.py` : colonne « Score », `todo` prêts triés par score ; `next.py` : ordre des prêts par score (champ `score` ajouté à `ready.v1`) ; tests existants verts
- [x] skill `.agents/skills/orchestrate-backlog/SKILL.md` (moins de 120 lignes) et une ligne dans `AGENTS.md`
- [ ] brancher `python3 tools/backlog/priority.py` (exit 2 sur graphe invalide) dans `tools/dev/check` / `ci-map.tsv` et le job `backlog` de `ci.yaml` (point chaud : PR dédiée, après T-475 et T-460)
- [ ] mesurer sur 3 lots réels si l'ordre par score réduit les tickets bloqués en attente ; sinon ajuster la formule (un terme à la fois)

## Notes
Reste : critères 5 et 6 (branchement CI hors périmètre de cette PR, T-475 modifie `ci.yaml` en parallèle ; mesure sur lots réels).

Art antérieur (prior-art, niveau complet) : NOT_TESTED en permalien SHA40, aucune requête réseau faite depuis cette session. Sources de méthode citées de mémoire : CPM, Kelley et Walker (1959) ; WSJF de SAFe (scaledagileframework.com/wsjf) ; RICE d'Intercom ; coefficient `blocking` de l'urgence de Taskwarrior. Décision : WSJF et RICE demandent des notes de valeur et de taille que ce backlog n'a pas ; le nombre de descendants non terminés est la mesure du chemin critique la plus simple et sans estimation. Code propre (stdlib, `graphlib`), car aucun outil amont ne lit ces en-têtes.

Limite connue : le score compte les tickets, pas leur taille ; un ticket qui débloque 5 tickets triviaux passe devant un ticket qui en débloque 4 gros. Acceptable tant que tout sera traité.
