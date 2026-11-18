---
id: T-325
title: "Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT"
status: todo
phase: P0
adr: [0013, 0021]
depends_on: [T-008]
class: AUTONOME
velocity: true
lane: connaissance
stage: S0
model: claude-sonnet-5-5
effort: medium
routing: R10-code-simple
github_issue: null
---
# T-325 — Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT

## Intention
Produire pour chaque étape la liste ordonnée des gestes exacts (noms de secrets, pas de valeurs ; liens ; durée) et un script interactif qui vérifie chaque effet en lecture seule (secret présent, label, App installée, runner enregistré).

## Périmètre de fichiers
tools/factory/gestes.sh, docs/GESTES-PAUL.md (généré)

## Critères de fin
- [ ] sortie pour S0 : toutes les demandes des tickets S0 en MANDAT, ordonnées, ≤ 30 min estimées
- [ ] aucune valeur de secret ni sortie sensible affichée ou écrite (test gitleaks)
- [ ] le script marque chaque geste PASS/FAIL/NOT_TESTED avec horodatage

## Notes
Le geste est fait par Paul ; le script ne crée aucun accès (platform-guardrails §2). Réduit le temps de séance, pas les droits.

Proposé par la recherche `factory` (clé FAC-16) ; intégration 2 du 2026-11-18.
