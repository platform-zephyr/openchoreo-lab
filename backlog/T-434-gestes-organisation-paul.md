---
id: T-434
title: "Gestes d'organisation de Paul : 2FA, permissions de base, création de dépôts, PAT, Apps tierces, Actions"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-434 — Gestes d'organisation de Paul : 2FA, permissions de base, création de dépôts, PAT, Apps tierces, Actions

## Intention
Une séance d'environ 20 minutes, une action par ligne : 2FA obligatoire, permission de base « aucune », création de dépôts interdite, jetons fins avec approbation et durée 30 jours, classiques restreints, accès tiers restreint, politiques Actions de l'organisation. Chaque réglage a sa commande de lecture (gh api) pour la preuve.

## Périmètre de fichiers
docs/runbooks/github-org-paul.md

## Critères de fin
- [ ] runbook rédigé, une action par ligne, sans valeur secrète
- [ ] preuve datée de chaque réglage par lecture API (2FA, base permission, repo creation, PAT policy), 2FA lue dans l'interface car l'API est en lecture seule
- [ ] chaque geste est listé dans `docs/GESTES-PAUL.md` quand T-325 l'aura généré (jusque-là : dans le runbook)

## Notes
Proposition GH-5 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Réglages impossibles à écrire par l'API (2FA) ou sans effet d'un agent. Aucun agent n'a de droit d'organisation. Rouvrir la question des organisations Free uniquement si une fonction « NON » du tableau devient nécessaire.

Routage R2 (ADR-0023) : Haiku `medium`, revue Sonnet en check requis (2 refus → Sonnet) ; ne touche ni l'en-tête du ticket ni backlog/proposals/. Le dispatcher relance en Sonnet si le diff réel sort du périmètre texte.
