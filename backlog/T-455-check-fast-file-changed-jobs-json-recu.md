---
id: T-455
title: "check --fast, --file, --changed, --jobs, --json et reçu (SL-3)"
status: done
phase: P0
adr: [0022]
depends_on: [T-453]
class: AUTONOME
velocity: true
lane: dev-factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-455 — check --fast, --file, --changed, --jobs, --json et reçu (SL-3)

## Intention
Donner à `tools/dev/check` les niveaux rapides de l'échelle de `docs/research/SHIFT-LEFT-DEV-ENV.md` (§2-§5, ligne SL-3) : `--file <chemin>` (L0, moins de 2 s), `--fast` (L1, moins de 10 s), `--changed` (restreint `--static` aux contrôles touchés par `git diff`, selon `tools/dev/check-paths.tsv`), `--jobs N` (étapes indépendantes en parallèle), `--json` et un reçu daté (SHA, niveau, résultats, date) écrit hors de l'arbre suivi. Corriger l'étape `gitleaks` (elle scannait l'historique avec les règles du dépôt : 208 FAIL, alors que le job `secrets` de la CI utilise les règles par défaut) et éviter le doublon `coverage` / `appgen-unittest`.

## Périmètre de fichiers
tools/dev/check, tools/dev/check-paths.tsv, tests/dev-factory/

## Critères de fin
- [x] `--file <chemin>` lint le fichier selon son type (ruff, shellcheck, yamllint, JSON) en moins de 2 s ; FAIL = rc 2 — `check --file` du 2026-11-18 : py 0,0 s, shell 0,5 s, trois fichiers (shell, py, app.yaml) 1,0 s ; `check-test.sh` section 4a (py, shell avec et sans extension, yaml, json, FAIL rc 2, stdout vide sur FAIL, outil absent NOT_TESTED, ruff d'une autre version NOT_TESTED)
- [x] `--fast` (ruff, yamllint, shellcheck des fichiers changés, backlog) en moins de 10 s ; fichiers indexés sinon modifiés depuis `merge-base origin/main` — `check --fast` du 2026-11-18 : 1,4 s sur le dépôt réel (4 contrôles) ; section 4b (indexé seul, non suivi, supprimé, backlog en échec)
- [x] `--changed` limite `--static` selon `check-paths.tsv` ; chaque étape de `--static` a une ligne dans la table (test) ; toute modification de `tools/dev/`, `.github/` ou `pyproject.toml` sélectionne tout ; sans `origin/main` : tout — `check --static --changed` du 2026-11-18 : .md 10,9 s (leak-guard `*`), .py 12,6 s, apps/ 10,7 s ; section 4c : un .md n'exécute pas un yamllint qui échouerait, un .yaml l'exécute, `tools/dev/`, `.github/`, `pyproject.toml` ou absence d'`origin/main` sélectionnent tout, table modifiée = sélection modifiée ; `--list` et la table : une ligne par contrôle et aucune ligne orpheline (cas négatif : ligne retirée détectée)
- [x] `--jobs N` : mêmes résultats qu'en série, plus rapide (test avec outils factices) — section 4d : 3 contrôles factices de 1 s, série 3,x s contre 1,x s avec `--jobs 3`, mêmes statuts et même ordre, FAIL conservé ; `check --static` complet 2026-11-18 : 116 s en série, 41 s avec `--jobs 4` (4 vCPU)
- [x] `--json` (une ligne par étape plus une ligne de bilan) et reçu `.git/check-receipt.json` (SHA, niveau, résultats, date UTC) — section 4e : stdout = une ligne JSON par contrôle + bilan (validé par python), texte lisible sur stderr ; reçu `.git/check-receipt.json` : SHA, `dirty`, niveau, date UTC, résultats, hors de l'arbre suivi (`git status` ne le voit pas)
- [x] `gitleaks` aligné sur le job `secrets` de `ci.yaml` (même configuration par défaut, même périmètre) : 0 FAIL sur main — `check --static` du 2026-11-18 : `gitleaks` PASS en 1,3 s (208 FAIL avant) ; section 4f : appel `git --config <défaut> --redact ... .` comparé au job `secrets` de `ci.yaml`, trouvaille factice = FAIL ; vérifié par mutation (ancien appel : 2 assertions FAIL). La garde propre au dépôt reste `leak-guard` (arbre, `.gitleaks.toml`, job `leak-guard`)
- [x] `coverage` et `appgen-unittest` ne rejouent plus les mêmes tests (fusion ou saut), sans perdre de contrôle quand `coverage` est NOT_TESTED — section 4g : quand `coverage` tourne, `appgen-unittest` est `SKIP` (« fusionné ») et listé ; `coverage` exclu ou NOT_TESTED : `appgen-unittest` s'exécute ; vérifié par mutation (fusion désactivée : 2 assertions FAIL). Gain : environ 7 s en série
- [x] un outil absent donne NOT_TESTED, jamais PASS ; cas négatifs dans `tests/dev-factory/check-test.sh` — `check-test.sh` : PATH restreint, ruff factice 0.0.1, `--file`/`--fast`/`--json` sans outil = NOT_TESTED (rc 3 avec `--strict`) ; assertions ajoutées (section 4), mutations (gitleaks, sélection toujours vraie, fusion) détectées
- [x] durées de chaque mode mesurées et datées (Notes) — voir Notes (mesures du 2026-11-18)
- [x] `python3 tools/backlog/check.py` : 0 erreur — 0 erreur (2026-11-18)

## Notes
Mesures du 2026-11-18 (VM cloud x86_64, 4 vCPU, ruff 0.16.9, helm, kubeconform, actionlint et gitleaks présents ; `guard-check`, `identities` et `hooks` NOT_TESTED) :

| Mode | Durée |
|---|---|
| `--file` (1 fichier shell / py / yaml) | 0,5 s / 0,0 s / 0,0 s ; app.yaml avec `appgen validate` 0,1 s |
| `--fast` (dépôt réel) | 1,4 s |
| `--static --changed` (.md / .py / app.yaml) | 10,9 s / 12,6 s / 10,7 s (`--jobs 4`) |
| `--static` série | 116 s (87 s avant l'ajout des assertions de `check-selftest`) |
| `--static --jobs 4` | 41 s |

Écart avec la demande : le job `secrets` de `ci.yaml` scanne l'historique (`gitleaks git`) avec les règles par défaut ; ce sont les règles du dépôt (`.gitleaks.toml`) que `check` chargeait, d'où les 208 FAIL. `leak-guard` applique les règles du dépôt à l'arbre, comme le job `leak-guard`.

Hors périmètre de ce ticket : `quality` et `coverage` sont FAIL sur la base actuelle de la branche (cliquet : `tools/appgen/appgen.py` 1485 lignes > 1481, 9 erreurs ruff > 8, 14 erreurs mypy > 12) ; antérieurs à ce ticket, à traiter par un ticket qualité.

Ne touche pas `ci.yaml` (SL-6) ni les hooks (SL-5). Art antérieur : voir la section de PR « Implémentations publiques consultées ».
