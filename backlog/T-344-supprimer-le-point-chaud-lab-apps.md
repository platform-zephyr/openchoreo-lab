---
id: T-344
title: "Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR d'agents"
status: todo
phase: P1
adr: [0001, 0022]
depends_on: [T-061, T-061b, T-062, T-214]
class: REVUE
velocity: true
lane: socle-oke
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-344 — Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR d'agents

## Intention
Une app = un répertoire `apps/<nom>/` sans éditer un fichier partagé : ApplicationSet à générateur Git (sous garde argo_guard). Activer la file de fusion sur main ; workflow de régénération de `generated/` après rebase pour qu'un conflit de génération ne bloque pas un agent.

## Périmètre de fichiers
platform/install/argocd/, .github/workflows/ (régénération), tests/argo-guard/

## Critères de fin
- [ ] deux PR d'apps différentes, ouvertes en parallèle, fusionnent sans conflit (essai daté)
- [ ] argo_guard et ses cas négatifs restent verts (une Application hors périmètre reste refusée)
- [ ] un conflit sur `generated/` est résolu par régénération sans intervention (essai)

## Notes
Zone noyau (platform/install/argocd/, .github/) : Paul approuve. Cohérent avec la décision de consensus « un seul propriétaire par app et environnement ».

Proposé par la recherche `harness` (clé HAR-14) ; intégration 2 du 2026-11-18.
