---
id: T-390
title: "Garde de confidentialité : aucun log de production ni secret vers un fournisseur autre qu'Anthropic"
status: deferred
phase: P5
adr: [0008, 0018, 0023]
depends_on: [T-025, T-061, T-389]
class: REVUE
velocity: false
lane: admission
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-390 — Garde de confidentialité : aucun log de production ni secret vers un fournisseur autre qu'Anthropic

## Intention
Faire respecter `deepseek_denied_data` : le gateway refuse une clé DeepSeek pour tout consommateur étiqueté `data-class` ≠ public ou lisant des logs de production ; test d'injection d'un faux log.

## Périmètre de fichiers
platform/ai-gateway/, platform/policies/, tests/k3d/

## Critères de fin
- [ ] test k3d : consommateur data-class `internal` demandant `deepseek-*` → refus ; modèle Claude → accepté
- [ ] allowlist modifiée sans revue → CI rouge

## Notes
Noyau : plancher Opus (R01), revue adverse.

Proposé par la recherche `model-routing` (clé MOD-11) ; intégration 2 du 2026-11-18.

DeepSeek : après le chantier (arbitrage 5 de Paul, 2026-11-18) ; tous les agents de dev sont Claude.
