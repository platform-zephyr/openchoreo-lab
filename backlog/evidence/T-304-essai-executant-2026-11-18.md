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

Mesures du run : modèle observé claude-sonnet-5-5, environ 0,14 $ et 13 tours pour la tâche d'essai.
Aucune valeur secrète dans ce fichier.
