---
id: T-454
title: "Outils de contrôle dans la VM cloud : cloud-setup, doctor, empreintes amd64 (SL-2, réalise T-334)"
status: done
phase: P0
adr: [0022]
depends_on: [T-332]
class: AUTONOME
velocity: true
lane: agents-harness
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-454 — Outils de contrôle dans la VM cloud : cloud-setup, doctor, empreintes amd64 (SL-2, réalise T-334)

## Intention
Les agents de la VM cloud (linux x86_64) n'ont ni `helm`, ni `kubeconform`, ni `actionlint`, ni `gitleaks` : 9 contrôles de `tools/dev/check --static` restent `NOT_TESTED`. Fournir ces outils, plus `shellcheck`, `ruff`, `yq` et `pre-commit`, aux versions épinglées : empreintes sha256 linux-amd64 dans `toolchain.lock`, script d'installation idempotent dans un dossier utilisateur, commande `doctor` qui dit outil par outil ce qui manque. Réalise la part « script d'installation » de T-334 (SL-2 de `docs/research/SHIFT-LEFT-DEV-ENV.md`) ; la création de l'environnement reste un geste de Paul.

## Périmètre de fichiers
tools/dev/toolchain.lock, tools/dev/cloud-setup.sh, tools/dev/doctor, tests/dev-factory/, docs/DEV-FACTORY.md

## Critères de fin
- [x] `toolchain.lock` porte une empreinte linux-amd64 par outil, relevée sur le fichier de checksums publié par le projet (ou calculée sur l'archive officielle quand le projet n'en publie pas : shellcheck, pre-commit, deux téléchargements identiques) ; sources écrites dans l'en-tête du lock — preuve : `tests/dev-factory/lock-concordance.sh` PASS, 2026-11-18
- [x] `tools/dev/cloud-setup.sh` installe les 8 outils dans `~/.local/bin`, vérifie chaque sha256 avant extraction, sans `curl | sh` ni sudo ; idempotent — preuve : VM cloud x86_64, 8 PASS en 5 s, 2e passage « déjà à la version épinglée », cas négatif (empreinte altérée) : FAIL et rien installé, 2026-11-18
- [x] `tools/dev/doctor` liste outil par outil présent / écart / absent avec la version et sort non zéro si un outil requis manque — preuve : `tests/dev-factory/check-test.sh` PASS (4 cas doctor), exécution réelle avant (5 absents, rc 1) et après (RESULT PASS), 2026-11-18
- [x] `tests/dev-factory/lock-concordance.sh` couvre les nouvelles clés (6 cas négatifs ajoutés à `check-test.sh`) — preuve : CHECK-TEST PASS, 2026-11-18
- [x] shellcheck vert sur les trois scripts — preuve : étape `shellcheck` de `tools/dev/check --static`, 2026-11-18
- [x] `docs/DEV-FACTORY.md` documente le branchement de `cloud-setup.sh` comme script de setup de l'environnement cloud (geste de Paul, sans valeur)
- [x] après `cloud-setup.sh`, `tools/dev/check --static` n'a plus aucun `NOT_TESTED` pour outil absent — preuve : VM cloud x86_64, NOT_TESTED 9 → 3 (restent : `guard-check` hors conteneur, `identities` et `hooks` absents du dépôt), 2026-11-18

## Notes
Limites : la VM est x86_64 ; les empreintes arm64 (conteneur, CI) restent celles de `toolchain.lock` et `ci.yaml`, preuve arm64 en CI. `ruff` et `pre-commit` ne figurent pas dans le Dockerfile (hors périmètre) : `RUFF_VERSION` est tenu égal à `ci.yaml`. Le script de setup ne tourne pas à la reprise d'une VM inactive.

Constat hors périmètre : avec `gitleaks` installé, l'étape `gitleaks` de `check --static` passe de NOT_TESTED à FAIL (208 emplacements) car elle lit `.gitleaks.toml` du dépôt (règles `lab-*`) alors que la CI utilise la config par défaut (`useDefault`, 0 fuite en local) ; dette de T-450 ou ajustement de `tools/dev/check` (autre agent).

Le reste de T-334 (liste d'hôtes autorisés, variables de délai, `docs/AGENT-ENVIRONMENTS.md`, session de preuve) n'est pas fait ici.
