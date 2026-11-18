---
id: T-210
title: "Dispatcher (cerveau) : next.py et admission — prêts, classe recalculée, couloirs, ressources exclusives, chevauchement de périmètres"
status: todo
phase: P0
adr: [0002, 0012, 0013]
depends_on: [T-007, T-008, T-061, T-215]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-210 — Dispatcher (cerveau) : next.py et admission — prêts, classe recalculée, couloirs, ressources exclusives, chevauchement de périmètres

## Intention
Calculer les tickets prêts (dépendances done, étape ouverte, aucun geste humain en attente) puis l'admission : au plus 2 par couloir, 1 sur contrat-appgen avant T-214, exclusive_resources libres, aucun chevauchement de `scope` avec une PR ouverte, budget du gouverneur. Un ticket n'est proposé que si les globs de son périmètre ne recoupent ni un ticket `in-progress`, ni une PR ouverte, ni une `exclusive_resources` (HAR-5).

## Périmètre de fichiers
tools/backlog/next.py, tools/backlog/admission.py, tests/backlog/

## Critères de fin
- [ ] next.py liste prêts et débloqués, sortie JSON stable (`ready.v1`)
- [ ] classe recalculée depuis les chemins touchés, jamais lue de l'en-tête ; un chemin du noyau force REVUE (test)
- [ ] tests : deux tickets du même couloir, deux scopes qui se chevauchent, une ressource exclusive occupée : un seul est admis
- [ ] test : deux tickets aux périmètres recoupés ne sont jamais proposés ensemble
- [ ] test : périmètres disjoints dans un même couloir sont proposés ensemble
- [ ] plafond global 4 au départ (relevé par T-322), 2 par couloir, 1 sur contrat-appgen avant T-214 ; contrat de mission d'Atlas (max_attempts 2)
- [ ] l'admission lit le gouverneur de quota (T-311) quand il existe : refus au-delà du seuil (test hors ligne)
- [ ] le modèle et l'effort de chaque ticket admis viennent de route.py (T-382) ou, à défaut, de l'en-tête

## Notes
Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.

Intégration 2 : absorbe FAC-3 et HAR-5. Le lancement (workflow_dispatch, preuve de 3 PR parallèles) passe à T-313.
