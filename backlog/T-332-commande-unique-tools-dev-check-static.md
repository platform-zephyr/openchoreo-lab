---
id: T-332
title: "Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée"
status: in-progress
phase: P0
adr: [0022]
depends_on: []
class: AUTONOME
velocity: true
lane: dev-factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-332 — Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée

## Intention
Une seule entrée pour la definition of done technique, sans Docker ni cluster pour --static (yamllint, appgen validate/check/unittest, kubeconform, gitleaks, shellcheck, tests unitaires). Un fichier toolchain.lock (versions + sha256) lu par le Dockerfile, ci.yaml et le script de l'environnement cloud.

## Périmètre de fichiers
tools/dev/check, tools/dev/toolchain.lock, tests/dev-factory/

## Critères de fin
- [ ] `tools/dev/check --static` passe sur main, en moins de 3 min, sans Docker (temps daté)
- [x] test de concordance : toolchain.lock = Dockerfile = ci.yaml (cas négatif : une version modifiée fait échouer) — `tests/dev-factory/lock-concordance.sh` + `check-test.sh` : 6 cas négatifs (version lock/Dockerfile/ci.yaml, sha256, ARG hors lock, pip), PASS le 2026-11-18
- [ ] le conteneur de dev, le job CI et la VM cloud appellent la même commande

## Notes
Remplace la dépendance de `dev test` à Colima/Mac. La VM cloud est x86_64, la CI arm64 : --static doit être indépendant de l'architecture.

Proposé par la recherche `harness` (clé HAR-2) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Avancement (2026-11-18, STATIC) :
- Livré : `tools/dev/check` (`--static`, `--k3d`, `--strict`), `tools/dev/toolchain.lock` (21 clés, arm64), `tests/dev-factory/lock-concordance.sh` et `check-test.sh` (34 assertions PASS) ; `tools/dev/dev test` délègue à `check --static --strict` (critère 3, volet conteneur).
- Critère 1 non coché : sur la VM cloud x86_64 sans Docker, `check --static` = 60 s, 13 PASS, 0 FAIL, 12 NOT_TESTED (actionlint, gitleaks, helm, kubeconform absents ; tests/leak-guard, identities, hooks absents du dépôt). Il reste à le passer avec tous les outils installés (CI ou conteneur) pour dater « < 3 min, 0 NOT_TESTED ».
- Critère 3 non coché : reste que le job CI appelle `tools/dev/check --static --strict` et que le script d'environnement cloud (T-334) l'appelle ; `ci.yaml` n'est pas modifié ici (autre agent) et doit lire `toolchain.lock`.
- Empreintes linux-amd64 de kubectl, jq et gh ajoutées à `toolchain.lock` (2026-11-18, STATIC) : `KUBECTL_AMD64_SHA256` (dl.k8s.io, Apache-2.0), `JQ_AMD64_SHA256` (sha256sum.txt de la release jq-1.8.2, MIT), `GH_AMD64_SHA256` (gh_2.104.0_checksums.txt, MIT). Les empreintes arm64 publiées par l'amont égalent celles déjà au lock (recoupement). `cloud-setup.sh` installe désormais kubectl, jq et gh (vérification sha256 avant pose) et le Dockerfile porte les trois `ARG *_AMD64_SHA256` ; `lock-concordance.sh` PASS (34 clés, arm64 et amd64).
- Reste aussi : les contrôles de T-303, T-306, T-330, T-331 s'activent seuls (NOT_TESTED tant que leur script manque).

Reste (2026-11-18) : `tools/dev/check --static --jobs 4` dure 41 s (116 s en série) avec les outils de `cloud-setup.sh` ; 3 NOT_TESTED restent (`guard-check` hors conteneur de dev, étapes `identities` et `hooks` dont les scripts sont livrés par T-331). Critère 3 (même commande dans la CI et la VM cloud) : porté par T-460 (parité `ci.yaml` ↔ `check`).
