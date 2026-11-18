---
id: T-477
title: "Étude : art antérieur des usines d'agents à réutiliser (FACTORY-PRIOR-ART)"
status: done
phase: P0
adr: [0021, 0024]
depends_on: []
class: AUTONOME
velocity: true
lane: factory
stage: S1
model: claude-opus-5-5
effort: high
routing: R2-texte
github_issue: null
---
# T-477 — Étude : art antérieur des usines d'agents à réutiliser

## Intention
Accélérer l'usine d'agents en réutilisant l'existant plutôt qu'en le reconstruisant : lire les « software factories » publiques,
les listes de référence et la documentation de Claude Code, puis rendre un verdict adopter / adapter / ignorer, une matrice
douleur → solution, des recommandations classées et les tickets des trois meilleures.

## Périmètre de fichiers
docs/research/FACTORY-PRIOR-ART.md, backlog/T-477-etude-art-anterieur-usine.md, backlog/T-478-plafonds-natifs-executant.md, backlog/T-479-statistiques-usine-par-run.md, backlog/T-480-garde-taille-tickets.md, backlog/STATUS.md

## Critères de fin
- [x] `docs/research/FACTORY-PRIOR-ART.md` (< 250 lignes, conclusion d'abord) : verdict par source avec licence et date, matrice douleur → solution, patterns avec effort S/M/L, recommandations classées, acquis à ne pas refaire, risques, sources (2026-11-18)
- [x] tickets des trois meilleures recommandations créés (T-478, T-479, T-480), périmètres disjoints entre eux
- [x] `python3 tools/backlog/check.py` : 0 erreur ; `backlog/STATUS.md` régénéré (2026-11-18)

## Notes
Sources lues le 2026-11-18 par WebFetch/WebSearch (liste au §8 de l'étude). NOT_TESTED : awesomeclaude.ai (hôte hors liste
réseau de la session), README du plugin `ralph-wiggum` (404), code des dépôts (clone et archives refusés dans cette session ;
README seulement), licence de SSW factory-builder. Le gist « Maciejd » n'existe pas sous ce nom (gists Java de 2014) ; le gist
pertinent est celui de Maciejdziuba (sans licence : idée seulement). Aucune ligne de code tiers copiée.
