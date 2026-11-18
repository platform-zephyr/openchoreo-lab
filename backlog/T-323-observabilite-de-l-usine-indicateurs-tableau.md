---
id: T-323
title: "Observabilité de l'usine : indicateurs, rapport hebdomadaire par (type de tâche, modèle), écart banc/réel, drill de panne"
status: deferred
phase: P5
adr: [0019, 0021]
depends_on: [T-061, T-311, T-313, T-314, T-346]
class: AUTONOME
velocity: false
lane: observabilité
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-323 — Observabilité de l'usine : indicateurs, rapport hebdomadaire par (type de tâche, modèle), écart banc/réel, drill de panne

## Intention
Agréger tickets/jour, délai ticket→merge, succès à la 1re tentative, taux de revert, gestes humains/jour, % de quota, inactivité des slots ; sortie JSON + page statique ; drill : limite de quota, runner perdu, boucle.

## Périmètre de fichiers
tools/factory/metrics.py, docs/FACTORY-RUNBOOK.md, tools/metrics/model-routing/report.py, docs/metrics/agents-scorecard.md

## Critères de fin
- [ ] indicateurs calculés depuis les artefacts mission-result.v1 (test hors ligne)
- [ ] drill de limite de quota : lancements stoppés, reprise au reset, preuve datée
- [ ] (repris de MOD-6) rapport daté généré depuis les données réelles ; cellules n < 20 marquées NOT_PROVEN
- [ ] (repris de MOD-6) règle d'alerte : une règle dont le taux d'escalade dépasse 40 % sur n ≥ 20 ouvre une issue
- [ ] (repris de HAR-21) tableau hebdomadaire généré sans valeur secrète (exemple daté)
- [ ] (repris de HAR-21) écart banc/réel affiché par type de ticket

## Notes
Proposé par la recherche `factory` (clé FAC-14) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : règle d'usine d'ADR-0021 (décision 10) ; avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
