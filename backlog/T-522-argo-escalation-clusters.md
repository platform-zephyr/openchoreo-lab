---
id: T-522
title: "argo-escalation : copier clusters/ dans le dépôt de test et rendre un code d'échec sur FAIL"
status: todo
phase: P1
adr: [0004, 0011]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S2
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-522 — argo-escalation : `clusters/` dans le dépôt de test, code d'échec sur FAIL

## Intention
Triage T-514 (#194, preuve STATIC) : depuis T-502 (#174) l'ApplicationSet `lab-o` lit `clusters/oke/lab-o-apps.yaml`. `tests/argo-escalation/run.sh` ne copiait que `platform/`, `generated/` et `apps/` : aucune Application `lab-o-*` n'existait et l'attente de `lab-o-whoami` (180 s) expirait.

## Périmètre de fichiers
tests/argo-escalation/run.sh, backlog/T-522-argo-escalation-clusters.md

## Critères de fin
- [x] `clusters/` copié dans le dépôt de test (et texte du log aligné)
- [x] `tests()` rend un code non nul si `results.tsv` contient un cas FAIL (statut en colonne 3)
- [x] namespace `openchoreo-control-plane` créé dans le cluster jetable (cas P-PLATFORM, hypothèse : prérequis manquant, non vérifiée)
- [ ] run k3d `argo-escalation` après fusion : verdicts réels (dispatch par l'orchestrateur ; P-PLATFORM reste FAIL s'il échoue encore)

## Notes
Preuve : `bash -n` et `tools/dev/check --static` seulement (STATIC). Aucun run k3d lancé ici.
