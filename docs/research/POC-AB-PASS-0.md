---
owner: paul
updated: 2026-11-19
review_days: 7
---
# Runbook : passe 0 non comptée du banc A/B (T-486)

Conclusion : le harnais de la passe 0 est prêt en statique (script de dispatch et son test). Aucun run n'a eu lieu. La passe 0 ne s'exécute qu'après les prérequis ci-dessous et ne compte pour aucun seuil.
Protocole : [POC-OPENCHOREO-STRATEGY.md](POC-OPENCHOREO-STRATEGY.md) §2 et §2.5. Seuils : `tests/bench-ab/thresholds.template.yaml`. Graders et verdict : `tools/bench-ab/`.

## Prérequis (tous BLOCKED tant que non faits)
- OKE recréé vierge ; un seul Argo (`lab-argocd`) ; bras K livré (T-212) ; check run publié depuis OKE (T-005) ; ApplicationSet par app sur `generated/` pour le bras O (T-491). Dépendances complètes : `backlog/T-486-passe-0-banc-oke.md`.
- Revue de fidélité du bras K par une session côté kube-ops, en lecture seule, datée, **avant** le premier run.
- Une issue par run, dans le dépôt du bras, avec pour texte la consigne de `tests/bench-ab/{tasks,traps}/<id>.<bras>.yaml` (texte identique pour K et O).

## Ordre des runs (11 runs, rang 0)
Un run à la fois par défaut ; au plus 3 en parallèle si l'empreinte le permet (mesure d'empreinte : voir plus bas). Pour chaque ligne, lancer `dispatch.sh`, exécuter la commande affichée, puis compléter le fichier de run.

| Ordre | Tâche | Bras | Attendu |
|---|---|---|---|
| 1-2 | M1 | K, O | `success` à la révision demandée, HTTP 200 |
| 3-4 | M2 | K, O | `success` + ligne lue par l'API de l'app |
| 5-6 | M3 | K, O | valeur vue en non-prod puis prod ; prod inchangée entre les deux ; état restauré ; aucune autre app touchée |
| 7-8 | M4 | K, O | cause juste (panne du tirage de rang 0 dans `draw.yaml`) + `success` après la PR de correctif |
| 9-11 | P1, P2, P3 | O seulement | piège contenu (CI, admission, AppProject ou refus de l'agent), jamais arrivé au cluster |

Commande, par run :

```bash
tests/bench-ab/pass-0/dispatch.sh <M1..M4|P1..P3> <K|O> --issue <numéro de l'issue>
```

Le script affiche la commande `gh workflow run claude-agent.yml ...` (entrées du workflow : `tickets`, `model`, `effort`). Modèle et effort : `claude-sonnet-5-5`, `high`, identiques aux deux bras. Il écrit `tests/bench-ab/pass-0/runs/<tâche>.<bras>.r0.json` (`bench-run.v1`, rang 0, `counted: false`, `expected_status`, empreinte de la consigne, panne de M4). Il ne lance rien et ne contient aucun secret. Un piège avec le bras K est refusé : la passe 0 ne joue les pièges qu'avec le bras O. Après le run, renseigner `actual_status`, `evidence_level`, `check_run` et `observations` (champs lus par `tools/bench-ab/graders.py`). Le rang 0 est ignoré par `verdict.py` : le rapport de la passe 0 se fait donc grader par grader, pas avec `verdict.py report`.

## Ce qu'on corrige librement pendant la passe 0
- Le harnais : `tests/bench-ab/pass-0/`, `tools/bench-ab/`, les fixtures.
- Les graders et leurs observations (`graders.py`).
- La plateforme et les deux bras : bootstrap, ApplicationSet, notifications, dépôt K (en restant fidèle à kube-ops, revue de fidélité à refaire si l'écart est de fond).
- Les consignes : **non** (texte préenregistré, identique K et O ; une correction exige l'accord de Paul et rouvre T-485).
- Les seuils : **non** (aucune valeur ne change avant le gel ; seul Paul peut en ajuster une, jamais après le commit de `thresholds.yaml`).
- Les règles de sûreté (PSA, admission, AppProject, NetworkPolicy) : **non**, jamais assouplies pour faire passer un test.

## Critère de sortie
Chaque grader rend le verdict attendu au moins une fois sur un run réel de la passe 0 : `m1`, `m2`, `m3`, `m4` (PASS sur la tâche réussie) et `trap` (PASS = piège contenu). Chaque verdict réel est daté, avec son niveau de preuve (`RUNTIME` OKE). Les cas FAIL et NOT_TESTED des graders sont couverts hors ligne par `tests/bench-ab/test_bench_ab.py` et ses fixtures de check run. Un grader qui ne rend pas le verdict attendu est corrigé, puis le run concerné est rejoué (`--force`) ; sinon la passe reste ouverte.

Mesures à joindre au rapport (critères de T-486) : une app A du bras K et une app A du bras O avec check run `success` publié depuis OKE ; empreinte (requests, pods) avec un bras actif puis avec les deux, et la règle « un bras actif à la fois » décidée.

## Règle d'adoption anticipée (Q26, ADR-0025 point 8)
Décision de Paul du 2026-11-19, relayée par le coordinateur (T-508). À l'issue de la passe 0, OpenChoreo est adopté
(porte 1 = « valeur prouvée »), sans campagne comptée, si les trois conditions sont réunies :
1. les 3 pièges (P1, P2, P3) sont contenus par le bras O ;
2. le bras O réussit M1, M2, M3 et M4 ;
3. le bras K échoue au moins une tâche pour une raison **structurelle** (cas attendu : M3), documentée dans le rapport.

Sinon : gel des SHA et des seuils, puis campagne comptée (T-488), sans changement. La porte 2 reste exigée dans les
deux cas. Le rapport de la passe 0 donne, par condition, la preuve RUNTIME OKE datée ; une condition `NOT_TESTED` n'est
pas réunie. Raison structurelle = capacité absente du modèle du bras, pas une erreur ponctuelle de l'agent ni un défaut
du harnais (un défaut du harnais se corrige, puis le run est rejoué).

## Règle sur M3 côté bras K (E6, ADR-0025 point 9)
Si le chemin kube-ops reproduit n'a pas d'environnement hors production, le run M3 du bras K est consigné **tel quel** :
mesure défavorable au bras K, avec la raison dans `observations`. On n'invente pas de non-prod pour le bras K et on ne
développe rien sur kube-ops. Ce cas peut remplir la condition 3 de la règle d'adoption anticipée.

## Gel des SHA et seuils
À faire une fois le critère de sortie atteint, si la règle d'adoption anticipée ne s'applique pas, et **avant le premier
run compté**.

1. Relever les SHA (ne pas les saisir de mémoire) :
   - O, `openchoreo-lab` : `git rev-parse origin/main` après `git fetch origin main` ;
   - K, `platform-zephyr/bench-ab-arm-k` : `git ls-remote https://github.com/platform-zephyr/bench-ab-arm-k refs/heads/main`.
2. Créer les seuils à partir du gabarit, sans modifier une valeur :
   ```bash
   cp tests/bench-ab/thresholds.template.yaml tests/bench-ab/thresholds.yaml
   python3 tools/bench-ab/verdict.py validate --thresholds tests/bench-ab/thresholds.yaml
   ```
3. Un seul commit contient `thresholds.yaml`, et son message donne les deux SHA gelés (le schéma des seuils refuse tout champ en plus). Son horodatage Git fait foi. Le rapport de la passe 0 cite le même commit et les mêmes SHA.
4. Après ce commit : aucune correction de plateforme ni de dépôt (§2.5 point 4). Une dérive d'un SHA invalide la campagne.

`thresholds.yaml` n'existe pas encore : ce runbook ne le crée pas.

## Statuts
- Statique, ce ticket : script et test (`tests/bench-ab/pass-0/dispatch-test.sh`) = `PASS` niveau `STATIC`.
- Tous les runs, les check runs OKE, l'empreinte, la revue de fidélité et le gel : `NOT_TESTED`.
- Écart à lever par Paul ou T-485 : la stratégie §2.3 cite `echo-bench` (M1, M4) et `miniflux` (M2), alors que `tests/bench-ab/tasks/` cite `it-tools` (M1, M4) et `vikunja` (M2). Le script lit l'application dans les consignes ; la consigne de `tests/bench-ab/tasks/` fait foi pour le grader jusqu'à correction.
