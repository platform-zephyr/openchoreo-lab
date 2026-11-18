---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Décaler les contrôles vers la gauche : environnement de dev des agents

Date : 2026-11-18. Proposition seulement : aucun fichier de CI, hook, `.pre-commit-config.yaml` ni ticket n'est créé ; `STATE.md`, `ROADMAP.md`, `ci.yaml` et `backlog/` ne sont pas modifiés. Dépôt PUBLIC : aucune IP, hôte interne, identifiant ni secret. Légende : **[M]** mesuré ici le 2026-11-18 (VM cloud x86_64, 4 vCPU, sans Docker) ; **[V]** source lue ; **[E]** estimation ; **[H]** hypothèse à mesurer ; **NOT_TESTED** non exécuté.

## 0. Conclusion
1. **Cause racine : `tools/dev/check --static` n'est pas équivalent à la CI.** Il omet des jobs entiers de `ci.yaml` (`quality`, `quality-coverage`, `lint-code` ruff, `crd-schema`, tests `backlog`/`quality`/`identities`) et plusieurs contrôles ne tournent pas dans la VM cloud faute d'outils (`helm`, `kubeconform`, `actionlint`, `gitleaks` absents [M]). L'agent croit avoir fini, la CI trouve le reste.
2. **Preuve sur la PR #58 (run `ci` 44291535887, 3 jobs rouges sur 15 [M]).** `quality` et `quality-coverage` échouent sur le cliquet ruff (`tools/factory/ledger.py`, `tests/factory/ledger_test.py`, `tools/cost/agent_usage.py` : « erreurs ruff > 0 ») ; `python3 tools/quality/check.py` reproduit le même FAIL en **1,4 s** en local [M], mais `check --static` ne l'appelle pas. `platform-render` échoue sur 15 cas de `tests/security-bundle` (ABANDON `tls-server-name inattendu`, `tools/oke/lib.sh:112`) ; il exige `helm` et `yq`, absents de la VM cloud : le contrôle est **inexécutable** là où l'agent travaille. `leak-guard` était vert sur ce run ; ses échecs signalés ailleurs ne sont pas relus ici (NOT_TESTED).
3. **Défaut annexe** : sans `gitleaks`, l'étape `leak-guard` de `check` sort **FAIL** (rc 1, « NOT_TESTED gitleaks introuvable » dans le journal) au lieu de NOT_TESTED [M]. Un FAIL d'outillage apprend à ignorer les FAIL.
4. **Proposition** : une échelle à 7 niveaux (§2), une seule commande `tools/dev/check` avec `--fast | --static | --full | --k3d`, un `.pre-commit-config.yaml` (pre-commit et pre-push), des hooks Claude Code (PostToolUse, Stop, PreToolUse sur `git push` et `gh pr create`), un script d'installation d'outils tiré de `toolchain.lock`, et une règle mesurable : **« la CI ne découvre rien qu'un contrôle local rapide aurait trouvé »** (§4), appliquée par un test de parité `ci.yaml` ↔ `check` et un compteur d'« évasions » par PR.
5. **Priorités** : (P1) combler l'écart `check` ↔ CI et installer les outils manquants dans la VM cloud, environ une demi-journée [E], supprime à lui seul les 3 échecs de la PR #58 ; (P2) niveaux `--fast`, pre-commit, hooks ; (P3) parité structurelle et métrique ; (P4) devcontainer multi-architecture et tests de politique sans cluster.
6. **Non prouvé** : l'effet sur le taux de CI verte au premier push (c'est une hypothèse, la mesure est au §4) ; les durées de `--full` avec tous les outils dans la VM cloud ; le build du devcontainer (jamais exécuté, `docs/DEV-FACTORY.md`) ; le comportement des hooks Claude Code dans une session cloud (ADR-0022 : « les hooks ne tournent pas dans tous les contextes cloud », la CI reste la preuve).

## 1. État actuel et écarts

### 1.1 Ce qui existe
| Élément | État | Source |
|---|---|---|
| `tools/dev/check` (`--static`, `--k3d`, `--strict`) | livré, T-332 `in-progress` ; 25 étapes PASS / FAIL / NOT_TESTED, durée 58 s dans la VM cloud avec 9 NOT_TESTED [M] | `tools/dev/check` |
| `tools/dev/toolchain.lock` + test de concordance lock = Dockerfile = `ci.yaml` | livré, arm64 seulement ; empreintes amd64 absentes | `tools/dev/toolchain.lock` |
| `.devcontainer/` (Dockerfile arm64, 1 vCPU / 1 GiB) | texte vérifié en CI ; image jamais construite | `docs/DEV-FACTORY.md` |
| Garde de fuite `tools/dev/leak-guard.sh` | livrée (T-303), appelée par `check` et la CI | `ci.yaml`, `check` |
| `.claude/settings.json` | `permissions` + `sandbox` seulement : **aucun hook** (T-331 `todo`) | `.claude/settings.json` |
| `pre-commit` | absent : aucun `.pre-commit-config.yaml`, outil non installé [M] | dépôt |
| Cliquet `tools/quality/check.py` (1,4 s [M]) | livré (T-414), **hors de `check`** | `ci.yaml` job `quality` |
| Cache et parallélisme de la CI | `platform` coupé en deux, cache de charts (CI-SPEED) ; `ci-ok` 80-120 s [M, CI-SPEED] | `docs/research/CI-SPEED.md` |

### 1.2 Contrôles de `ci.yaml` et leur couverture locale
« Local » = `tools/dev/check --static` dans la VM cloud, 2026-11-18.

| Job CI | Équivalent dans `check --static` | Écart |
|---|---|---|
| `yamllint` | `yamllint` (mêmes dossiers) | aucun |
| `appgen` | `appgen-validate`, `appgen-check`, `appgen-unittest` ; `identities` seulement si `tests/identities/run.sh` existe | `tools/backlog/identities_lint.py` et `tests/identities` : NOT_TESTED (script absent) |
| `crd-schema` | aucun | clone d'OpenChoreo + `kubeconform -strict` sur le rendu `generated/` : **absent** (clone réseau, outil absent) |
| `secrets` (gitleaks, historique) | `gitleaks` | NOT_TESTED : outil absent |
| `leak-guard` | `leak-guard` | **FAIL** sans gitleaks (devrait être NOT_TESTED) |
| `actionlint` | `actionlint` | NOT_TESTED : outil absent |
| `charts` | aucun | trivial (aucun chart local) |
| `platform` | `argo-guard-*`, `cell-cpt`, `shellcheck` ; yamllint de `platform/*` | `check` lint `apps tools tests .github`, pas `platform/` (CI le fait dans `platform`) |
| `platform-render` | `security-bundle`, `render-check`, `uninstall-guards`, `kubeconform-platform` | **4 NOT_TESTED** : `helm`, `kubeconform` absents ; `yq` présent |
| `release-history` | `release-history` | aucun |
| `dev-factory` | `dev-factory-static`, `check-selftest`, `toolchain-lock`, `devcontainer-json` | aucun |
| `backlog` | `backlog` (`check.py`) | `python3 -m unittest discover -s tests/backlog` **absent** |
| `lint-code` | `shellcheck` (liste de fichiers fixe, sans `-S warning`) | `ruff check --select F,B,E9 tools tests` **absent** ; `shellcheck -S warning` sur `git ls-files '*.sh'` **absent** |
| `quality` | aucun | **absent** : cliquet + `tests/quality` |
| `quality-coverage` | aucun | **absent** : `coverage` + plancher + diff-cover |

Bilan [M] : sur 15 jobs requis, 4 sont absents de `check` (`crd-schema`, `lint-code` ruff, `quality`, `quality-coverage`), 4 sont NOT_TESTED ou FAIL à cause d'outils manquants (`platform-render`, `actionlint`, `secrets`, `leak-guard`), 2 sont partiels (`backlog`, `appgen`). Les contrôles absents de `check` sont les moins chers : ruff 0,02 s, cliquet 1,4 s [M].

### 1.3 Échecs de la PR #58 [M, journaux de la CI]
| Job | Cause lue | Attrapable en local ? | Niveau où il aurait dû l'être |
|---|---|---|---|
| `quality` | cliquet : 3 fichiers avec erreurs ruff > 0, 3 dégradations | oui, `python3 tools/quality/check.py` reproduit le FAIL en 1,4 s | L1 (pre-commit) |
| `quality-coverage` | même `check.py` (journal tronqué à la fin : cause exacte non relue, **probablement** le même cliquet) | oui avec `coverage` (installé), environ 40 s selon T-414 | L2 (pre-push) |
| `platform-render` | `tests/security-bundle` : 15 FAIL, ABANDON `tls-server-name inattendu` (valeur de test non conforme à l'expression de `tools/oke/lib.sh:112`) | **non reproduit** : `helm` absent de la VM [M] | L2 si l'outil est installé ; sinon L3 |

## 2. Échelle des niveaux

Principe : un contrôle va au niveau **le plus à gauche** où il est déterministe, sans secret et sous le budget de durée ; il passe à droite s'il dépasse le budget ou s'il est instable. Un contrôle qui échoue en CI deux fois en 30 jours alors qu'il tient dans le budget d'un niveau plus à gauche y est déplacé (§4, règle de promotion).

Sources de l'échelle : pyramide de tests Kubernetes sans cluster d'abord (lint, schéma, politique, rendu, puis cluster jetable, puis réel). Le dépôt a déjà un exemple fonctionnel : les `kubeconform -strict` contre les CRD épinglées, `argo_guard`, `psa_check` et les rendus Helm tournent sans cluster ; seuls `tests/k3d`, `vap`, `argo-escalation` et `gitops-k3d` en demandent un (3 à 23 min [M, CI-SPEED]).

| Niveau | Quand | Budget | Contrôles | Où | Commande unique |
|---|---|---|---|---|---|
| **L0 écriture** | après chaque Edit / Write | < 2 s par fichier | syntaxe et lint du fichier touché : `yamllint`, `ruff check`, `shellcheck -S warning`, JSON ; `appgen validate` si `apps/*/app.yaml` ; `argo_guard` si `platform/` | hook Claude Code PostToolUse ; éditeur | `tools/dev/check --file <chemin>` (appelée par le hook) |
| **L1 pre-commit** | `git commit` | < 10 s sur les fichiers indexés | L0 sur l'index + `gitleaks` (index) + `leak-guard` + cliquet `quality` + `backlog check` + `actionlint` si workflow touché + conflits, fins de ligne, `check-yaml` | git (pre-commit framework) ; Claude Code | `tools/dev/check --fast` |
| **L2 pre-push** | `git push`, `gh pr create`, hook Stop | < 90 s (cible 60 s) | tout ce qui est statique, sans réseau ni cluster, **sélectionné par chemins** : `appgen` (validate, check, unittest), `argo_guard` + cas négatifs, `cell-cpt`, `release-history`, `tests/*` des dossiers touchés, ruff complet, `mypy` appgen, couverture si `tools/` change | git (pre-push) ; Claude Code (Stop, PreToolUse sur `git push`) ; devcontainer | `tools/dev/check --static --changed` |
| **L3 CI pré-merge** | PR, `merge_group` | < 3 min (aujourd'hui 80-120 s [M]) | **tout L2 sans sélection** + rendus Helm, security bundle, `kubeconform -strict` (plateforme et CRD), `crd-schema`, gitleaks sur l'historique, couverture, `ci-ok` | GitHub Actions, runners hébergés | `tools/dev/check --full --strict` (par job : `--only <étapes>`) |
| **L4 post-merge** | push sur `main` | 3-25 min | suites k3d (`vap`, `gitops-k3d`, `k3d`, `argo-escalation`), niveau N1 d'ADR-0022 | GitHub Actions (`k3d-integration`) | `tools/dev/check --k3d` |
| **L5 nuit** | cron | 30 min à 2 h | toutes les suites k3d, dérive amont (charts, CRD, images), rapport d'évasions (§4), mutation et tests lents si ajoutés | GitHub Actions, cron | `tools/dev/check --full --k3d` + `tools/dev/ci-escapes.py` |
| **L6 réel** | après merge et réconciliation | minutes à heures | preuve runtime datée (N2 du lab, puis OKE sur mandat de Paul) | cluster réel, lecture seule ou GitOps | skills `diagnose-app`, `add-app` ; `golden-paths/` |

Règles de l'échelle :
- **Les jobs statiques restent tous pré-merge et inconditionnels** : ils durent moins de 60 s chacun et `ci-ok` traite `skipped` comme un échec (CI-SPEED §2). La sélection par chemins sert **localement** (L2) et pour k3d (L4), pas pour `ci.yaml` pré-merge.
- **`--full` et la CI exécutent le même code** : un job CI est `tools/dev/check --only <étapes> --strict` (T-332, critère 3). Un contrôle ajouté en CI sans étape de `check` est refusé par le test de parité (§4).
- Statuts inchangés : PASS / FAIL / NOT_TESTED ; `--strict` fait de NOT_TESTED un échec. En local, un outil manquant reste NOT_TESTED **et** `check` imprime la ligne d'installation (`tools/dev/doctor`).
- **Aucun niveau n'a de secret** (L0 à L3). Le secret facultatif `LEAK_GUARD_EXTRA_PATTERNS` n'existe qu'en CI ; local, les règles génériques suffisent et l'écart est écrit dans la sortie.

## 3. Proposition concrète

### 3.1 `tools/dev/check` : modes
Ajouts à `tools/dev/check` (bash existant, mêmes helpers `step`, `script_step`) :

| Option | Effet |
|---|---|
| `--file <chemin>...` | L0 : lint du ou des fichiers, choisi par extension et chemin. Sortie courte, rc 2 si échec (pour le hook). |
| `--fast` | L1 : fichiers indexés (`git diff --cached --name-only`), sinon fichiers modifiés depuis `merge-base origin/main`. |
| `--static` | L2, comportement actuel **plus** les étapes manquantes (ci-dessous). |
| `--changed` | restreint `--static` aux étapes dont les chemins sont touchés (table `tools/dev/check-paths.tsv`, modèle `affected-tests.conf` de kube-ops) ; toute modification de `tools/dev/`, `.github/`, `pyproject.toml` ou `toolchain.lock` sélectionne tout. |
| `--full` | L3 : `--static` sans sélection + étapes réseau (`crd-schema`, rendus, kubeconform, gitleaks historique). |
| `--k3d` | L4, inchangé (hors cluster : NOT_TESTED, jamais OKE). |
| `--jobs N` | exécution parallèle des étapes indépendantes (sérialisation par `flock` conservée pour le cache de charts). Gain attendu : 58 s → environ 30 s sur 4 vCPU [E]. |
| `--json` | une ligne JSON par étape (`name`, `status`, `seconds`, `level`) écrite aussi dans un reçu `$(git rev-parse --git-dir)/check-receipt.json` (SHA, niveau, date) ; sert au §4. |

Étapes à ajouter à `--static` (écarts du §1.2, toutes sans réseau) :
- `quality` : `python3 -m unittest discover -s tests/quality` puis `python3 tools/quality/check.py` (1,4 s [M]) ;
- `ruff-bugs` : `ruff check --select F,B,E9 tools tests` (0,02 s [M]) ;
- `shellcheck-all` : `git ls-files -z '*.sh' | xargs -0 shellcheck -S warning` (remplace la liste fixe de `shellcheck_all`) ;
- `backlog-unittest` : `python3 -m unittest discover -s tests/backlog` ;
- `identities-lint` : `python3 -I tools/backlog/identities_lint.py` ;
- `yamllint` élargi aux dossiers `platform/*` listés dans le job `platform` ;
- `coverage` (en `--full` ou `--static` si `tools/` change) : même recette que `quality-coverage`, base `origin/main` ;
- corriger `leak-guard` : rc 125 (précondition) quand `gitleaks` manque, pour rendre NOT_TESTED.

### 3.2 `.pre-commit-config.yaml` (esquisse)
Règle de conception : **les binaires viennent de `toolchain.lock`** (hooks `language: system` ou variantes `-system`), pour garder **une seule liste d'outils et d'empreintes** ; le framework n'orchestre que. Les hooks distants sont réservés aux contrôles triviaux, avec `rev` épinglé par SHA de commit.

```yaml
# .pre-commit-config.yaml (proposition ; versions du framework et SHA à figer dans la PR)
minimum_pre_commit_version: "4.0.0"
default_install_hook_types: [pre-commit, pre-push]
default_stages: [pre-commit]
fail_fast: false          # tout afficher d'un coup : moins d'allers-retours
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <SHA de v6.0.0, à figer>
    hooks:
      - {id: check-merge-conflict}
      - {id: check-yaml, args: [--allow-multiple-documents]}
      - {id: end-of-file-fixer}
      - {id: mixed-line-ending}
      - {id: check-json}
  - repo: local
    hooks:
      - {id: yamllint, name: yamllint, language: system, types: [yaml],
         entry: yamllint -c tools/appgen/yamllint.yaml}
      - {id: ruff-bugs, name: ruff (F,B,E9), language: system, types: [python],
         entry: ruff check --select F,B,E9 --force-exclude}
      - {id: shellcheck, name: shellcheck -S warning, language: system, types: [shell],
         entry: shellcheck -S warning -x -P SCRIPTDIR}
      - {id: gitleaks, name: gitleaks (index), language: system, pass_filenames: false, always_run: true,
         entry: gitleaks git --pre-commit --redact --staged --no-banner}
      - {id: leak-guard, name: garde de fuite (T-303), language: system, pass_filenames: false, always_run: true,
         entry: tools/dev/leak-guard.sh}
      - {id: actionlint, name: actionlint, language: system, files: '^\.github/workflows/',
         pass_filenames: false, entry: actionlint}
      - {id: appgen-validate, name: appgen validate, language: system, files: '^(apps|tools/appgen)/',
         pass_filenames: false, entry: python3 tools/appgen/appgen.py validate}
      - {id: appgen-drift, name: appgen check (generated/ à jour), language: system,
         files: '^(apps|tools/appgen|platform/component-types)/', pass_filenames: false,
         entry: python3 tools/appgen/appgen.py check}
      - {id: argo-guard, name: argo_guard, language: system, files: '^(platform|clusters|tools/oke)/',
         pass_filenames: false, entry: python3 -I tools/oke/argo_guard.py .}
      - {id: backlog, name: backlog check, language: system, files: '^backlog/',
         pass_filenames: false, entry: python3 tools/backlog/check.py}
      - {id: quality-ratchet, name: cliquet de maintenabilité, language: system,
         files: '^(tools|tests)/.*\.py$', pass_filenames: false, entry: python3 tools/quality/check.py}
      - {id: check-static, name: check --static --changed (pré-push), language: system,
         stages: [pre-push], pass_filenames: false, always_run: true,
         entry: tools/dev/check --static --changed}
```

Notes :
- La même tactique existe dans le dépôt privé de Paul : un hook local `always_run` qui appelle le script de validation statique du dépôt, plus `gitleaks` sur l'index [V]. Ici on garde la granularité par fichier (L1) car la validation complète dure plus de 10 s.
- Les hooks `gitleaks`, `actionlint` et `shellcheck` publient une variante `-system` ou un point d'entrée simple, donc compatibles avec les binaires épinglés [V : `.pre-commit-hooks.yaml` de gitleaks, actionlint, shellcheck-py, lus 2026-11-18]. `ruff-pre-commit` expose `ruff-check` ; on garde `local` pour la même version que `pyproject.toml` / CI (`ruff==0.16.9`).
- Installation : `tools/dev/setup` (nouveau) exécute `pre-commit install` (pre-commit et pre-push) et `tools/dev/doctor`. `git commit --no-verify` et `git push --no-verify` restent refusés par `permissions.deny` de `.claude/settings.json` [V].
- Le service d'intégration continue du framework n'est pas retenu (dépôt public, mais la CI maison est la preuve et `ci-ok` le seul check requis).

### 3.3 Hooks Claude Code (extension de T-331)
Faits retenus de la documentation [V, code.claude.com/docs/en/hooks, lue 2026-11-18, page tronquée à 100 000 caractères sur 294 000] : `PreToolUse` avec rc 2 bloque l'appel ; `PostToolUse` ne bloque pas (rc 2 montre stderr à Claude, l'outil a déjà tourné) ; `Stop` avec rc 2 empêche la fin et relance la conversation ; `SessionStart` ne bloque pas ; délai par défaut 600 s pour `command`. Le champ `stop_hook_active` et le plafond de blocs consécutifs (8, d'après T-331) ne sont pas relus ici.

| Événement | Matcher | Commande | Effet | Budget |
|---|---|---|---|---|
| `SessionStart` | `startup`, `resume` | `tools/dev/doctor` | liste les outils manquants (NOT_TESTED prévisible), installe les hooks git ; imprime ticket, branche, dernier état CI | < 3 s |
| `PreToolUse` | `Bash` | garde de commandes de T-331 | refus `kubectl`, `curl \| sh`, `--no-verify`, push forcé | < 1 s |
| `PreToolUse` | `Bash(git push *)`, `Bash(gh pr create *)` | `tools/dev/check --static --changed --strict-fail` | refuse le push si un FAIL ; n'exige pas le reste (NOT_TESTED affiché) | < 90 s |
| `PostToolUse` | `Edit\|Write\|MultiEdit` | `tools/dev/check --file "$file_path"` | lint du fichier ; rc 2 + stderr = retour immédiat à l'agent | < 2 s |
| `Stop` | tous | `tools/dev/check --fast` puis, si le dépôt a changé, `--static --changed` | rc 2 + résumé court si FAIL ; une exécution par état de l'arbre (reçu) pour ne pas boucler | < 60 s |

Points d'attention :
- **Une règle sans exception est un hook, jamais une phrase d'`AGENTS.md`** (ADR-0022 §3). Les contrôles bloquants sont donc des hooks de type `command` (déterministes) ; aucun hook `prompt` ou `agent`.
- Les hooks sont une couche de **retour rapide**, pas la preuve : ils peuvent ne pas tourner dans toutes les sessions cloud. Les hooks **git** (§3.2) et la CI couvrent ce cas. Trois couches indépendantes valent mieux qu'une.
- `.claude/` est noyau (CODEOWNERS) : la PR qui ajoute les hooks est REVUE.
- Le script de hook lit le JSON d'entrée sur stdin (`jq`), n'écrit que sur stderr en cas d'échec, ne contacte aucun réseau ni cluster, et n'affiche jamais de valeur sensible (sortie de `leak-guard` déjà masquée).
- Mesure de chaque hook sur dépôt propre exigée par T-331 (< 5 s) ; le hook `PreToolUse` sur `git push` fait exception documentée (< 90 s).

### 3.4 Outils dans la VM cloud des agents (T-334)
État [M] : présents `yamllint`, `ruff`, `shellcheck`, `yq`, `jq`, `radon`, `mypy`, `coverage` ; **absents** `helm`, `kubeconform`, `actionlint`, `gitleaks`, `pre-commit`. La VM est x86_64, la CI arm64 : `toolchain.lock` n'a que des empreintes linux-arm64.

Proposition pour `tools/dev/cloud-setup.sh` (T-334) :
1. lit `toolchain.lock` ; table d'empreintes **linux-amd64** ajoutée au lock (`*_SHA256_AMD64`, vérifiée par `lock-concordance.sh`), publiée par les releases amont (jamais calculée sur un binaire non vérifié) ;
2. installe `helm`, `kubeconform`, `actionlint`, `gitleaks` (et `shellcheck`, `yq`, `jq` si absents) dans `~/.local/bin`, archive vérifiée par `sha256sum -c` ; Python : `yamllint`, `PyYAML`, `jsonschema`, `ruff`, `radon`, `mypy`, `coverage`, `pre-commit` en versions `==` ;
3. idempotent, < 5 min, aucun secret ; hôtes autorisés : GitHub (releases), registres de paquets, `get.helm.sh` (déjà utilisé par la CI), PyPI ;
4. se termine par `tools/dev/doctor` qui rend la liste des outils manquants et **échoue** si un outil requis par `--static` manque ;
5. ne tourne pas à la reprise d'une VM inactive (T-334, Notes) : `SessionStart` rappelle `doctor`, qui réinstalle à la demande dans `~/.local/bin`.

Sans cette étape, la classe d'échec `platform-render` (1.3) reste invisible en local : c'est la **recommandation P1 n°2**.

### 3.5 Devcontainer
Écarts [V] par rapport à l'objectif « mêmes contrôles que la CI » :
- Dockerfile arm64 uniquement (binaires `linux_arm64` codés en dur) : ajouter `TARGETARCH` et les empreintes amd64 du lock, pour qu'un même fichier serve le Mac, le N100 (x86_64) et la VM cloud ;
- venv `/opt/lint` : ajouter `ruff`, `radon`, `mypy`, `coverage`, `pre-commit` aux mêmes versions que `ci.yaml` ;
- `postCreateCommand` : `tools/dev/doctor && pre-commit install --install-hooks` en plus de `guard-check.sh` ;
- limite `--cpus=1 --memory=1g` : mesurer `check --static` sous cette limite avant de la garder (NOT_TESTED ; probablement 2 à 3 fois plus lent que les 58 s [E]) ;
- l'image n'est jamais construite en CI : ajouter un build périodique (L5, hors `ci-ok`) pour détecter la dérive des pins.
Prior art : le standard Dev Containers (`devcontainer.json`, `postCreateCommand`, `features`) est déjà utilisé ; rien à inventer. L'exécution de la CI **dans** la même image (`container:` de GitHub Actions) garantirait la parité totale mais allonge chaque job (tirage d'image) : écarté tant que le test de parité (§4) suffit.

### 3.6 Entrée unique : `just` ou `make` ?
Le dépôt privé de Paul utilise un `.justfile` comme point d'entrée (`just check`, `just check-affected`, `just ci`) [V]. Ici `tools/dev/check` joue déjà ce rôle et est lu par la CI, le conteneur et le hook. **Ne pas ajouter `just`** : un second point d'entrée à synchroniser contredit « une seule commande ». Un alias `tools/dev/dev test` existe déjà ; il suffit d'ajouter `dev fast` et `dev check` comme alias fins si utile.

## 4. Règle « la CI ne découvre rien qu'un contrôle local rapide aurait trouvé »

Énoncé : **tout job rouge de `ci-ok` dont le contrôle a un niveau ≤ L2 est une évasion** ; une évasion est un défaut de l'environnement local, pas seulement du code. Cible : 0 évasion par semaine après P1 ; taux de PR vertes au premier push ≥ 80 % [H : base à mesurer, aujourd'hui inconnue] ; au plus 2 runs `ci` par PR.

### 4.1 Mesure structurelle (bloquante, statique)
`tools/dev/ci-map.tsv` : pour chaque job de `ci.yaml`, `job<TAB>étapes de check<TAB>niveau` ou `CI-ONLY<TAB>raison`. Test `tests/dev-factory/ci-parity.sh` (ajouté à `check`, étape `ci-parity`) :
- chaque job de `needs:` de `ci-ok` figure dans la table ; sinon FAIL (« job CI sans équivalent local ni exception motivée ») ;
- chaque étape nommée existe dans `tools/dev/check` ;
- les `CI-ONLY` restent rares et motivés (aujourd'hui : `crd-schema` pour le clone amont, `secrets` pour l'historique complet).
Cas négatifs : un job ajouté sans ligne, une étape inexistante, un `CI-ONLY` sans raison. Le fichier `tools/dev/ci-map.tsv` est noyau (CODEOWNERS).

### 4.2 Mesure empirique (non bloquante, hebdomadaire)
`tools/dev/ci-escapes.py` (stdlib seule ; `gh api` en lecture seule, comme `tools/github/`) pour les PR fusionnées ou ouvertes de la semaine :
- pour chaque run `ci` de PR : jobs en échec → étape de check (via `ci-map.tsv`) → niveau ;
- sorties dans `quality.v1`-compatible : `first_push_green` (bool), `ci_runs_per_pr`, `escapes` (liste `{pr, job, niveau}`), `minutes_to_green`, `escape_rate = jobs rouges de niveau ≤ L2 / jobs rouges` ;
- exécuté en L5 (nuit) ; résultat publié en artefact et résumé dans le ledger de la fabrique (`tools/factory/ledger.py`, T-313) si celui-ci l'accepte ;
- **règle de promotion** : un contrôle de niveau ≥ L3 qui provoque ≥ 2 échecs de PR en 30 jours et dure moins que le budget de L2 est ouvert en ticket « décaler à gauche » ; un contrôle de L1 ou L2 instable (échec non reproductible) est ouvert en ticket « décaler à droite ».

### 4.3 Preuve locale datée
`check` écrit le reçu (SHA, niveau, résultats, date). Le gabarit de PR (`.github/pull_request_template.md`, noyau) reçoit une ligne `Preuve locale : check --static @ <sha> : PASS / INCOMPLET (NOT_TESTED : <liste>)`. Ce n'est pas une garantie (déclaratif) mais rend l'écart visible au relecteur.

### 4.4 Rétro-test sur la PR #58
| Job rouge | Niveau du contrôle | Évasion ? | Après P1 |
|---|---|---|---|
| `quality` | L1 | oui | attrapé par `--fast` (pre-commit) et par le hook Stop |
| `quality-coverage` | L2 | oui (si cause = cliquet, non relue) | attrapé par `--static` |
| `platform-render` | L2 (outil absent en VM cloud) | oui, par défaut d'outillage | attrapé si `helm` et `kubeconform` installés (`cloud-setup.sh`) |
`escape_rate` = 3/3 [M, sur ce run seul : un échantillon ne fait pas une tendance].

## 5. Tickets proposés (à ajouter au backlog, non créés)
Numéros libres à attribuer à l'intégration (dernier numéro existant : T-452). Classe REVUE si `.claude/`, `.github/`, `CODEOWNERS` ou `tools/quality/` sont touchés. `model` : `claude-sonnet-5-5`, `routing: R3-defaut`, `lane` indiquée.

| Clé | Titre | Périmètre de fichiers | Dépend de | Effort | Classe | Lane / stage |
|---|---|---|---|---|---|---|
| SL-1 | Combler l'écart `check --static` ↔ CI : étapes `quality`, `ruff-bugs`, `shellcheck-all`, `backlog-unittest`, `identities-lint`, yamllint `platform/*`, `coverage` ; `leak-guard` en NOT_TESTED sans gitleaks | `tools/dev/check`, `tests/dev-factory/` | T-332 (à fusionner dans son avancement), T-413, T-414 | high | AUTONOME | dev-factory / S0 |
| SL-2 | Installer `helm`, `kubeconform`, `actionlint`, `gitleaks`, `pre-commit` dans la VM cloud : empreintes linux-amd64 dans `toolchain.lock`, `cloud-setup.sh`, `tools/dev/doctor` | `tools/dev/toolchain.lock`, `tools/dev/cloud-setup.sh`, `tools/dev/doctor`, `tests/dev-factory/` | T-332 ; réalise T-334 (fusion proposée) | high | AUTONOME + MANDAT (création de l'environnement par Paul) | agents-harness / S0 |
| SL-3 | `check --fast`, `--file`, `--changed`, `--jobs`, `--json`, reçu daté, table `check-paths.tsv` | `tools/dev/check`, `tools/dev/check-paths.tsv`, `tests/dev-factory/` | SL-1 | high | AUTONOME | dev-factory / S1 |
| SL-4 | `.pre-commit-config.yaml` (pre-commit + pre-push, binaires du lock) et `tools/dev/setup` | `.pre-commit-config.yaml`, `tools/dev/setup`, `tests/dev-factory/`, `docs/DEV-FACTORY.md` | SL-3, SL-2 | medium | AUTONOME | dev-factory / S1 |
| SL-5 | Hooks Claude Code : PostToolUse (lint du fichier), Stop (`--fast` puis `--static --changed`), PreToolUse sur `git push` et `gh pr create`, SessionStart (`doctor`) ; **extension du périmètre de T-331** | `.claude/hooks/`, `.claude/settings.json`, `tests/hooks/` | SL-3, T-331, T-330 | high | REVUE | agents-harness / S1 |
| SL-6 | Parité `ci.yaml` ↔ `check` : `ci-map.tsv`, test `ci-parity.sh`, et jobs CI qui appellent `check --only <étapes> --strict` (critère 3 de T-332) | `tools/dev/ci-map.tsv`, `tests/dev-factory/ci-parity.sh`, `.github/workflows/ci.yaml`, `.github/CODEOWNERS` | SL-1, SL-3, T-332 | high | REVUE | ci / S1 |
| SL-7 | Indicateur d'évasions : `tools/dev/ci-escapes.py` (lecture seule), tests, rapport hebdomadaire, ligne « Preuve locale » du gabarit de PR | `tools/dev/ci-escapes.py`, `tests/dev-factory/`, `.github/pull_request_template.md` | SL-6 | medium | REVUE | ci / S2 |
| SL-8 | Devcontainer multi-architecture (`TARGETARCH`), outils Python alignés, `postCreateCommand`, mesure de `check --static` sous 1 vCPU / 1 GiB, build périodique hors `ci-ok` | `.devcontainer/`, `tests/dev-factory/`, workflow de build | SL-2, T-332 | high | REVUE | dev-factory / S2 |
| SL-9 | Spike (1 j) : tests de politiques sans cluster pour `tests/kyverno` et les VAP (`kyverno test`, éventuellement `conftest`) au niveau L2/L3, verdict PASS / FAIL / BLOCKED et durée ; aujourd'hui ces tests passent par k3d | `docs/research/`, `tests/kyverno/` (lecture) | aucune | medium | AUTONOME | ci / S2 |
| SL-10 | Règles d'agent : `AGENTS.md` (« avant `git push` : `check --static --changed` ; PASS avec niveau et reçu ») et skills `add-app` / `fix-app` (étape « local d'abord ») | `AGENTS.md`, `.agents/skills/` | SL-3 | low | REVUE | gouvernance / S1 |
| SL-11 | Nuit : workflow cron `check --full --k3d` + dérive amont + `ci-escapes` + alerte (alignée sur T-451 et T-452, à fusionner avec leur décision d'alerte) | `.github/workflows/` | SL-7, T-451, T-452 | medium | REVUE | ci / S3 |

Ordre conseillé : SL-1 → SL-2 (en parallèle) → SL-3 → SL-4 et SL-5 → SL-6 → SL-7 → SL-8, SL-9, SL-10, SL-11. T-451 (`CSafeLoader`) réduit L2 de 58 s à environ 30 s [E, CI-SPEED] et doit passer avant SL-3 pour tenir le budget de 60 s.

## 6. Recommandations priorisées
| Rang | Action | Effet attendu | Coût | Preuve |
|---|---|---|---|---|
| P1.1 | SL-1 : ajouter `quality`, ruff, shellcheck complet, tests backlog/identités à `check --static` | supprime 2 des 3 échecs de la PR #58 | environ 0,5 j [E] | reproduction du FAIL en 1,4 s [M] |
| P1.2 | SL-2 : `helm`, `kubeconform`, `actionlint`, `gitleaks` dans la VM cloud | rend `platform-render` exécutable en local | 0,5 à 1 j [E] ; geste de Paul pour l'environnement | outils absents constatés [M] |
| P2 | SL-3, SL-4, SL-5 : `--fast`, pre-commit, hooks | retour en moins de 10 s à l'écriture et au commit | 2 à 3 j [E] | à mesurer (T-331 : < 5 s par hook) |
| P3 | SL-6, SL-7 : parité structurelle et métrique d'évasions | empêche la dérive, rend l'effet mesurable | 2 j [E] | §4 |
| P4 | SL-8, SL-9, SL-11 | parité devcontainer, politiques sans cluster, nuit | 3 à 4 j [E] | NOT_TESTED |

## 7. Ce qui est prouvé et ce qui ne l'est pas
- **PASS** [M, 2026-11-18, VM cloud x86_64] : `tools/dev/check --static` en 58 s, 15 PASS, 1 FAIL (`leak-guard` sans gitleaks), 9 NOT_TESTED ; `tools/quality/check.py` reproduit les 3 dégradations en 1,4 s ; `ruff check --select F,B,E9` : 0 erreur en 0,02 s sur l'arbre fusionné.
- **PASS** [V] : journaux de la CI de la PR #58, run 44291535887 (jobs `quality`, `quality-coverage`, `platform-render` rouges ; les 12 autres verts).
- **NOT_TESTED** : `check --full` avec tous les outils ; durée de `--fast` ; hooks Claude Code en session cloud ; `pre-commit` (non installé) ; build du devcontainer ; cause exacte de `quality-coverage` (journal tronqué) et de `platform-render` (valeur de test refusée par la garde TLS ; lien avec le solde de `.gitleaksignore` T-450 non établi) ; `kyverno test` sans cluster (la page lue ne le confirme pas) ; sites `pre-commit.com` et GitHub Docs injoignables depuis cette session.
- **[H]** : le taux de PR vertes au premier push s'améliore ; le plancher de 80 % est un objectif, pas une mesure.

## 8. Implémentations publiques consultées (skill `prior-art`)
| Source | Licence | Décision | Pourquoi |
|---|---|---|---|
| Documentation des hooks Claude Code, https://code.claude.com/docs/en/hooks (lue 2026-11-18, partielle) | documentation, lue seulement | adopté (sémantique des codes de sortie) | PostToolUse ne bloque pas ; Stop et PreToolUse bloquent par rc 2 |
| gitleaks `.pre-commit-hooks.yaml`, https://github.com/gitleaks/gitleaks | MIT | adopté (idée : `gitleaks git --pre-commit --redact --staged`) | contrôle d'index sans historique |
| actionlint `.pre-commit-hooks.yaml`, https://github.com/rhysd/actionlint | MIT | adopté (variante `-system`) | utilise le binaire épinglé |
| ruff-pre-commit, https://github.com/astral-sh/ruff-pre-commit | MIT | adapté (hook local, version du dépôt) | une seule version de ruff |
| shellcheck-py `.pre-commit-hooks.yaml`, https://github.com/shellcheck-py/shellcheck-py | MIT | adapté (hook local `-S warning`) | aligne sur `lint-code` |
| kubeconform, https://github.com/yannh/kubeconform | Apache-2.0 | déjà adopté ; `-cache` et `-schema-location` notés | pas de hook officiel pré-commit, appel direct |
| Kyverno CLI `kyverno test`, https://github.com/kyverno/kyverno (doc `kyverno_test.md`) | Apache-2.0 | écarté pour l'instant (SL-9) | absence de cluster non confirmée par la page |
| Dépôt privé de Paul (kube-ops, homelab-infra) : `.justfile` (`check`, `check-affected`), `affected-tests.sh` + `.conf` (sélection par chemins), `run-checks-parallel.mjs`, hook PreToolUse de protection de sortie, `.pre-commit-config.yaml` avec hook `always_run`, outils figés par `mise.lock` | privé, lecture seule ; aucune valeur copiée | adapté (idées seulement) | sélection par chemins, exécution parallèle, une commande de CI, hook de garde |
| `docs/research/CI-SPEED.md` (ce dépôt) | Apache-2.0 | réutilisé | jobs statiques inconditionnels, `skipped` = échec |
| Non lus faute d'accès réseau : pre-commit.com, GitHub Docs (merge queue), docs Dev Containers | — | NOT_TESTED | à relire lors de SL-4 et SL-8 |
