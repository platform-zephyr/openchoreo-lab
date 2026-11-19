---
id: T-516
title: "Rôle de l'orchestrateur (déléguer) et journal des frictions"
status: todo
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-516 — Rôle de l'orchestrateur (déléguer) et journal des frictions

## Intention
Paul a corrigé le rôle de l'orchestrateur : il délègue systématiquement (dispatcher, synchroniser, réfléchir) et n'exécute pas. Écrire ce rôle, la règle STOP, le brief de l'opérateur OKE et la cadence, puis tenir un journal des frictions récurrentes pour n'améliorer que sur preuve.

## Périmètre de fichiers
docs/ORCHESTRATION.md, docs/research/FRICTIONS-ORCHESTRATION.md, .agents/skills/orchestrate-backlog/SKILL.md, backlog/T-516-role-orchestrateur-frictions.md

## Critères de fin
- [ ] `docs/ORCHESTRATION.md` § 2 réécrit et section « Rôle de l'orchestrateur » ajoutée (tableau, règle STOP, brief opérateur OKE, cadence)
- [ ] `docs/research/FRICTIONS-ORCHESTRATION.md` créé, amorcé avec les frictions du 2026-11-19
- [ ] Skill `orchestrate-backlog` : ligne de délégation et cadence de réflexion en tête
- [ ] `tools/dev/check --static --changed` et `python3 tools/backlog/check.py` : verdict reporté dans la PR

## Notes
Documentation seulement. Aucun secret, OCID, IP, hôte interne ni identifiant de session.
