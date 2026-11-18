---
id: T-322
title: "Calibrage du quota : pilote 24 h à N=3, paliers décidés par Paul, et décision Max/Ultra"
status: todo
phase: P0
adr: [0017, 0021]
depends_on: [T-008, T-302, T-303, T-304, T-305, T-306, T-311, T-313, T-326, T-330, T-413]
class: AUTONOME + MANDAT
velocity: true
lane: agents
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-322 — Calibrage du quota : pilote 24 h à N=3, paliers décidés par Paul, et décision Max/Ultra

## Intention
Mesurer le coût réel par ticket et par classe, le pourcentage de quota 5 h et hebdomadaire consommé, la concurrence cloud maximale, puis recalculer le calendrier et fixer N, le modèle par défaut et la décision de plan.

## Périmètre de fichiers
docs/research/AGENT-FACTORY-24-7.md (§6 recalculé), factory/config.yaml (concurrence)

## Critères de fin
- [ ] tableau mesuré : coût estimé, tours, durée par ticket sur ≥ 20 tickets ; % de quota relevé par Paul (/usage) à 0, 24, 48 h
- [ ] décision écrite : N, modèle par défaut, Max ou Ultra (seuil 70 % hebdomadaire au jour 3)
- [ ] (repris de MOD-8) ratios mesurés (quota par ticket) consignés ; proxy remplacé ou confirmé
- [ ] (repris de MOD-8) recommandation de plan chiffrée ; MANDAT : Paul ajuste le plan, la PR décrit le geste
- [ ] (repris de MOD-8) seuil de repli fixé : quota hebdomadaire > 70 % ⇒ Opus → Sonnet high hors noyau
- [ ] liste figée du pilote traitée à N=3 en dispatch manuel ; aucun ticket hors liste lancé pendant le pilote
- [ ] paliers N = 3 → 6 → 10 décidés par Paul sur les mesures (ADR-0021), consignés dans factory/config.yaml
- [ ] MANDAT Paul : moteur horaire d'Atlas/homelab-infra en pause pendant les 24 h (début et fin datés) ; usage de Paul hors pilote noté
- [ ] quota relevé toutes les 5 h ; un résultat « limit » arrête le lot sans relance (T-326)
- [ ] en mode dev, les tickets REVUE fusionnent après `ci-ok` par l'auto-merge de l'exécutant (arbitrage 7) ; aucun lot d'approbations de Paul

## Notes
MANDAT : Paul relève les pourcentages et décide du plan et du plafond de crédits d'usage. Remplace les hypothèses H1-H5 du §6.

Proposé par la recherche `factory` (clé FAC-13) ; intégration 2 du 2026-11-18.

C'est le pilote 24 h à N=3 (section « Lancement 24/7 » de ROADMAP.md), puis N=6, puis 8-10.

Liste figée du pilote (20) : T-002, T-214, T-332, T-050, T-325, T-337, T-365, T-338, T-216, T-345, T-331, T-340, T-217, T-341, T-321, T-314, T-317, T-072, T-025, T-074.

Liste refaite (arbitrage Fable, 2026-11-18) : T-041 et T-070 sortent (chevauchement, P7) ; T-326 devient prérequis (P6) ; T-072, T-025 et T-074 (AUTONOME, sans cluster) entrent.

T-413 ajouté aux prérequis (intégration 5, 2026-11-18) : T-214 (liste figée) en dépend. T-411 et T-414 (S0) sont recommandés avant l'heure 0 : décision de Paul (backlog/INTEGRATION-5.md).
