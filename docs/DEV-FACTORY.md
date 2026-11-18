# Development Factory (minimale)

Séparer le développement du déploiement OKE, sans nouvelle plateforme : Dev Containers standard, worktrees Git,
scripts existants (`tests/*`, `tools/appgen`, `tools/oke`). Outil : `tools/dev/dev`. Garde-fou : `tools/dev/guard-check.sh`.

## Modèle

- **Coordinateur unique** : seul rôle autorisé à utiliser OKE (kubeconfig OKE, gate de Paul). Il ne développe pas en parallèle.
- **3 agents de développement au maximum**, chacun dans son worktree `../wt-<tâche>` (branche `feat/<tâche>` depuis `origin/main`) et son conteneur `oclab-dev-<tâche>`.
- **Un seul propriétaire du k3d partagé** (`openchoreo`) : les agents ne le touchent jamais.
- Les agents font lint, tests unitaires, rendus Helm et vérifications statiques **sans cluster** (`dev test`).
- Chaque tâche : PR, CI verte, sans attendre le coordinateur ; aucun merge automatique.

## Conteneur (`.devcontainer/`)

- `Dockerfile` : base `python:3.12-slim-bookworm` par digest (index multi-arch, arm64), outils par version et sha256.
  Helm, yq, kubeconform, gitleaks, actionlint : mêmes empreintes que `ci.yaml` (vérifié par `tests/dev-factory/run.sh`).
  Utilisateur non-root dont UID/GID = ceux de l'hôte.
- `devcontainer.json` : limites par workspace `--cpus=1 --memory=1g --memory-swap=1g --pids-limit=512`,
  `--cap-drop=ALL`, `no-new-privileges`. Caches en **volumes nommés partagés** : `openchoreo-lab-dev-pip`,
  `openchoreo-lab-dev-helm`, `openchoreo-lab-dev-phaseb` (`~/.cache/openchoreo-lab-phaseb`, sérialisé par `flock`).
- **Jamais montés** : `~/.kube`, `~/.oci`, `~/.cache/oke-access`, `~/.config/gh`, Doppler, AWS, `~/.ssh`, socket Docker.
  Aucune variable sensible ; `containerEnv` ne contient que `DEV_FACTORY=1` et la config `safe.directory`.

- Build périodique (T-472) : `.github/workflows/devcontainer-build.yaml` (`schedule` hebdomadaire + `workflow_dispatch`) construit
  l'image en amd64 et arm64 (runner natif par architecture). Hors `ci-ok` et non requis : un build rouge est un signal, pas un blocage.
  `tests/dev-factory/run.sh` vérifie statiquement cette propriété. Exécution réelle sur GitHub : `NOT_TESTED` tant qu'aucun dispatch n'est daté.

## Reprise après compaction

- Registre hors Git : `~/.local/state/openchoreo-lab-dev/agents.json` (agent-id = tâche, branche, worktree, conteneur).
- `dev status` le recoupe avec `git worktree list`, `docker ps` (label `openchoreo-lab-dev=1`), `git branch` et `gh pr list`.

## Commandes

| Commande | Effet |
|---|---|
| `dev up <tâche>` | worktree + conteneur + garde-fous (conteneur supprimé si KO) |
| `dev exec <tâche> -- <cmd>` | exécute dans le conteneur, ex. `dev exec t -- tools/dev/dev test` |
| `dev test` | alias de `tools/dev/check --static --strict` (T-332) : mêmes contrôles que la CI, une ligne PASS / FAIL / NOT_TESTED par contrôle. Exclut `tests/k3d` (cluster) ; `tools/dev/check --k3d` le documente |
| `dev reset <tâche>` | recrée le conteneur (worktree et caches conservés) |
| `dev destroy <tâche>` | supprime conteneur + worktree **seulement** si propre, sans fichier ignoré, branche suivie et tout poussé ; sinon refus |
| `dev status` | worktrees, conteneurs, branches `feat/*`, PR ouvertes, registre |

Garde-fous de `dev` : refus si le contexte Docker est la VM Colima partagée `openchoreo` (sauf `DEV_ALLOW_SHARED_VM=1`),
refus si le daemon n'est pas ARM64. Le push et l'ouverture de PR se font depuis l'hôte (aucun token dans le conteneur).

## VM cloud des agents (linux x86_64) : outils de contrôle (SL-2, T-454)

La VM cloud n'a pas `helm`, `kubeconform`, `actionlint` ni `gitleaks` : sans eux, neuf contrôles de `dev test` restent `NOT_TESTED`.
`tools/dev/cloud-setup.sh` les installe, avec `shellcheck`, `ruff`, `yq` et `pre-commit`, dans `~/.local/bin` (jamais de sudo).

- **Versions et empreintes** : `tools/dev/toolchain.lock`, clés `<OUTIL>_AMD64_SHA256` (linux-amd64), plus `RUFF_*` et `PRECOMMIT_*`.
  Les empreintes viennent des fichiers de checksums publiés par chaque projet ; shellcheck et le zipapp pre-commit n'en publient pas :
  empreinte calculée sur l'archive officielle (deux téléchargements identiques). Aucun `curl | sh`.
- **Installation** : chaque archive est vérifiée par sha256 avant extraction ; empreinte différente = `FAIL` et rien d'installé.
  Idempotent : un outil déjà à la version épinglée n'est pas retéléchargé. `--only helm,yq` limite aux outils nommés.
  Mesuré le 2026-11-18 sur la VM cloud : 8 outils en 5 s, réseau ouvert.
- **Diagnostic** : `tools/dev/doctor` liste outil par outil `présent` / `écart` (autre version) / `absent` et sort non zéro si un outil
  requis manque (`--strict` : aussi sur un écart). Lecture seule, sans réseau.
- **Contrôle** : `tests/dev-factory/lock-concordance.sh` couvre les clés amd64 (empreinte valide, version présente, lue par
  `cloud-setup.sh`, différente de l'arm64, `RUFF_VERSION` = `ci.yaml`).
- Limite : cible x86_64 seulement (arm64 : `.devcontainer/Dockerfile`) ; la preuve arm64 reste en CI. Le script ne tourne pas à la reprise
  d'une VM inactive et les processus lancés ne survivent pas à son expiration.

**Geste de Paul (T-334, aucune valeur)** : dans l'interface de l'environnement cloud des agents, renseigner comme script de setup
`tools/dev/cloud-setup.sh` (exécuté depuis la racine du dépôt cloné), vérifier que `~/.local/bin` est dans le `PATH` des agents,
puis lancer une session et y exécuter `tools/dev/doctor` (attendu : `RESULT: PASS`). Hôtes à autoriser en sortie pour le script :
`get.helm.sh`, `github.com` et le CDN de téléchargement des releases GitHub.

## Hooks git locaux : pre-commit et pre-push (SL-4, T-459)

`tools/dev/setup` installe, une fois par clone, les hooks du framework `pre-commit` d'après `.pre-commit-config.yaml`
(idempotent ; `--check` vérifie seulement ; il lance ensuite `tools/dev/doctor`). Tous les hooks sont `language: system` :
aucun dépôt distant, aucun réseau, binaires de `toolchain.lock`.

| Étape | Hooks |
|---|---|
| pre-commit (fichiers indexés) | `tools/dev/check --file` (ruff, yamllint, shellcheck, JSON, appgen validate), `gitleaks` sur l'index (`.gitleaks.toml`), `actionlint` si un workflow change, `backlog check` si `backlog/` change, cliquet `quality` si un `.py` de `tools/` ou `tests/` change |
| pre-push | `tools/dev/check --static --changed` |

Un outil absent donne `NOT_TESTED` côté `check` (jamais PASS) : lancer `tools/dev/doctor`. `git commit --no-verify` et `git push --no-verify`
restent refusés par `.claude/settings.json` ; la configuration ne les utilise ni ne les propose.
Preuve : `tests/dev-factory/precommit-test.sh` (dépôt temporaire ; cas négatifs ruff F821, YAML invalide, secret factice, shellcheck ;
setup idempotent ; durée du commit propre). Mesuré le 2026-11-18 sur la VM cloud x86_64 : commit propre en 2,1 s environ (gitleaks inclus).
Limite : le pre-push exécute le périmètre `--changed` ; la CI reste la preuve (`ci-ok`).

## Limites connues

- Le processus Claude Code tourne sur l'hôte, dans le worktree : l'isolation couvre les **commandes** exécutées (`dev exec`), pas l'agent lui-même.
- Le conteneur écrit dans le `.git` commun (monté au même chemin pour que les worktrees fonctionnent).
- Les paquets apt sont épinglés à la version bookworm du moment ; une mise à jour de sécurité peut les rendre introuvables : mettre à jour la PR.
- Les tests `crd-schema` (clone du dépôt OpenChoreo) et `tests/k3d` restent hors `dev test`.
- Pas de build d'image en CI : le job `dev-factory` vérifie les textes (shellcheck, yamllint, JSON, pins, garde-fou négatif).

## Chemin d'évolution (évaluation seulement, rien de déployé)

Une VM dédiée sur Proxmox, ou un poste distant de type Coder, permettraient de sortir la charge de la VM Colima partagée.
À évaluer : coût mémoire/disque, accès réseau aux registres, et séparation des identifiants. Aucune de ces options n'est mise en œuvre.

## Preuves (2026-11-18)

Environnement : Mac arm64, 32 GiB ; VM `openchoreo` (Colima, partagée, 4 vCPU / 8 GiB, non modifiée) ; profil `default` arrêté ; podman machine non touchée.

| Commande | Résultat |
|---|---|
| `docker --context colima-openchoreo system df` (avant build) | Images 8 (2,07 GB, 1,76 GB récupérables), Volumes 8 (10,19 GB), Build cache 115,5 MB |
| `docker info` sur le contexte par défaut | daemon injoignable (profil `default` arrêté) |
| `tests/dev-factory/run.sh` (hôte) | PASS, 0,65 s : garde-fou 13 cas (1 positif, 12 injections refusées), pins 13 contrôles |
| `tools/dev/guard-check.sh` (hôte, non conteneur) | FAIL 9 points attendu : détecte `~/.kube`, `~/.oci`, `~/.config/gh`, `~/.aws`, `SSH_AUTH_SOCK`, etc. |
| `shellcheck -x` tools/dev, tests/dev-factory | PASS |
| Étapes hors réseau de `dev test` lancées sur l'hôte (appgen validate/check/unittest, argo_guard + négatifs, release-history, cell-cpt, yamllint, actionlint, shellcheck tools/oke) | PASS 10/10 (même commandes que le conteneur, pas dans le conteneur) |
| Étapes réseau de `dev test` (charts, security-bundle, kubeconform) et gitleaks | **NON EXÉCUTÉ** (charts à télécharger dans le cache partagé ; gitleaks absent de l'hôte) |
| `actionlint .github/workflows/ci.yaml` | PASS |
| `yamllint -c tools/appgen/yamllint.yaml tools/dev .devcontainer` | PASS |
| `dev up Bad_Name` | refus (nom invalide) |
| `dev up tfact1` sans daemon | refus propre, aucun effet de bord |
| `dev destroy dev-factory` (worktree modifié) | refus |
| `docker build --platform linux/arm64` (image) | **NON EXÉCUTÉ** (voir décision 1) |
| `dev test` dans le conteneur | **NON EXÉCUTÉ** (dépend de l'image) |
| 2 workspaces parallèles, `dev test` chacun | **NON EXÉCUTÉ** (dépend de l'image) |
| RAM / temps par workspace | **NON MESURÉ** |

Incident : une commande de lecture a tiré `alpine:latest` sur la VM `openchoreo`. La commande a été interrompue et aucune image
n'a été ajoutée (compteurs identiques avant/après). Aucun conteneur ni volume créé.

## Décisions requises de Paul

1. Construire l'image : soit autoriser un build ponctuel sur la VM `openchoreo` (2-3 GiB libres, partagée avec le k3d),
   soit démarrer le profil `default` avec l'allocation choisie. Commandes prêtes :
   `colima start default --cpu 4 --memory 12` (ou autre allocation), puis `tools/dev/dev up <t>` avec `DEV_DOCKER_CONTEXT`.
2. Allocation Colima (proposition du mandat : 4 vCPU / 12 Go) : non appliquée ici.
3. Limites par workspace (1 vCPU / 1 Go actuellement) et nombre d'agents simultanés (3 maximum).
4. Push et PR depuis l'hôte (recommandé) ou jeton dédié dans le conteneur (refusé par le mandat).
