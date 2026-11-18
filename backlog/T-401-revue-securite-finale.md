---
id: T-401
title: "Revue de sécurité finale de la plateforme (prérequis de « plateforme finie »)"
status: todo
phase: P4
adr: [0002, 0006, 0021, 0022]
depends_on: [T-007, T-215, T-400, T-402]
class: MANDAT
velocity: false
lane: gouvernance
stage: FINAL
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-401 — Revue de sécurité finale de la plateforme (prérequis de « plateforme finie »)

## Intention
Vérifier, avant de déclarer la plateforme finie, que la sécurité finale est tenue : identité d'usine, ruleset sans contournement, noyau CODEOWNERS testé, exécutant aux outils étroits, historique propre.

## Périmètre de fichiers
docs/review/SECURITY-FINAL.md, .github/workflows/claude-agent.yml, .claude/

## Critères de fin
- [ ] rapport daté par une revue adverse (session distincte, Opus) : identité d'usine, ruleset, noyau, secrets, exposition, admission ; chaque point PASS/FAIL avec preuve
- [ ] garde T-303 verte sur tout l'historique (après T-301 si Paul l'a fait)
- [ ] Paul déclare « plateforme finie » dans STATE.md et MISSION.md, ou liste les écarts restants
- [ ] (repris de T-313) `show_full_output` absent ; aucun secret hors jeton Claude ; `--permission-mode auto --permission-prompts none` (ou dontAsk + allowedTools) vérifié
- [ ] (repris de T-313) une PR du noyau lancée par l'exécutant reste non fusionnable
- [ ] (repris de T-313) (repris de HAR-3) actionlint vert ; le workflow ne contient plus `python3:*` ni `git:*`
- [ ] (repris de T-313) (repris de HAR-3) une commande hors liste (ex. curl) est refusée dans le run, visible dans permission_denials

## Notes
Arbitrage 4 (consensus n°2 et arbitrages de Paul, 2026-11-18) : seule la sécurité finale compte ; ce ticket est la dernière porte avant « plateforme finie ».
