---
id: T-480
title: "Garde de taille des tickets : avertissement de check.py au-delà de ce qu'un run absorbe"
status: todo
phase: P0
adr: [0012, 0021]
depends_on: []
class: AUTONOME
velocity: true
lane: backlog
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 87
---
# T-480 — Garde de taille des tickets

## Intention
Éviter les tickets trop gros pour un run d'agent (`docs/research/FACTORY-PRIOR-ART.md` R3). Idées reprises sans code : ccpm
(MIT) borne une épopée à 10 tâches avec `depends_on` et `conflicts_with` ; le skill « software-factory » (gist sans licence)
découpe en tranches verticales. `sizing.py` calcule une taille par ticket actif et `check.py` émet un **avertissement**
(jamais une erreur) au-delà des seuils initiaux : plus de 8 éléments de périmètre, plus de 6 critères de fin, ou un glob `**`
sur un répertoire de code (`tools/`, `platform/`, `.github/`). Le message propose de scinder.

## Périmètre de fichiers
tools/backlog/sizing.py, tests/backlog/test_sizing.py, tools/backlog/check.py

## Critères de fin
- [ ] `tools/backlog/sizing.py` : fonction réutilisable et CLI `--json` (taille et motifs par ticket) ; seuils en constantes nommées
- [ ] `check.py` émet un avertissement par ticket `todo` ou `in-progress` hors seuils ; aucune nouvelle erreur ; tickets `done`, `dropped`, `deferred` ignorés
- [ ] tests avec cas négatifs : périmètre `hors de ce dépôt`, commentaire entre parenthèses, ticket sans critère, glob `**` sous `docs/` (pas d'avertissement)
- [ ] `python3 tools/backlog/check.py` sur le backlog actuel : nombre d'avertissements ajoutés relevé dans la PR (pas de bruit massif ; sinon ajuster un seuil à la fois)
- [ ] `python3 -m unittest discover -s tests/backlog` PASS ; cliquet `tools/quality/check.py` PASS

## Notes
Seuils à recalibrer avec les données de T-479 (tours par ticket selon la taille). `check.py` est aussi dans le périmètre de
T-337 (todo) : ne pas les lancer en parallèle.
