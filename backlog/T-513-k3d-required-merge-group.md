---
id: T-513
title: "`K3D_REQUIRED` : les runs `merge_group` ont les suites `skipped`, donc fusion ne prouve pas k3d"
status: todo
phase: P1
adr: [0004, 0011]
depends_on: []
class: REVUE
velocity: false
lane: ci
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-513 — `K3D_REQUIRED` : les runs `merge_group` ont les suites `skipped`, donc fusion ne prouve pas k3d

## Intention
`k3d-integration.yml` ne lance les suites dans la file de fusion que si la variable de dépôt `K3D_REQUIRED` vaut `true` (mode dev : non posée). Les runs `merge_group` ont donc les suites `skipped` et `k3d-ok` vert sans suite : une PR fusionnée n'est PAS une preuve k3d. Proposer la pose de la variable, mesurer le coût CI et décider avec Paul.

## Périmètre de fichiers
docs/CI-K3D.md, .github/workflows/k3d-integration.yml, backlog/evidence/T-513-*.md

## Critères de fin
- [ ] constat daté : liste des derniers runs `merge_group` de `k3d-integration` avec l'état des suites (`skipped` ou lancées), preuve dans `backlog/evidence/`
- [ ] coût mesuré : durée et minutes CI d'un run complet des suites sur main, et fréquence des PR qui touchent `platform/`, `tools/{oke,k3d,appgen}/`, `tests/{k3d,vap,argo-escalation,gitops-k3d}/`
- [ ] proposition écrite dans `docs/CI-K3D.md` : poser `K3D_REQUIRED=true` maintenant, à FINAL0 (T-435, T-400) ou jamais, avec le coût ; si « maintenant », modification du workflow en PR REVUE ; Paul pose la variable (geste humain)

## Notes
Classe REVUE : `.github/` est dans CODEOWNERS (noyau, Opus). L'écriture de la variable de dépôt est un geste de Paul ; l'agent ne la pose pas. Jusqu'à la décision, toute PR sur ces chemins porte le reçu de `tools/dev/check` et ne prétend pas à une preuve k3d.
