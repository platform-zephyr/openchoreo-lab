---
id: T-512
title: "Alignements textuels laissés par T-502 : skill add-app, golden path whoami, commentaire argocd, déclencheur argo-guard-negative"
status: todo
phase: P1
adr: [0025, 0024]
depends_on: []
class: AUTONOME
velocity: false
lane: documentation
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-512 — Alignements textuels laissés par T-502 : skill add-app, golden path whoami, commentaire argocd, déclencheur argo-guard-negative

## Intention
T-502 (couloir `lab-o`) a changé le comportement de cluster `oke` ; des textes et une règle de déclenchement locale n'ont pas suivi. Aligner ces 4 éléments, sans code applicatif.

## Périmètre de fichiers
.agents/skills/add-app/SKILL.md, docs/GOLDEN-PATH-WHOAMI.md, platform/install/values/argocd.yaml, tools/dev/check-paths.tsv

## Critères de fin
- [ ] `.agents/skills/add-app/SKILL.md` § cluster `oke` décrit le comportement réel après T-502 (relire le diff de T-502, ne rien supposer)
- [ ] `docs/GOLDEN-PATH-WHOAMI.md` cohérent avec ce comportement ; commentaire de `platform/install/values/argocd.yaml` corrigé (commentaire seulement, aucune valeur changée)
- [ ] `tools/dev/check-paths.tsv` : un changement sous `clusters/*` déclenche `argo-guard-negative` ; `tools/dev/check --static --changed` le montre (reçu dans la PR)

## Notes
À lancer après la fusion de T-502 (propriétaire du couloir `lab-o`) : ne pas éditer ces fichiers pendant que T-502 est ouvert. Un changement de `platform/install/values/argocd.yaml` ne doit pas toucher la quota ni la configuration des notifications.
