---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Statistiques de l'usine : rapport sur les artefacts réels (T-479)

Date : 2026-11-18. Outil : `tools/factory/stats.py` (schéma de sortie `factory-stats.v1`). Source : artefacts
`mission-result-<n>` (schéma `mission-result.v1`) téléchargés par `gh api repos/platform-zephyr/openchoreo-lab/actions/artifacts/<id>/zip`
le 2026-11-18. Aucun artefact expiré ; tous lisibles. Dépôt public : aucune valeur sensible reprise. Les montants sont des
estimations côté client, pas la facture (NOT_PROVEN).

## Verdict

- Lecture des artefacts réels : PASS (7 artefacts lus, 0 fichier ignoré), niveau RUNTIME (sorties de l'usine réelle).
- Comparaison coût/tours avant et après T-466 / T-474 / T-478 : NOT_PROVEN. Échantillon de 7 runs, tickets différents,
  un seul run par ticket, et les artefacts ne portent pas `finished_at` (l'outil retombe sur la date du fichier, donc
  `--since` n'est pas fiable sur ces artefacts). Seule la tendance ci-dessous est observée, rien n'est conclu.

## Runs lus

| Run (Actions) | Artefact | Date de création | Issue | Statut | Échec | Tours | Durée s | Coût estimé USD |
|---|---|---|---|---|---|---|---|---|
| 44313706955 | mission-result-66 | 2026-11-18 13:39Z | 66 | PASS | aucun | 79 | 734 | 1.814 |
| 44313706955 | mission-result-67 | 2026-11-18 13:58Z | 67 | FAIL | aucun | 61 | 1888 | 1.649 |
| 44326043746 | mission-result-74 | 2026-11-18 14:41Z | 74 | FAIL | trailers_refused | 29 | 281 | 0.674 |
| 44331128791 | mission-result-74 | 2026-11-18 15:08Z | 74 | PASS | aucun | 27 | 275 | 0.659 |
| 44333609180 | mission-result-75 | 2026-11-18 15:24Z | 75 | PASS | aucun | 27 | 482 | 0.639 |
| 44338002716 | mission-result-86 | 2026-11-18 15:42Z | 86 | PASS | aucun | 28 | 183 | 0.512 |
| 44338002716 | mission-result-87 | 2026-11-18 15:41Z | 87 | PASS | aucun | 17 | 121 | 0.371 |

Tous les runs demandent et observent `claude-sonnet-5-5`, effort `high`.

## Agrégats (sortie de l'outil)

Les deux premiers runs (44313706955, 44326043746) : 3 runs, tours 61 / 79 (médiane / p90), coût 4.138 USD, PASS x1, FAIL x2,
refus `Bash:?` x5 et `Write` x2. Les quatre runs suivants (44331128791, 44333609180, 44338002716) : 4 runs, tours 27 / 28,
durée 229 / 482 s, coût 2.180 USD, PASS x4, refus `Bash:gh pr` x1.

## Observations (indices, non prouvés)

- Les runs de 13h39 à 14h41 UTC consomment 29 à 79 tours et 0.67 à 1.81 USD ; ceux de 15h08 à 15h42 UTC, 17 à 28 tours et
  0.37 à 0.66 USD. Le sens est cohérent avec l'effet attendu de T-466 / T-474 / T-478, mais les tickets diffèrent : NOT_PROVEN.
- Les 5 refus `Bash:?` des runs 66 et 67 sont des commandes dont l'argument n'est pas un simple mot minuscule (revue de
  sortie ci-dessous) ; le détail est perdu volontairement dans la sortie.
- Un seul échec nommé : `trailers_refused` (issue 74, rejoué avec succès au run 44331128791).

## Revue de sortie sans donnée sensible

Constat : `tools/factory/stats.py` ne reprend aucune chaîne libre. Le modèle et la cause d'échec passent par une liste
fermée (sinon « autre »). Le nom d'un refus passait par un motif large : un jeton collé après `Outil:` aurait pu sortir.
Correctif : la partie après `:` n'est reprise que si elle tient en un ou deux mots en minuscules et tirets (`git push`,
`gh pr`) ; sinon `Outil:?`. La branche, le chemin des fichiers sources, les sorties d'outil, les prompts et
l'environnement ne sortent jamais (tests : `test_no_sensitive_content_in_output`,
`test_denial_command_part_never_carries_arguments`, `test_output_has_only_closed_keys`). Limite assumée : un jeton en
minuscules de moins de 20 caractères sans séparateur resterait lisible ; la source (`permission_denials`) ne devrait pas en contenir.

## Reproduire

```
mkdir -p /tmp/art && gh api repos/platform-zephyr/openchoreo-lab/actions/runs/<id>/artifacts   # liste
gh api repos/platform-zephyr/openchoreo-lab/actions/artifacts/<artifact_id>/zip > a.zip         # un dossier vide par artefact
python3 tools/factory/stats.py --dir <dossier> [--json]
```

Les artefacts Actions expirent (rétention du dépôt) : rejouer tôt.
