---
id: T-140
title: "Registre des limites free tier (valeur, date, source) et lint de péremption"
status: todo
phase: P1
adr: [0017]
depends_on: [T-001, T-061]
class: AUTONOME
velocity: false
lane: coût
stage: S3
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
- [ ] (repris de T-141) mesure datée requests/usage/pods/IP et tableau composant -> cluster recommandé (critères de T-009)
- [ ] (repris de T-141) sortie JSON cost-evidence.v1 avec PASS/FAIL/NOT_TESTED/BLOCKED et date
- [ ] (repris de T-141) FAIL si un volume n'est lié à aucun PVC, si le total dépasse 200 Go ou si un LB/IP publique existe
- [ ] (repris de T-141) exécution périodique (cron CI en lecture ou job planifié) sans écriture cluster
- [ ] (repris de T-142) un test par refus, sur valeurs effectives après overrides
- [ ] (repris de T-142) erreur typée cost-free-tier avec la correction
- [ ] (repris de T-142) aucun contournement de VAP/PSA/NetworkPolicy (AGENTS.md)

## Notes
Les valeurs [E] de docs/research/COST-FREE-TIER.md servent de point de départ, pas de preuve.

Proposé par la recherche `cost` (clé T-140).
