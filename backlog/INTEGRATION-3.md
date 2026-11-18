# Intégration 3 du backlog : consensus n°2 et arbitrages de Paul (2026-11-18)

Conclusion : le pilote 24 h ne dépend plus que d'un **S0 minimal de 8 tickets** ; l'identité d'usine et le ruleset passent dans
une étape **FINAL** ; le CP OpenChoreo est sur le homelab (D11). Backlog : **122 `todo`, 46 gelés (42 `deferred`, 4 `blocked`),
27 abandonnés** ; `check.py` : 0 erreur, profondeur 11. Source : patch « Consensus n°2 + arbitrages de Paul » de
`tools/backlog/seed.py`. Statut : PROPOSITION (STATIC) ; ADR, CODEOWNERS et `tools/backlog/` sont noyau, Paul approuve.

## Ce qui a changé
| Sujet | Changement |
|---|---|
| Données sensibles (arb. 1) | T-300 `dropped` (pas de fenêtre privée ni de purge) ; T-303 en S0 ; T-301 = geste de Paul (`model: human`), aucun ticket n'en dépend. |
| Sécurité de dev (arb. 4) | Étape **FINAL** (après I8) : T-215, T-007, T-121 (Renovate exige l'App), **T-400** retrait du `bypass_actors` admin, **T-401** revue de sécurité finale, **T-402** garde d'image multi-arch. Dépendances vers T-215/T-007 retirées des tickets actifs (note dans chacun). |
| S0 minimal (déc. 2) | S0 = T-303, T-302, T-061, T-061b, T-008, T-210, T-311, T-313, T-330 (+ T-301 hors chemin). Le reste de l'ancien S0 passe en S1. |
| Versions minimales | T-311 = PAUSE + concurrence 3 ; ledger et disjoncteur → **T-326** (S1, construit pendant le pilote). T-210 = `next.py` seul ; admission → T-314. T-313 = dispatch + mission-result.v1 ; outils étroits → T-401. |
| T-061 scindé (déc. 3) | T-061 (a) : ADR-0002, ADR-0021 réduit, MISSION, STATE. **T-061b** : autres ADR, ADR-0022, ADR-0023, amendements ; en S0, en parallèle ; dépendance de tous les tickets actifs hors S0 et hors pilote. |
| Lab (déc. 4, arb. 2-3) | **T-366** bundle multi-arch + installateur lab (REVUE + MANDAT) ; T-364 dépend de T-366 et T-001. D11 tranché : CP définitif sur la VM lab (T-364, T-211) ; T-030 reste gelé (DP OKE seulement si Paul le demande). Note dans T-361/T-360 : services kube-ops désactivables. |
| Porte (déc. 5) | T-211 : mono-cluster, horloge à T-363 `done`, repli sur OKE le 2026-11-25. |
| Accès agents cloud (arb. 2) | **T-006 dégelé** (S1, lecture seule) : MCP/API derrière Tunnel + Access déjà côté kube-ops, ou statut publié dans GitHub. |
| Runners (arb. 6) | T-343 : hébergés par défaut ; ARC homelab seulement pour push/dispatch de mainteneurs, jamais PR de fork (gelé par la déc. 10). |
| Règle d'usine (déc. 10) | `deferred` : T-318, T-320, T-323, T-342, T-343, T-346, T-352, T-386 ; en cascade T-319, T-347, T-348, T-349. |
| Routage (déc. 8) | 3 règles recalculées pour chaque ticket : R1 noyau → opus/high, R2 texte → haiku/medium + revue Sonnet, R3 → sonnet/high ; T-301 → `R0-geste-humain`. `deferred` : T-382, T-388, T-392 (T-386, T-390 ci-dessus/ci-dessous). |
| DeepSeek (arb. 5) | T-350, T-389, T-390 `deferred` « après le chantier » ; T-388 noté. |
| CODEOWNERS (déc. 7) | `/factory/`, `/backlog/proposals/model-routing.yaml`, `/backlog/routing.yaml`, `/docs/state/model-prices.yaml`, `/docs/state/homelab-capacity.yaml`. |
| ADR | Amendés : 0002 (sécurité de dev, FINAL), 0003 (CP sur le homelab, OKE optionnel), 0020 (mono-cluster, horloge, repli). Créés : 0021, 0022, 0023. 0014/0018 ne citent pas DeepSeek : inchangés. |

## Pilote 24 h (T-322) : prérequis et liste figée
Prérequis exacts (S0 minimal, 3 vagues) : T-008, T-061, T-303 → T-210, T-302, T-311, T-330 → T-313.
Ni T-215, ni le ruleset, ni T-301, ni T-061b. N = 3, dispatch manuel par Paul ; paliers 6 puis 10 décidés par Paul.

Liste figée (20, sans cluster réel ; k3d jetable en CI admis) :
T-002, T-214, T-332, T-041, T-050, T-325, T-326, T-337, T-365, T-338, T-070, T-216, T-345, T-331, T-340, T-217, T-341, T-321, T-314, T-317.
- 9 AUTONOME, 11 REVUE (noyau : Paul approuve par lot). Il n'existe pas 20 tickets AUTONOME prêts sans cluster.
- Chaînes internes : T-332 → T-337 → T-340/T-341 ; T-002 → T-338/T-070/T-216/T-217/T-321 ; T-214 → T-365 ; T-314 → T-317.
- T-314 est construit pendant le pilote ; son cron ne s'active qu'après la décision de T-322.

## Chiffres
- `todo` par étape : S0 10, S1 33, S2 4, S3 11, PORTE 1, I1 7, I1bis 1, I2 12, I3 4, I4 8, I5 7, I6 6, I7 9, I8 3, FINAL 6.
  Avant la porte : 58 (contre 68 avant ce patch).
- Modèles des `todo` : Opus 67, Sonnet 53, Haiku 1, humain 1. Le noyau est large (`.github/`, `tools/backlog/`, `.agents/`,
  `platform/policies/`, `factory/`…), d'où la majorité Opus.
- Chemin jusqu'à la porte (9 vagues) : T-061 → T-361 → T-362 → T-363 → T-364 → T-005 → T-015 → T-044 → T-211.
  T-360, T-061b, T-001 → T-366 courent en parallèle et rejoignent T-361 ou T-364.

## Questions restantes à Paul
1. Pilote : accepter 11 tickets REVUE dans la liste figée (approbations par lot pendant les 24 h), ou réduire la liste ?
2. Routage : 67 tickets en Opus. Garder le noyau CODEOWNERS complet comme critère R1, ou restreindre R1 (par ex. hors `tests/` de garde) ?
3. T-301 : prévenir l'amont de l'exposition passée (forks et archives publiques gardent la copie) ? Date de la réécriture ?
4. VM lab : racine OpenTofu `proxmox` ou `proxmox-lab` (T-361) ; quels services de kube-ops désactiver (après T-360) ?
5. Date de la séance S0 : approbation de T-061, T-061b et des 7 PR REVUE du S0 ; gestes homelab T-360 → T-362.
6. Bundle (T-366, T-001) : publication multi-arch dans le dépôt privé et accès en lecture au package.
7. Plan Max ou Ultra et plafond de crédits d'usage (T-322) ; Doppler : export du journal ou plan Team (T-181).
8. Identifiant `T-061b` : hors du format `T-NNN` (demandé explicitement) ; `check.py` l'accepte. Garder ou renuméroter ?
