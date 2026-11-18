---
id: T-322
title: "Calibrage du quota : pilote 24 h à N=3, puis 6, puis 8-10, et décision Max/Ultra"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-061, T-301, T-311, T-313]
class: AUTONOME + MANDAT
velocity: true
lane: agents
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-322 — Calibrage du quota : pilote 24 h à N=3, puis 6, puis 8-10, et décision Max/Ultra

## Intention
Mesurer le coût réel par ticket et par classe, le pourcentage de quota 5 h et hebdomadaire consommé, la concurrence cloud maximale, puis recalculer le calendrier et fixer N, le modèle par défaut et la décision de plan.

## Périmètre de fichiers
docs/research/AGENT-FACTORY-24-7.md (§6 recalculé), factory/config.yaml (concurrence)

## Critères de fin
- [ ] tableau mesuré : coût estimé, tours, durée par ticket sur ≥ 20 tickets ; % de quota relevé par Paul (/usage) à 0, 24, 48 h
- [ ] test de concurrence cloud : 6, 10, 15 sessions ; seuil observé ou NOT_PROVEN consigné
- [ ] décision écrite : N, modèle par défaut, Max ou Ultra (seuil 70 % hebdomadaire au jour 3)
- [ ] (repris de MOD-8) ratios mesurés (quota par ticket) consignés ; proxy remplacé ou confirmé
- [ ] (repris de MOD-8) recommandation de plan chiffrée ; MANDAT : Paul ajuste le plan, la PR décrit le geste
- [ ] (repris de MOD-8) seuil de repli fixé : quota hebdomadaire > 70 % ⇒ Opus → Sonnet high hors noyau

## Notes
MANDAT : Paul relève les pourcentages et décide du plan et du plafond de crédits d'usage. Remplace les hypothèses H1-H5 du §6.

Proposé par la recherche `factory` (clé FAC-13) ; intégration 2 du 2026-11-18.

C'est le pilote 24 h à N=3 (section « Lancement 24/7 » de ROADMAP.md), puis N=6, puis 8-10. Ne démarre qu'après la réécriture de l'historique (T-301).
