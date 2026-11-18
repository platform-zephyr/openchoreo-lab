---
id: T-350
title: "Voie DeepSeek : spike de compatibilité et critère d'admission par le banc"
status: todo
phase: P4
adr: [0018, 0022]
depends_on: [T-061, T-164, T-311, T-346, T-386, T-388]
class: REVUE + MANDAT
velocity: false
lane: agents
stage: I7
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-350 — Voie DeepSeek : spike de compatibilité et critère d'admission par le banc

## Intention
Mesurer sur le banc une session pilotée par DeepSeek via son point d'accès compatible Anthropic (https://api.deepseek.com/anthropic ; la doc DeepSeek indique `mcp_servers` ignoré et remappage des noms claude-* vers ses modèles : donc MCP et choix de modèle par nom à tester). Anthropic ne supporte pas le routage de Claude Code vers un modèle non-Claude : voie non supportée, admise seulement si pass^3 ≥ 0,8 sur les types N0 retenus, hors noyau ; clé en secret du dépôt.

## Périmètre de fichiers
docs/research/DEEPSEEK-LANE.md, tools/bench/, .github/workflows/ (voie dédiée)

## Critères de fin
- [ ] rapport de compatibilité daté : fonctionnalités testées / non testées
- [ ] pass@1 et pass^3 par type de ticket, comparés à sonnet et haiku
- [ ] règle écrite : types de tickets admis, noyau et MANDAT exclus, plafond de dépense
- [ ] cas négatif : une PR du noyau lancée par cette voie reste non fusionnable

## Notes
La clé est un secret : GitHub secret ou secret réseau, jamais dans le dépôt. Les sessions cloud (`--cloud`) ne sont pas disponibles avec un fournisseur tiers : voie runner seulement.

Proposé par la recherche `harness` (clé HAR-20) ; intégration 2 du 2026-11-18.
