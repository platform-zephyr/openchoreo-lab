---
id: T-438
title: "Project v2 « Pilote » : vue en lecture du backlog (facultatif)"
status: deferred
phase: P5
adr: [0012]
depends_on: [T-325]
class: AUTONOME + MANDAT
velocity: false
lane: connaissance
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-438 — Project v2 « Pilote » : vue en lecture du backlog (facultatif)

## Intention
Tableau et feuille de route GitHub Projects (gratuit) alimentés depuis backlog/ (étape, couloir, classe, modèle). Git reste la source de vérité ; le Project est un miroir lecture seule régénéré. Paul crée le Project ; l'écriture passe par la session du coordinateur, pas par une App agent.

## Périmètre de fichiers
tools/backlog/, docs/runbooks/github-project.md

## Critères de fin
- [ ] miroir régénérable, supprimable sans perte
- [ ] aucune permission d'écriture sur les Projects pour une App d'agent
- [ ] décision « garder ou supprimer » consignée après le pilote

## Notes
Proposition GH-9 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Ne pas élargir une App pour ce confort. À abandonner si le tableau INDEX.md suffit.

Différé après la porte (règle d'usine : aucun geste de Paul mesuré supprimé ; INDEX.md suffit). À abandonner si le tableau INDEX.md suffit.
