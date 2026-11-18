# Revue hebdomadaire de maintenabilité (T-420, ADR-0024)

Une tâche planifiée en lecture seule. Elle mesure, elle propose, elle ne refactore pas. Procédure pas à pas : skill `quality-review`.

## Entrées (toutes existantes)
| Entrée | Commande | Rôle |
|---|---|---|
| Mesure du jour | `python3 tools/quality/check.py --output <fichier>` | `quality.v1` (cc_max, fonctions > 15, fichiers > 400 lignes, ruff, mypy) ; verdict du cliquet |
| Tendance | `docs/state/quality-history.jsonl` (4 dernières semaines) | une ligne par merge sur `main` (T-421) |
| Fichiers chauds | `git log --since=28.days --name-only --format= -- 'tools/*.py' 'tests/*.py'`, puis `sort`, `uniq -c`, `sort -rn`, `head -5` | les 5 fichiers les plus modifiés |
| Fonctions gelées touchées | clés de `tools/quality/baseline.json` (`functions`) dont le fichier est parmi les fichiers chauds | dette qui coûte réellement |
| Coût de l'usine | `python3 tools/factory/stats.py --dir <mission-results> --since <date>` | volume, tours et coût estimé des runs de la semaine |

## Sorties
1. Une issue de synthèse : tendance des indicateurs, 5 fichiers chauds, fonctions gelées touchées, verdict du cliquet. Aucune valeur secrète.
2. Au plus 3 propositions, au format `backlog/proposals/FORMAT.md` (le coordinateur attribue les `T-xxx`). Chacune porte : cible (fichier::fonction), mesure avant (commande et valeur), mesure attendue, test oracle (test existant qui reste vert, ou test de caractérisation à écrire d'abord).
3. Plus de 3 candidats : garder les 3 de meilleur rapport (fonction gelée touchée souvent, refactor peu coûteux) ; citer le reste en une ligne dans l'issue, sans proposition.

## Règle de budget (dette contre fonctionnalité)
- 1 ticket de dette pour 10 tickets de fonctionnalité terminés : le ticket de dette se prend quand le compteur atteint 10.
- Immédiat si le cliquet s'est tendu (une valeur de `baseline.json` a baissé, ou `check.py` a échoué sur `main`) : le ticket de dette passe devant.
- Un refactor n'est jamais mêlé à une fonctionnalité : une PR, un but. Le refactor garde le comportement (test oracle vert avant et après). La ligne de base se régénère dans une PR dédiée (`check.py --write-baseline`, noyau).
- La revue ne crée pas de ticket seule : elle propose, le coordinateur décide.

## Limites
- Aucun accès cluster, aucun secret, aucune écriture hors issue et proposition.
- Le trieur T-320 est différé : la revue se lance à la main tant qu'il n'existe pas.
- Les montants de `stats.py` sont des estimations (NOT_PROVEN), pas la facture.

## Coût en tokens (T-326)
Plafond d'une revue : 12 tours, aucune lecture hors des entrées ci-dessus. Le coût réel se lit dans le `mission-result.v1` du run (`tokens`, `total_cost_usd`) via `tools/factory/ledger.py`. Il n'est pas encore mesuré : NOT_TESTED, aucun run planifié avant le trieur. Le premier run l'écrit ici.

## Essai daté : 2026-11-18, commit 74fd1cc (STATIC, lecture locale)
Limites : `quality-history.jsonl` ne contient qu'une ligne (T-421 vient d'arriver), donc aucune tendance sur 4 semaines (NOT_PROVEN). Les fichiers chauds viennent de l'historique git (28 jours, 78 commits).
Verdict du cliquet : PASS (`check.py` : cc_max 65, 23 fonctions > 15, 4 fichiers > 400 lignes, ruff 224, mypy 12).
Fichiers chauds (modifications en 28 jours) : `tools/appgen/appgen.py` (5), `tools/oke/argo_guard.py` (4), `tools/backlog/check.py` (3), `tests/appgen/test_extensions.py` (3), `tests/appgen/test_appgen.py` (3).

Propositions (3 retenues) :
1. `tools/oke/argo_guard.py::check_projects`. Avant : cc 65 (`baseline.json`), fichier touché 4 fois. Attendu : cc ≤ 15 par fonction, une fonction par règle. Oracle : `tests/argo-guard` (existant) vert avant et après.
2. `tools/appgen/appgen.py::render_component`. Avant : cc 46, 136 lignes, fichier touché 5 fois. Attendu : cc ≤ 15, ≤ 80 lignes par fonction. Oracle : sorties `generated/` identiques octet pour octet, `tests/appgen` vert.
3. `tools/appgen/appgen.py::semantic_check` (cc 45, 102 lignes) et `_native_errors` (cc 41). Attendu : un contrôle par fonction, cc ≤ 15. Oracle : mêmes erreurs sur les cas de `tests/appgen` ; test de caractérisation ajouté d'abord.
Citée sans proposition : `tools/oke/psa_check.py::check` (cc 48, fichier touché 1 fois).
