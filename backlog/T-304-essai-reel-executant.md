---
id: T-304
title: "Essai réel de l'exécutant avant l'heure 0 : push d'un workflow, check.py sur runner, auto-merge, identité `workflows`"
status: done
phase: P0
adr: [0002, 0021]
depends_on: [T-008, T-210, T-306, T-311, T-313]
class: REVUE + MANDAT
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-304 — Essai réel de l'exécutant avant l'heure 0 : push d'un workflow, check.py sur runner, auto-merge, identité `workflows`

## Intention
Prouver, avant le pilote, que l'exécutant peut faire ce que la liste figée exige : pousser un fichier sous `.github/workflows/`, lancer `check.py` sur un runner hébergé, armer l'auto-merge GitHub. En mode dev, l'exécutant utilise une identité qui a la permission `workflows` (App ou jeton fin de Paul, arbitrage 7) ; elle est remplacée à FINAL0 (T-215).

## Périmètre de fichiers
.github/workflows/claude-agent.yml, docs/AGENT-RUNNERS.md, backlog/evidence/

## Critères de fin
- [x] MANDAT Paul : identité de l'exécutant avec la permission `workflows` fournie (secret d'environnement, jamais dans le chat), inscrite par son nom dans `docs/state/identities.yaml` (T-306)
- [x] essai daté : une PR de l'exécutant qui modifie un fichier sous `.github/workflows/` est poussée sans refus
- [x] essai daté : `python3 tools/backlog/check.py` sur un runner hébergé lit tous les tickets (> 0) et sort 0 erreur
- [x] essai daté : l'exécutant arme l'auto-merge GitHub ; la PR fusionne seule après `ci-ok` (mode dev, arbitrage 7)
- [x] (sans objet : le push a réussi) si le push d'un workflow échoue : T-002, T-216, T-321 et T-314 sortent de la liste figée (sessions de Paul) et sont remplacés avant l'heure 0

## Notes
Constat P1 de la revue Fable, accepté (arbitrage Fable, 2026-11-18). Preuves dans `backlog/evidence/`, sans jeton ni sortie d'outil.

Preuve : `backlog/evidence/T-304-essai-executant-2026-11-18.md` (run réel, PR #63 fusionnée seule par la file).
