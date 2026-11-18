---
id: T-432
title: "SECURITY.md et politique de signalement privé"
status: todo
phase: P0
adr: [0006]
depends_on: [T-431]
class: AUTONOME
velocity: false
lane: gouvernance
stage: S0
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-432 — SECURITY.md et politique de signalement privé

## Intention
Dire comment signaler une faille (bouton privé de l'onglet Security, jamais une issue publique), le périmètre, aucun secret dans un signalement, le délai de première réponse tenu par Paul.

## Périmètre de fichiers
SECURITY.md

## Critères de fin
- [ ] SECURITY.md à la racine, reconnu par GitHub (onglet Security)
- [ ] aucune adresse e-mail personnelle ni identifiant interne (garde T-303 verte)
- [ ] relecture Sonnet

## Notes
Proposition GH-3 (backlog/proposals/github.yaml), intégrée (intégration 5, 2026-11-18). Texte hors noyau : haiku puis revue Sonnet (ADR-0023). Le signalement privé doit être activé par GH-2 avant la fusion.

Aucun SECURITY.md n'existe aujourd'hui : pas de doublon. Le texte peut être écrit avant T-431, la fusion attend l'activation du signalement privé.

Routage R2 (ADR-0023) : Haiku `medium`, revue Sonnet en check requis (2 refus → Sonnet) ; ne touche ni l'en-tête du ticket ni backlog/proposals/. Le dispatcher relance en Sonnet si le diff réel sort du périmètre texte.
