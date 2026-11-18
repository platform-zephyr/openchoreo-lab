---
id: T-435
title: "Check k3d requis : déclencheur merge_group et k3d-ok dans le ruleset"
status: todo
phase: P0
adr: [0002, 0004]
depends_on: [T-002, T-430]
class: REVUE
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-435 — Check k3d requis : déclencheur merge_group et k3d-ok dans le ruleset

## Intention
Une PR qui touche platform/ doit avoir la CI k3d verte (ADR-0002 §4). Ajouter merge_group au workflow k3d (sinon le check requis ne se publie jamais dans la file) puis requérir k3d-ok ; la suite gitops-k3d reste KNOWN_FAIL non bloquante.

## Périmètre de fichiers
.github/workflows/k3d-integration.yml, .github/rulesets/, docs/CI-K3D.md

## Critères de fin
- [ ] k3d-integration.yml déclenché par merge_group ; k3d-ok vert quand la porte (gate) dit « non lancé »
- [ ] ruleset : k3d-ok requis, ci-ok inchangé
- [ ] essai daté : une PR platform/ rouge est retirée de la file ; une PR apps/ passe sans suite k3d

## Notes
Proposition GH-6 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Variante : ajouter k3d-ok au needs de ci-ok (docs/CI-K3D.md §4). Choisir une seule voie. Coût : minutes de runner ARM gratuites en dépôt public.

T-400 (FINAL0) requiert `k3d-ok` dans `main-final.json` : T-400 dépend de ce ticket.
