---
id: T-422
title: "Mesurer l'effet de l'art antérieur sur le pilote 24 h (avec/sans, banc T-346 ensuite)"
status: todo
phase: P1
adr: [0024]
depends_on: [T-412, T-322]
class: AUTONOME
velocity: false
lane: usine
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-422 — Mesurer l'effet de l'art antérieur sur le pilote 24 h (avec/sans, banc T-346 ensuite)

## Intention
Relever sur les tickets du pilote : section valide, CI verte au 1er push, itérations CI, échecs `appgen validate`/`kubeconform` dus à un champ, une CRD, une image ou un chart inexistants, citations invalides, tokens par ticket. Comparaison appariée par type de ticket dès que le banc existe.

## Périmètre de fichiers
docs/research/, tools/quality/

## Critères de fin
- [ ] tableau daté des 7 mesures du §A6 du rapport, avec le nombre de tickets (indicatif, pas statistique)
- [ ] décision recommandée : garder, alléger (niveau `léger` partout) ou retirer, avec la mesure qui la fonde

## Notes
Proposition QA-12 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Dire NOT_PROVEN si l'échantillon est trop petit. Le banc T-346 est différé après la porte.

Le banc T-346 est différé après la porte : comparaison avec/sans seulement indicative.
