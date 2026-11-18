# Consensus n°2 — coordinateur ↔ revue adverse (2026-11-18, soir)

Entrées : `docs/review/ADVERSARIAL-REVIEW-2.md`, intégration 2 (`backlog/INTEGRATION-2.md`), recherches du soir
(usine 24/7, harness, homelab, routage des modèles, vérification en ligne, audit de données sensibles). Deux tours
d'échange. **Proposition à Paul** : effectif quand Paul approuve la PR (ADR, `missions/` et CODEOWNERS sont noyau).

## Constat
Le plan avait regrossi (68 tickets avant la porte, ~30 qui construisent l'usine et pas le produit). Le pilote 24 h peut
partir avec 12 tickets. La VM lab avec CP et DP co-localisés vide les critères C2/C4 de leur sens multi-cluster. Deux
blocages manquaient (image corrigée arm64 vs lab x86_64 sans installateur ; runners arm64 gratuits perdus en privé).

## Décisions
| # | Sujet | Décision |
|---|---|---|
| 1 | Identité de l'usine | Retirer `bypass_actors` admin du ruleset. **Aucun lancement automatique avant T-215** ; aucun commit d'usine sous l'identité de Paul (vérifié par T-007). Config git `noreply` imposée par le harness. |
| 2 | S0 minimal (12) | T-300 → T-303 → T-302 → T-301 ; T-215 + ruleset ; T-061a ; T-008 ; T-007 ; T-313 minimal ; T-210 minimal ; T-311 minimal (`factory/PAUSE`, concurrence 3) ; T-330. Le reste de S0 (T-001, T-002, T-041, T-217, T-325, T-331, T-332, T-334, T-382, T-360-T-362) passe en S1 ou voie parallèle. |
| 3 | T-061 scindé | T-061a = ADR-0002, ADR-0021 réduit, MISSION/STATE alignés (prérequis du pilote). T-061b = autres ADR, amendements ADR-0003/0020, ADR-0022, ADR-0023. |
| 4 | Blocage lab | Nouveau **T-366 « bundle multi-arch + installateur lab »** (MANDAT : dépôt privé du bundle) ; T-364 dépend de T-366 et de T-001. |
| 5 | Porte (ADR-0020) | La porte évalue OpenChoreo **en mono-cluster** (écrit dans l'ADR). D11 : soit Paul tranche « CP sur lab » maintenant, soit C2 est mesuré tout de suite sur le CP déjà installé sur OKE. T-364 remplace T-030 dans la règle §4. L'horloge de 3 jours part de T-363 `done`. Si la VM lab n'est pas prête le 2026-11-25 : mesure des deux moteurs sur OKE. |
| 6 | Fenêtre privée | Une journée au plus : réécriture préparée par un agent, exécutée par Paul en une séance au J0, retour public avant le pilote ; pas de pilote ni de CI lourde en privé. T-301 : critère « amont prévenu de l'exposition » (forks, GH Archive, Software Heritage gardent la copie) ; ne pas attendre la confirmation du support GitHub. |
| 7 | Noyau | CODEOWNERS ajoute `/factory/`, les règles de routage, `docs/state/model-prices.yaml`, `docs/state/homelab-capacity.yaml`. Le dispatcher recalcule le modèle depuis les chemins et ignore un `model:` sous le plancher. |
| 8 | Routage (ADR-0023) | **Trois règles jusqu'aux données du pilote** : noyau (chemins CODEOWNERS, `docs/adr/`, `docs/review/`) → Opus `high` ; texte de tickets et docs hors noyau (sans toucher les en-têtes ni `backlog/proposals/`) → Haiku `medium` + revue Sonnet en check requis (2 refus → Sonnet) ; tout le reste → Sonnet `high`. Le dispatcher compare le diff réel au périmètre Haiku et relance en Sonnet sinon. Alias de modèles, escalade sur échec de capacité seulement. Différés après le pilote : T-382, T-386, T-388, T-390, T-392. |
| 9 | DeepSeek | **Interdit comme agent de code avant la porte.** Après : seulement règle « docs », `deepseek-flash` avec alias épinglés vérifiés en CI, runner sans secret ni jeton d'écriture (jeton GitHub dans une étape séparée), sortie réseau limitée à l'API DeepSeek, lecture de l'environnement et de `~/` refusée, dépôt public au lancement, pass^3 ≥ 0,8 sur un banc de vrais tickets docs, revue par Claude ; lint : `ANTHROPIC_BASE_URL` non Anthropic seulement dans ce job ; plafond de dépense = MANDAT. |
| 10 | Règle d'usine (ADR-0021) | Avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré. Différés : T-346, T-386, T-323, T-352, T-342, T-343, T-318, T-320. Liste figée de 20 tickets pour le pilote. Paliers N = 3 → 6 → 10 décidés par Paul. |
| 11 | Images | Garde « image multi-arch » (T-365) pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64). |
| 12 | Cohérence | STATE.md (homelab par défaut, chiffres du backlog) et MISSION.md corrigés dans T-061a. |

## Points restant à Paul
D11 (CP sur lab maintenant, ou mesure C2 sur OKE) ; date de la fenêtre privée et séance de réécriture ; prévenir l'amont ;
retrait du contournement admin ; Doppler (export du journal ou plan Team) ; Max ou Ultra ; mandat de dépense DeepSeek.

## Incertitudes
Gratuité des runners arm64 en privé ; image corrigée déjà multi-arch ou non ; durée réelle de la réécriture (PR ouvertes,
worktrees, kube-ops) ; gain de quota perdu avec un routage simplifié ; usage réellement mono-cluster de Paul.
