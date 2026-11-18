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
