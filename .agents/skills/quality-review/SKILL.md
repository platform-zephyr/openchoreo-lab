---
name: quality-review
description: Revue hebdomadaire de maintenabilité en lecture seule (T-420, ADR-0024). À charger pour « fais la revue de maintenabilité », « quelle dette refactorer ». Lit quality.v1, les fichiers chauds et les fonctions gelées ; rend une issue de synthèse et au plus 3 propositions de refactor. Ne refactore jamais.
---

# quality-review

Procédure et règle de budget : `factory/quality-review.md` (source unique). Lecture seule : aucun accès cluster, aucun secret.

1. Mesurer : `python3 tools/quality/check.py --output <fichier>` (verdict, valeurs du jour).
2. Tendance : `docs/state/quality-history.jsonl`, 4 dernières semaines. Moins de 4 semaines : le dire (NOT_PROVEN).
3. Fichiers chauds : les 5 fichiers `.py` les plus modifiés en 28 jours (commande dans `factory/quality-review.md`).
4. Fonctions gelées touchées : clés de `tools/quality/baseline.json` dans ces fichiers, triées par complexité.
5. Facultatif : `python3 tools/factory/stats.py --dir <dossier>` pour le coût de la semaine.
6. Écrire l'issue de synthèse et au plus 3 propositions (`backlog/proposals/FORMAT.md`) : cible, mesure avant (commande et valeur), mesure attendue, test oracle. Au-delà de 3, garder les 3 de meilleur rapport et citer le reste en une ligne.
7. Appliquer la règle de budget : 1 ticket de dette pour 10 de fonctionnalité, immédiat si le cliquet s'est tendu ; jamais de refactor mêlé à une fonctionnalité.

Interdits : modifier du code, la ligne de base, `tools/dev/check` ou `ci.yaml` ; créer un ticket (le coordinateur le fait) ; reprendre une valeur secrète dans l'issue.
