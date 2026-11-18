# T-304 — essai réel de l'exécutant (2026-11-18)

Niveau : RUNTIME (run GitHub Actions réel, issue de test #57, PR #63).

| Critère | Résultat | Preuve |
|---|---|---|
| Identité avec la permission workflows | PASS | GitHub App de l'exécutant (nom dans docs/state/identities.yaml), installation sur ce dépôt seulement ; jeton d'installation généré à chaque run |
| PR de l'exécutant modifiant un fichier sous .github/workflows/, poussée sans refus | PASS | PR #63 ouverte par le bot ; trois essais précédents refusés (jeton sans workflows, puis GITHUB_TOKEN de checkout prioritaire) |
| check.py sur un runner hébergé : tickets lus > 0, 0 erreur | PASS | 233 fichiers, 134 tickets actifs, exit 0 (dans la PR) |
| Auto-merge armé, fusion seule après ci-ok | PASS | auto-merge activé par le bot, entrée en file de fusion, CI de la file verte, PR #63 fusionnée (commit 1a05f87) |

Causes corrigées pendant l'essai :
- jeton personnel sans propriétaire d'organisation → GitHub App dédiée ;
- git push réutilisait le GITHUB_TOKEN persisté par actions/checkout (refusé pour les workflows) → persist-credentials: false (issue amont anthropics/claude-code-action#1510).

Mesures par run (artefacts `mission-result-57` des runs de l'issue #57, relus par `gh api` en lecture seule le 2026-11-18 ; modèle observé `claude-sonnet-5-5` partout) :

| Run | Tours | Coût (USD) | Durée (s) | Statut du compte rendu |
|---|---|---|---|---|
| 44293640307 | 26 | 0,3481 | 82 | PASS |
| 44294793839 | 14 | 0,1789 | 43 | PASS |
| 44295963844 | 17 | 0,2066 | 44 | PASS |
| 44296400227 | 14 | 0,1696 | 42 | PASS |
| 44299104705 | 13 | 0,1425 | 43 | PASS |
| 44299930797 | 11 | 0,1156 | 40 | PASS |
| 44303340671 | 8 | 0,1363 | 35 | NOT_TESTED (no_branch) |
| 44305477356 | 8 | 0,0974 | 29 | NOT_TESTED (no_branch) |
| 44306512412 | 12 | 0,1651 | 39 | NOT_TESTED (no_branch) |
| 44307563892 | 10 | 0,1652 | 35 | NOT_TESTED (no_branch) |

La mention antérieure « environ 0,14 $ et 13 tours » est celle du run 44299104705. Le run 44307563892, qui a produit la PR #63 (branche `agent/issue-57-…`), compte 10 tours et 0,1652 $. Les quatre derniers runs n'ont pas de branche dans la sortie de l'action (la PR est ouverte par l'agent lui-même) : le champ `branch` est vide et le statut `NOT_TESTED`.
Aucune valeur secrète dans ce fichier.
