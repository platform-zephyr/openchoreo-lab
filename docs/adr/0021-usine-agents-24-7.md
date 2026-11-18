# ADR-0021 — Usine d'agents 24/7 (version réduite)
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0012, ADR-0017, ADR-0020, ADR-0022, ADR-0023 ; D-2026-11-15-03 (homelab-infra) ;
`docs/review/CONSENSUS-2.md` (décisions 2, 10 et arbitrages de Paul)

## Contexte
- Objectif de Paul : finir vite, en heures réelles, avec peu de gestes humains.
- Le goulot est le quota d'abonnement (fenêtre de 5 h et plafond hebdomadaire partagés par tous les chemins de calcul),
  puis la latence humaine (gestes MANDAT, approbations du noyau) (`docs/research/AGENT-FACTORY-24-7.md` §0, §3).
- La revue adverse n°2 a montré que le plan avait regrossi : une trentaine de tickets construisaient l'usine et pas le
  produit. Le pilote 24 h peut partir avec un S0 minimal.
- Version réduite : ce texte ne fixe que les règles du pilote et de l'usine avant la porte. Le reste de la proposition
  (mandats de lot, App de merge, travailleur homelab, trieur) attend les mesures du pilote.

## Décision
1. **Règle d'usine** : avant la porte (ADR-0020), un ticket qui construit l'usine n'entre que s'il supprime un geste de Paul
   mesuré pendant le pilote. Les autres sont `deferred` (T-318, T-320, T-323, T-342, T-343, T-346, T-352, T-386 et leurs
   dépendants).
2. **Pilote 24 h à N=3** (T-322), en dispatch manuel par Paul (`workflow_dispatch`), sur une **liste figée de 20 tickets**
   écrite à l'avance dans T-322 ; aucun autre lancement pendant le pilote. Prérequis : S0 minimal (T-303, T-302, T-061,
   T-008, T-210, T-311, T-313, T-330). Le pilote ne dépend ni de l'identité d'usine ni du ruleset (étape FINAL, ADR-0002
   amendé), ni de la réécriture de l'historique (T-301, geste de Paul hors chemin critique).
3. **Paliers N = 3 → 6 → 10**, décidés par Paul sur les mesures du pilote (coût par ticket, % de quota 5 h et
   hebdomadaire, concurrence cloud) et consignés dans `factory/config.yaml` (noyau). Aucun passage de palier automatique.
4. **Kill-switch** : la présence de `factory/PAUSE` (noyau) arrête tout lancement et tout merge automatique (T-311).
5. Le dispatcher est du **code déterministe** (`tools/backlog/next.py`), pas un LLM ; il recalcule classe et modèle depuis les
   chemins (ADR-0023). Le coordinateur décide, il ne dispatche pas.
6. Pendant le développement, les sessions agissent avec l'identité de Paul (ADR-0002 amendé) ; l'App de merge et l'identité
   d'usine arrivent en FINAL (T-215).

## Conséquences
- `factory/` entre dans CODEOWNERS (décision 7). Le ledger de quota se construit pendant le pilote (T-326).
- Sur 20 tickets prêts sans cluster réel, 11 touchent le noyau : Paul approuve par lot pendant le pilote.
- Le calendrier (`AGENT-FACTORY-24-7.md` §6) se recalcule après le pilote.

## Alternatives écartées
- Lancer l'usine complète d'emblée (dispatcher planifié, merge armé, travailleur homelab) : le plan regrossit, la porte recule.
- Dispatcher LLM : coût de quota et non-déterminisme.
- Attendre T-215 et le ruleset avant le pilote : retard sans gain pendant le développement (arbitrage 4).
- Plus de 10 agents : le graphe et le quota limitent avant les slots.

## Vérification
- T-322 : tableau mesuré sur les 20 tickets, % de quota relevé par Paul à 0, 24 et 48 h, décision de palier écrite.
- Test : `factory/PAUSE` présent = aucun lancement (T-311).
- `tools/backlog/check.py` : aucun ticket actif ne dépend d'un ticket différé ; la liste figée est lue par `roadmap.py`.

## Références
`docs/research/AGENT-FACTORY-24-7.md` §5-§9, `docs/review/ADVERSARIAL-REVIEW-2.md` §1, `docs/review/CONSENSUS-2.md`,
`backlog/INTEGRATION-3.md`.
