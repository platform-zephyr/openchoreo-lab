# Intégration 4 du backlog : arbitrage de la revue Fable (2026-11-18, nuit)

Conclusion : le pilote 24 h a désormais **11 prérequis exacts** (dont l'essai réel de l'exécutant, le ledger minimal et le
tag `core-baseline`) ; une étape **FINAL0** précède la première donnée réelle ; la porte mesure **C1-C7** et son repli est un
report. Backlog : **128 `todo`, 46 gelés, 27 abandonnés** ; `check.py` : 0 erreur, profondeur 11. Source : patch
« Arbitrage Fable » de `tools/backlog/seed.py`. Statut : PROPOSITION (STATIC), effective à la fusion de la PR #54.

## Ce qui a changé
| Constat | Changement |
|---|---|
| P1 | **T-304** (S0) essai réel de l'exécutant : push d'un workflow, `check.py` sur runner, auto-merge, identité `workflows` en mode dev (MANDAT). |
| P3 | T-061 et T-061b : `todo`, « done à la fusion de la PR #54 » ; retirés des dépendances du pilote et de ses prérequis. |
| P4 | Mode dev : REVUE = merge après `ci-ok` (`backlog/README.md`) ; test à 6/10/15 sessions retiré de T-322. |
| P5 | T-311 : concurrence par `max-parallel: 3` ou groupes par couloir ; test 5 dispatchs → 5 runs terminés. |
| P6 | T-326 (ledger minimal, disjoncteur « limit ») passe en S0, prérequis ; T-313 : Opus 90 min / 150 tours ; T-322 : pause du moteur Atlas/homelab-infra (MANDAT). |
| P7 | T-210 : contrôle de chevauchement minimal ; `STATE.md`, `ROADMAP.md` au coordinateur seul ; T-041 et T-070 hors liste. |
| F1 | Étape **FINAL0** (entre PORTE et I1) : T-215, T-007, T-400 (+ revue des code owners sur `platform/authz/`, `platform/policies/`, `security/`), **T-403** rotation des secrets de dev, jalon **T-404**. T-404 bloque T-022, T-026, T-028, T-051, T-164, T-171, T-181, T-185. |
| F2, F5 | T-313 : `noreply` et trailers imposés dès S0 ; **T-305** (S0) tag `core-baseline`, relu par T-401. |
| F3 | **T-306** (S0) registre `docs/state/identities.yaml` (noms, rôles, dates, jamais de valeur) ; **T-405** (FINAL) rotation complète. |
| F4 | T-401 : VM lab recréée depuis Git, secrets neufs, diff RBAC/CRD/webhooks vide ; T-363 : VAP et Kyverno en `enforce` avant la première app ; T-362 jamais allégé. |
| G1-G4 | T-211 : C2 différentiel (≤ 4 Gio, ≤ 25 pods), C4 jour 2, C5 (30 %), C6, C7 (T-050), horloge par voie, ordre croisé, T-044 pour les deux moteurs, repli = report au 2026-12-11 ; T-140 retiré, T-050 ajouté. T-006 limité au statut publié dans GitHub, lu par l'API GitHub (AUTONOME). |
| ADR | ADR-0020 et ADR-0021 : paragraphes « Amendement (arbitrage Fable, 2026-11-18) ». `check.py` et `roadmap.py` : FINAL0 dans l'ordre des étapes. |

## Pilote (T-322)
Prérequis exacts (11) : T-008, T-303, T-306, T-311, T-330 → T-210, T-302 → T-313 → T-304, T-326 → T-305.

Liste figée (20) : T-002, T-214, T-332, T-050, T-325, T-337, T-365, T-338, T-216, T-345, T-331, T-340, T-217, T-341, T-321,
T-314, T-317, T-072, T-025, T-074.
- Entrées : T-072, T-025, T-074 (AUTONOME, sans cluster). Il n'existait qu'un ticket AUTONOME prêt (T-025) : la dépendance
  T-001 de T-072 et T-074 est retirée (aucun fichier commun avec la PR #8). T-025 et T-074 sont sérialisés après T-214,
  T-072, T-365 (fichiers communs) ; T-025 reste derrière T-002 (REVUE, merge après `ci-ok` en mode dev).
- Si T-304 échoue sur les workflows : T-002, T-216, T-321 et T-314 sortent et sont remplacés avant l'heure 0.

## Ordre de lancement
1. Fusion de la PR #54 : T-061 et T-061b `done`.
2. S0 par vagues : (T-008, T-303, T-306, T-311, T-330) → (T-210, T-302) → T-313 → (T-304 avec le geste de Paul, T-326) → T-305 (tag par Paul).
3. Paul met en pause le moteur horaire d'Atlas/homelab-infra, relève le quota : heure 0 de T-322, N=3.
4. Racines du pilote d'abord : T-002, T-214, T-332, T-050, T-325, T-314, T-072 ; puis les chaînes internes.
5. Après les 24 h : décision de palier par Paul, cron T-314, puis T-315, T-316, T-006.

## Chiffres
- `todo` par étape : S0 14, S1 32, S2 4, S3 11, PORTE 1, FINAL0 5, I1 7, I1bis 1, I2 12, I3 4, I4 8, I5 7, I6 6, I7 9, I8 3, FINAL 4.
- Modèles des `todo` : Sonnet 100, Opus 26, Haiku 1, humain 1. Chemin jusqu'à la porte : 9 vagues (inchangé).
