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

## Amendement (arbitrage Fable, 2026-11-18)
Source : `docs/review/FABLE-REVIEW.md` (P1-P7, F1-F5), `docs/review/FABLE-ARBITRAGE.md`. Il remplace la liste des
prérequis du §2 et la conséquence « Paul approuve par lot ».
1. **Prérequis du pilote** (T-322) : T-008, T-302, T-303, T-306 (registre `docs/state/identities.yaml`), T-311, T-210,
   T-313, T-330, T-326 (ledger minimal et disjoncteur « limit »), T-304 (essai réel de l'exécutant : push d'un
   workflow, `check.py` sur runner, auto-merge, identité avec permission `workflows` en mode dev), T-305 (tag
   `core-baseline`). T-061 et T-061b sont `done` à la fusion de la PR #54, qui acte les ADR 0001-0023 et leurs amendements.
2. **Liste figée** : T-041 et T-070 en sortent (chevauchement) ; T-326 devient prérequis ; T-072, T-025 et T-074
   (AUTONOME, sans cluster) entrent. Si l'essai T-304 échoue sur les workflows, les tickets qui écrivent sous
   `.github/workflows/` sortent et sont remplacés avant l'heure 0.
3. **Mode dev** : REVUE = merge après `ci-ok` par l'auto-merge de l'exécutant (arbitrage 7). Le test à 6, 10, 15 sessions
   est retiré : les paliers restent décidés par Paul (§3).
4. **Concurrence** : matrice `max-parallel: 3` ou groupes de concurrence par couloir, jamais un groupe unique (T-311).
   Contrôle de chevauchement minimal dans T-210 ; `STATE.md` et `backlog/ROADMAP.md` ne sont écrits que par le coordinateur.
5. **Quota** : pendant les 24 h, le moteur horaire d'Atlas/homelab-infra est en **pause** et l'usage de Paul est noté ;
   plafonds Opus portés à 90 min et 150 tours (T-313) ; `noreply` et trailers imposés dès S0.
6. **FINAL0** : étape placée avant la première donnée réelle, identité réelle ou exposition publique (avant I1) :
   identité d'usine (T-215), noyau testé (T-007), retrait du contournement admin (T-400), rotation des secrets créés en dev
   (T-403), revue des code owners réactivée sur `platform/authz/`, `platform/policies/`, `security/` ; jalon T-404, dont
   dépendent T-022, T-026, T-028, T-051, T-164, T-171, T-181, T-185. FINAL garde T-121, T-401, T-402 et la rotation complète
   (T-405) ; T-401 exige la VM lab recréée depuis Git (secrets neufs, diff RBAC/CRD/webhooks vide) et relit le diff depuis
   `core-baseline`.
