---
id: T-473
title: "Vue d'état du backlog : fait, en cours, bloqué, prêt (backlog/STATUS.md généré)"
status: in-progress
phase: P0
adr: [0012]
depends_on: []
class: REVUE
velocity: false
lane: backlog
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-473 — Vue d'état du backlog : fait, en cours, bloqué, prêt

## Intention
Donner à Paul une page unique, lisible et à jour de ce qui est fait, en cours et à faire. `tools/backlog/status.py` lit les tickets en lecture seule et génère `backlog/STATUS.md` : compteurs par statut, tickets `done` (date et preuve citées dans les notes), `in-progress` (ligne « Reste », cases X/Y), `blocked` (blocage), `todo` prêts ou bloqués par dépendance, lien vers l'issue GitHub quand `github_issue` est renseigné. Sortie déterministe, sans horodatage de génération.

## Périmètre de fichiers
tools/backlog/status.py, tests/backlog/test_status.py, backlog/STATUS.md, backlog/README.md, backlog/T-473-vue-status-du-backlog.md

## Critères de fin
- [x] `python3 tools/backlog/status.py` imprime la vue ; `--write` écrit `backlog/STATUS.md` ; `--check` rend rc 1 si le fichier est absent ou périmé
- [x] tests avec cas négatifs : ticket sans critères, dépendance inconnue, en-tête illisible, `--check` périmé, déterminisme et ordre naturel
- [x] `backlog/README.md` : une ligne de lien vers `STATUS.md`
- [x] brancher `python3 tools/backlog/status.py --check` dans la CI (job `backlog` de `ci.yaml`, REVUE, point chaud : PR dédiée, sérialisée avec T-460) et dans `tools/dev/check` / `ci-map.tsv` (STATIC PASS 2026-11-18, T-475 : étape `backlog-status` de `check`, job `backlog` en `--only backlog-unittest,backlog,backlog-status`, parité PASS)
- [ ] régénérer `backlog/STATUS.md` à chaque PR qui change un ticket (une fois `--check` en CI, la CI l'impose)

## Notes
Art antérieur (prior-art, niveau complet) : NOT_TESTED. L'accès GitHub de la session était refusé (`gh api` : 403, dépôts non attachés) ; aucun permalien SHA40 n'a pu être vérifié. Pistes connues, non consultées : `adr generate toc` d'adr-tools et l'index de log4brains pour les ADR (génération d'index depuis des fichiers Markdown), Backlog.md pour un backlog en fichiers. Local : `roadmap.py` (ROADMAP.md) et `next.py` (prêts) ; `status.py` réutilise `check.parse_ticket` et ne duplique pas le graphe de `next.py`. Décision : code propre, car aucun outil amont ne lit ces en-têtes et ces conventions (« Reste », « Bloqué par »).

Reste : critère 5, imposé par la CI dès la fusion de T-475 (run CI de la PR non encore observé).

`--check` est prêt pour la CI : sans argument réseau, sans dépendance hors bibliothèque standard, rc 0 ou 1, message sur stderr, aucune écriture. Date d'un ticket `done` : la plus récente date ISO écrite dans ses notes (sinon `—`) ; preuve : fichiers `evidence/` et `PR #n` cités dans le ticket, pas une vérification runtime.
