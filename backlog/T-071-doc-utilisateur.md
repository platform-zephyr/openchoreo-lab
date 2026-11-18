---
id: T-071
title: "Guide utilisateur : demander, suivre, annuler, déposer un secret"
status: todo
phase: P2
adr: [0013, 0014]
depends_on: [T-023, T-043, T-061, T-061b]
class: AUTONOME
velocity: false
lane: intention
stage: I2
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-071 — Guide utilisateur : demander, suivre, annuler, déposer un secret

## Intention
Ce qu'un humain doit savoir pour parler à la plateforme, en une page.

## Périmètre de fichiers
docs/USER-GUIDE.md

## Critères de fin
- [ ] une page, exemples de phrases
- [ ] dépôt d'un secret `provided` expliqué
- [ ] lecture d'un `app-status` expliquée

## Notes
Routage R2 (ADR-0023) : Haiku `medium`, revue Sonnet en check requis (2 refus → Sonnet) ; ne touche ni l'en-tête du ticket ni backlog/proposals/. Le dispatcher relance en Sonnet si le diff réel sort du périmètre texte.
