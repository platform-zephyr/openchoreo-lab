---
id: T-507
title: "Lecteur de statut réduit à un appel gh api documenté dans le skill read-app-status"
status: todo
phase: P1
adr: [0024]
depends_on: [T-497]
class: AUTONOME
velocity: false
lane: acces-mcp
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-507 — Lecteur de statut simple

## Intention
Décision de Paul : maintenabilité avant richesse. Remplacer `tools/status/app_status.py` (357 lignes, cache, ETag,
schéma `app-checkrun.v1`) par un appel `gh api` sur le check run `argocd/<application>`, documenté dans le skill.

## Périmètre de fichiers
tools/status/app_status.py, tests/status/test_app_status.py, tests/status/fixtures/, tests/registry.yaml (ligne status-reader), .agents/skills/read-app-status/SKILL.md, backlog/T-497-lecteur-statut-check-runs.md, backlog/T-507-lecteur-statut-simple.md

## Critères de fin
- [x] outil Python, tests et fixtures supprimés ; une seule ligne retirée de `tests/registry.yaml`
- [x] skill : commande `gh api` filtrée, garde « app non déployée » en shell, interprétation success/pending/failure/absent, règle ≥ 1 min
- [x] aucun consommateur de `app_status.py` ou `app-checkrun.v1` restant hors historique (`git grep`)
- [x] note datée dans T-497

## Notes
`tests/status/install-notifications.sh` est conservé : il teste `tools/oke/install.sh`, pas le lecteur.
