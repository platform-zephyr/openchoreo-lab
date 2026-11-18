---
id: T-389
title: "agentgateway : fournisseur DeepSeek, clés virtuelles par usage, budget bloquant (fournisseur factice d'abord)"
status: deferred
phase: P5
adr: [0018, 0023]
depends_on: [T-023, T-061, T-161, T-388]
class: REVUE + MANDAT
velocity: false
lane: ai-gateway
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-389 — agentgateway : fournisseur DeepSeek, clés virtuelles par usage, budget bloquant (fournisseur factice d'abord)

## Intention
Ajouter les fournisseurs `anthropic` et `deepseek` (intégré ; `baseUrl` https://api.deepseek.com/anthropic si Claude Code passe par le gateway, pour éviter la conversion Messages vers Chat Completions) avec clés virtuelles, restriction de modèles (deepseek-flash seulement) et budget bloquant ; bascule Haiku ↔ Flash ; la clé de fournisseur n'existe que dans le namespace du gateway.

## Périmètre de fichiers
platform/ai-gateway/, tests/k3d/

## Critères de fin
- [ ] k3d, fournisseur factice : routage par modèle, bascule sur panne, budget dépassé → blocage, clé révoquée → 401
- [ ] fournisseur réel seulement après MANDAT (création de la clé DeepSeek, plafond mensuel côté console) ; appel de test journalisé avec agent_id et tokens

## Notes
agentgateway 1.7 (docs lues le 2026-11-18) : route /v1/messages native avec conversion vers Chat Completions, clés virtuelles et budgets documentés ; la bascule entre fournisseurs (Resiliency) reste à prouver en k3d.

Proposé par la recherche `model-routing` (clé MOD-10) ; intégration 2 du 2026-11-18.

DeepSeek : après le chantier (arbitrage 5 de Paul, 2026-11-18) ; tous les agents de dev sont Claude.
