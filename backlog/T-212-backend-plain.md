---
id: T-212
title: "Bras K du banc A/B : chemin kube-ops reproduit dans un dépôt bac à sable figé (remplace le backend plain)"
status: todo
phase: P1
adr: [0001, 0020, 0025]
depends_on: [T-061, T-061b, T-214, T-485]
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
- [ ] seules différences avec kube-ops listées dans `tests/bench-ab/arm-k/DIFF.md` (cible `lab-k-*`, observation par statut publié, pas de `kubectl-rw`)
- [ ] Applications du bras K rattachées à l'AppProject `lab-k` (créé par T-487, frontière Argo)
- [ ] une app A du bras K Ready avec `app-status.v1` PASS sur k3d (T-486), preuve datée

## Notes
Échec = pas d'app A Ready avec PASS après 3 jours d'agent (ADR-0020 §3). Recadré par ADR-0025 (2026-11-18) : le C5 de la porte compare OpenChoreo au chemin kube-ops reproduit ; plus de backend dans `tools/appgen/`.

Intégration 2 : cible = cluster lab (T-363). Remplacé par ADR-0025 : cible = cluster du banc (MacBook puis OKE).
