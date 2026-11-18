---
id: T-301
title: "Réécriture de l'historique et purge des refs de PR (mailmap, détail de faille, identifiants)"
status: todo
phase: P0
adr: [0002]
depends_on: [T-300, T-302, T-303]
class: MANDAT
velocity: false
lane: gouvernance
stage: S0
model: claude-opus-5-5
effort: high
routing: R01-noyau-securite
github_issue: null
---
# T-301 — Réécriture de l'historique et purge des refs de PR (mailmap, détail de faille, identifiants)

## Intention
Retirer de l'historique le détail de faille, l'e-mail professionnel (mailmap) et les identifiants d'infrastructure ; demander au support GitHub la purge des refs `refs/pull/*` et des vues en cache ; rebaser ou recréer les branches ouvertes.

## Périmètre de fichiers
historique git de toutes les branches

## Critères de fin
- [ ] miroir de sauvegarde privé avant réécriture
- [ ] gitleaks + règles maison : 0 constat sur tout l'historique réécrit
- [ ] demande de purge au support GitHub envoyée et confirmée
- [ ] branches ouvertes recréées, PR rouvertes

## Notes
Commandes `git filter-repo` préparées dans le rapport d'audit (hors dépôt). Toute PR ou fork existant garde l'ancien historique : à vérifier.

Proposé par la recherche `sensitive` (clé SEC-2) ; intégration 2 du 2026-11-18.

À faire AVANT le pilote 24 h (T-322) et le dispatcher planifié (T-314) : chaque branche ouverte serait à recréer après la réécriture.
