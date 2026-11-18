---
id: T-212
title: "Bras K du banc A/B : chemin kube-ops reproduit dans un dépôt bac à sable figé (remplace le backend plain)"
status: todo
phase: P1
adr: [0001, 0020, 0025]
depends_on: [T-061, T-061b, T-214]
class: AUTONOME + MANDAT
velocity: true
lane: moteur-plain
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-212 — Bras K du banc A/B : chemin kube-ops reproduit

## Intention
Le comparateur de la porte n'est plus un backend plain écrit pour l'occasion : kube-ops a déjà un contrat à un fichier (`apps-generated`, chart `platform-app`, `app-status.v1`) et un chemin Kustomize. Reproduire ce chemin, tel quel, dans un dépôt bac à sable privé figé à un SHA, déployé sur le cluster du banc dans les namespaces `lab-k-*` (ADR-0025, `docs/research/POC-OPENCHOREO-STRATEGY.md` §2.2).

## Périmètre de fichiers
tests/bench-ab/arm-k/, dépôt bac à sable du bras K (hors de ce dépôt)

## Critères de fin
- [ ] MANDAT Paul : dépôt privé du bac à sable créé, accès donné à l'App de l'usine
- [ ] bac à sable = kube-ops au SHA noté, réduit aux apps du banc (`it-tools`, `vikunja`, `ntfy`), `AGENTS.md`, skills et chart `platform-app` inchangés ; licence MIT et `NOTICE` vérifiés ; aucun nom d'hôte ni IP
- [ ] livraison = copie de l'ApplicationSet `apps-generated` et de son AppProject de kube-ops, à 3 champs près (dépôt, projet `lab-k`, préfixe `lab-k-`) ; `helm template` du chart `platform-app` OK en CI pour les 3 apps
- [x] seules différences avec kube-ops listées dans `tests/bench-ab/arm-k/DIFF.md` (cible `lab-k-*`, observation par check run publié, pas de `kubectl-rw`, base de M2 sur `lab-pg`) — STATIC, 2026-11-18, kube-ops `ef50472`
- [ ] Applications du bras K rattachées à l'AppProject `lab-k` (créé par T-487, frontière Argo)
- [ ] contenu poussé dans le bac à sable par l'App de l'usine, SHA noté dans `DIFF.md`

## Notes
Échec = pas d'app A Ready avec PASS après 3 jours d'agent (ADR-0020 §3). Recadré par ADR-0025 (2026-11-18) : le C5 de la porte compare OpenChoreo au chemin kube-ops reproduit ; plus de backend dans `tools/appgen/`.

Intégration 2 : cible = cluster lab (T-363). Remplacé par ADR-0025 : cible = cluster du banc (MacBook puis OKE).

Accéléré (arbitrages de Paul n°3, 2026-11-18) : la preuve runtime du bras K (app A Ready, check run `success` sur OKE) passe dans T-486 ; plus de répétition sur k3d. T-485 retiré des dépendances (les 3 apps sont connues).

Arbitrages de Paul du 2026-11-18 (mandat de la session) : apps du banc = `echo-bench` (M1, M4), `miniflux` (M2, provisoire, base sur `lab-pg`), `ntfy` (M3) ; elles remplacent `it-tools` et `vikunja` dans le 2e critère. Cible `lab-k-*`, AppProject `lab-k`, un seul Argo (`lab-argocd`).

État du 2026-11-18 (`tests/bench-ab/arm-k/DIFF.md`) : contenu du bac à sable prêt (kube-ops `ef50472`), commit initial NON poussé (BLOCKED : git refusé par l'isolation de la session, API d'écriture refusée par le proxy). `helm template` PASS pour echo-bench seulement ; miniflux et ntfy passent par le chemin Kustomize. Conflits à arbitrer par Paul : chart inchangé vs `lab-k-*` (namespace `svc-<name>` codé en dur) ; kinds et écritures dans `lab-pg` pour miniflux ; pas de non-prod pour M3. `tests/bench-ab/test_bench_ab.py` attend encore `it-tools`/`vikunja` (T-485).
