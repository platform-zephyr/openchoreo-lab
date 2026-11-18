---
id: T-140
title: "Registre des limites free tier (valeur, date, source) et lint de péremption"
status: todo
phase: P0
adr: [0017]
depends_on: [T-001]
class: AUTONOME
velocity: false
lane: coût
github_issue: null
---
# T-140 — Registre des limites free tier (valeur, date, source) et lint de péremption

## Intention
Une seule table machine-lisible des limites gratuites (OCI, Cloudflare, Grafana, GitHub, Doppler, ntfy, Cloud Run), reconfirmées sur les pages officielles (web bloqué lors de la recherche du 2026-11-18).

## Périmètre de fichiers
docs/state/free-tier.yaml, tools/cost/lint_free_tier.py, tests/cost/

## Critères de fin
- [ ] chaque ligne a valeur, unité, URL source, date de vérification, prochaine revue
- [ ] le lint échoue si une ligne n'a pas été revérifiée depuis 90 jours
- [ ] la discordance A1 2/12 (dépôt) vs 4/24 (connaissance) est tranchée avec source datée

## Notes
Les valeurs [E] de docs/research/COST-FREE-TIER.md servent de point de départ, pas de preuve.

Proposé par la recherche `cost` (clé T-140).
