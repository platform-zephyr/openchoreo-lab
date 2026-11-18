---
id: T-388
title: "Registre des modèles et tarifs : docs/state/model-prices.yaml avec date de lecture et lint à 90 jours (sources DeepSeek déjà lues)"
status: todo
phase: P1
adr: [0017, 0023]
depends_on: [T-061]
class: AUTONOME + MANDAT
velocity: false
lane: veille
stage: S2
model: claude-haiku-5-5
effort: low
routing: R15-veille-releases
github_issue: null
---
# T-388 — Registre des modèles et tarifs : docs/state/model-prices.yaml avec date de lecture et lint à 90 jours (sources DeepSeek déjà lues)

## Intention
Consigner prix, contexte, effort par défaut et date de retrait des modèles Claude 5 et DeepSeek avec source et date (lues le 2026-11-18 : voir MODEL-ROUTING.md §3), plus les scores Terminal-Bench 4.1 ; lire les conditions de la plateforme API DeepSeek (illisibles le 2026-11-18) pour trancher la rétention des données API.

## Périmètre de fichiers
docs/state/model-prices.yaml, tools/backlog/lint_prices.py

## Critères de fin
- [ ] chaque ligne a url, date de lecture, prochaine revue ; une ligne de plus de 90 jours fait échouer le lint
- [ ] verdict DeepSeek par propriété : tarifs PASS, endpoint Anthropic PASS, appels d'outils PASS (docs, 2026-11-18) ; rétention API NOT_PROVEN jusqu'à lecture des conditions ; test runtime NOT_TESTED

## Notes
Les hôtes bloqués pour l'outil web restent lisibles par curl depuis le shell. MANDAT seulement si une clé ou une dépense est créée.

Proposé par la recherche `model-routing` (clé MOD-9) ; intégration 2 du 2026-11-18.
