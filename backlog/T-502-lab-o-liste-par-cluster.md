---
id: T-502
title: "ApplicationSet lab-o sans exclusions manuelles : générateur Git files sur une liste propre au cluster OKE"
status: in-progress
phase: P1
adr: [0025, 0024]
depends_on: [T-491]
class: REVUE
velocity: false
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-502 — lab-o choisi par cluster, sans exclusions

## Intention
Revue de fidélité n°1 (`docs/research/FIDELITE-JOURNAL.md`, seul verdict HACKY) : `lab-o` choisissait les apps OKE
par 6 `exclude` écrits à la main, tenus par la règle O5 d'`argo_guard`. Toute app non OKE touchait la frontière Argo.
Décision de Paul : « lab-o généré par cluster ». Solution native : générateur Git `files` d'Argo CD sur une liste
versionnée `clusters/oke/lab-o-apps.yaml` (un tableau = un jeu de paramètres par élément, `.app`). Une app k3d ne
touche plus ni la liste ni `platform/`. O5 est réduite à la validation de la liste. Les gardes L1-L4 de `lab-k` et la
frontière du bras K ne changent pas.

## Périmètre de fichiers
platform/install/argocd/apps/lab-apps.yaml, clusters/oke/lab-o-apps.yaml, tools/oke/argo_guard.py, tests/argo-guard/, tools/status/app_status.py (consommateur de la liste, CI), tests/status/test_app_status.py, backlog/T-502-lab-o-liste-par-cluster.md

## Critères de fin
- [x] `lab-apps.yaml` : un générateur `git.files` sur `clusters/oke/lab-o-apps.yaml`, aucun `exclude` — STATIC, 2026-11-19
- [x] Ensemble des fichiers synchronisés par `lab-o` identique avant et après (29 fichiers, 4 apps : echo-demo, ntfy,
  searxng, whoami) ; noms `lab-o-<app>` et chemins source inchangés — STATIC, 2026-11-19
- [x] Cas négatifs dans `tests/argo-guard/` (liste : app k3d, remontée `../`, gabarit, clé en plus, doublon, app sans
  sortie generated/, liste absente ou illisible ; générateur `directories` ou autre fichier) — STATIC, 2026-11-19
- [ ] Preuve OKE après fusion : `lab-o-echo-demo`, `lab-o-ntfy`, `lab-o-searxng`, `lab-o-whoami` seules, Synced/Healthy
  (commandes en lecture seule dans la PR)

## Notes
- Hors périmètre, à reprendre par un ticket de texte : `.agents/skills/add-app/SKILL.md` (§ cluster oke),
  `docs/GOLDEN-PATH-WHOAMI.md` (garde CI), commentaire de `platform/install/values/argocd.yaml` (« hors liste
  d'exclusion »), `docs/research/FIDELITE-JOURNAL.md` (verdict à réévaluer à la revue n°2).
- Étape suivante possible (non faite) : `tools/appgen` écrit lui-même la liste à partir de `cluster: oke` ; la liste
  reste aujourd'hui le geste explicite qui tient echo-bench et miniflux hors d'OKE avant la passe 0.
- Reprise 2026-11-19 (passation vers l'orchestrateur du Mac) :
  - Fait : PR #174, `ci-ok` vert sur 290f136 ; fusion refusée (conflit : `main` a supprimé `tools/status/`, T-507) ;
    `main` fusionnée dans la branche (2cf5806) : suppression acceptée, garde du skill `read-app-status` alignée sur
    la liste OKE. Check local : 21 PASS, 0 FAIL.
  - #174 fusionnée en squash (12e096e) après `ci-ok` sur 2cf5806. Reste : preuve OKE (commandes dans le corps de #174).
  - Commandes : `python3 -I tools/oke/argo_guard.py .` (attendu : 0 écart, lab-o = 4 apps) ; `tests/argo-guard/run.sh`.
  - Pièges : une app OKE nouvelle = une ligne dans `clusters/oke/lab-o-apps.yaml` ; `check-paths.tsv` ne relance pas
    `argo-guard-negative` sur `clusters/*` (suite reprise par T-512).
