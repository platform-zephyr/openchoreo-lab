---
id: T-509
title: "Orchestration parallèle capitalisée : docs/ORCHESTRATION.md et skill orchestrate-backlog à jour"
status: in-progress
phase: P1
adr: [0021]
depends_on: []
class: AUTONOME
velocity: true
lane: agents
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-509 — Orchestration parallèle

## Intention
Paul veut un seul orchestrateur Claude sur son Mac, qui dispatche massivement en parallèle (sessions cloud,
sous-agents, usine, k3d) et ferme la boucle jusqu'à la preuve OKE. Capitaliser ce que l'orchestration cloud du
2026-11-18/19 a appris, pour qu'un orchestrateur neuf ne le redécouvre pas. Documentation seulement.

## Périmètre de fichiers
docs/ORCHESTRATION.md, .agents/skills/orchestrate-backlog/SKILL.md, backlog/T-509-orchestration-parallele.md

## Critères de fin
- [x] `docs/ORCHESTRATION.md` : principes de Paul, topologie, cycle et section « Preuve OKE demandée », découpage, capacités et limites mesurées, recettes, anti-patterns (un tableau par sujet, ≤ 4 pages)
- [x] skill `orchestrate-backlog` : renvoi vers `docs/ORCHESTRATION.md`, orchestrateur unique sur le Mac, couloirs cloud par `create_session`
- [x] `tools/dev/check --static --changed` lancé, verdict reporté dans la PR

## Notes
Sources : handoffs de l'orchestrateur cloud du 2026-11-18 et du 2026-11-19 (hors dépôt, éphémères), `docs/CLOUD-AGENTS.md`,
`docs/AGENT-RUNNERS.md`, `docs/CI-K3D.md`. Mesures de capacité au niveau `USER` (observées), non rejouées par ce ticket.
Aucun identifiant de session écrit dans le dépôt.
