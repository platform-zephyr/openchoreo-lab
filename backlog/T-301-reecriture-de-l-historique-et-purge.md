---
id: T-301
title: "Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique)"
status: todo
phase: P0
adr: [0002]
depends_on: [T-302, T-303]
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: human
effort: none
routing: R0-geste-humain
github_issue: null
---
# T-301 — Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique)

## Intention
Paul réécrit lui-même l'historique (mailmap, détail sensible, identifiants d'infrastructure) avec un agent Claude local, au moment qu'il choisit. Pas de dépôt privé, pas de demande de purge du cache GitHub. Aucun ticket n'attend ce geste.

## Périmètre de fichiers
historique git de toutes les branches

## Critères de fin
- [ ] miroir de sauvegarde privé avant réécriture
- [ ] garde T-303 : 0 constat sur tout l'historique réécrit
- [ ] branches ouvertes au moment de la réécriture rebasées ou recréées, PR rouvertes

## Notes
Proposé par la recherche `sensitive` (clé SEC-2) ; intégration 2 du 2026-11-18. Commandes `git filter-repo` préparées dans le rapport d'audit (hors dépôt).

Recadré (consensus n°2 et arbitrages de Paul, 2026-11-18) : geste de Paul (arbitrage 1), hors chemin critique ; le pilote (T-322) et le cron (T-314) ne l'attendent plus. Conseil : choisir un moment sans PR d'agent ouverte. Copies déjà faites (forks, archives publiques) hors de portée : prévenir l'amont reste une question à Paul.
