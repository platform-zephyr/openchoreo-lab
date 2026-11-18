---
id: T-479
title: "Statistiques de l'usine par run : tools/factory/stats.py (tours, coût, refus, verdict par modèle et par ticket)"
status: in-progress
phase: P0
adr: [0021]
depends_on: []
class: AUTONOME
velocity: true
lane: factory
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: 86
---
# T-479 — Statistiques de l'usine par run

## Intention
Mesurer avant de changer l'usine (`docs/research/FACTORY-PRIOR-ART.md` R2, idée de `metrics.jsonl` + `factory-stats` du dépôt
AlexPEClub/software-factory, MIT, idée seulement). `stats.py` lit un répertoire de `mission-result.v1`
(`docs/schema/mission-result.v1.json`, artefacts `mission-result-<n>`) et rend, par modèle et par ticket : nombre de runs,
tours (médiane, p90), coût estimé, durée, refus par nom d'outil, statuts et causes d'échec. Version minimale de T-323 (gelé),
sans tableau de bord. Ne remplace pas `ledger.py` (fenêtres de quota).

## Périmètre de fichiers
tools/factory/stats.py, tests/factory/stats_test.py, docs/research/FACTORY-STATS-REPORT-2026-11-18.md

## Critères de fin
- [x] `python3 tools/factory/stats.py --dir <répertoire> [--json] [--since AAAA-MM-JJ]` : sortie Markdown par défaut, JSON avec un champ `schema: factory-stats.v1` — PROUVÉ : PR #90 (agent de l'usine, issue 86, run 44338002716), CLI vérifiée par le coordinateur, 2026-11-18
- [x] tests avec cas négatifs : fichier non JSON, schéma inconnu, champ manquant (ignoré et compté), répertoire vide (code 0, « aucun run »), refus multiples du même outil agrégés — PROUVÉ : `tests/factory/stats_test.py` OK, 2026-11-18
- [x] aucune sortie d'outil, aucun corps de prompt, aucune valeur d'environnement dans la sortie (test) — PROUVÉ : revue de sortie 2026-11-18, partie commande des refus restreinte aux mots minuscules ; `tests/factory/stats_test.py` 12 tests OK
- [x] rapport daté sur les artefacts réels des runs déjà faits (T-304 et suivants) joint à la PR — PROUVÉ : `docs/research/FACTORY-STATS-REPORT-2026-11-18.md` (7 artefacts lus, 5 runs ; comparaison avant/après NOT_PROVEN)
- [x] `tools/dev/check --static --changed` PASS ; cliquet `tools/quality/check.py` PASS — PROUVÉ : cliquet PASS sur `main` après la fusion de la PR #90 ; CI de la PR verte (18 checks)

## Notes
Branchement dans `claude-agent.yml` (job `report`) hors périmètre : PR séparée après T-478 (même fichier). Sert de mesure
avant/après pour T-478 et pour la recommandation R6 (paquet de contexte).

Reste : aucun (comparaison coût/tours avant/après T-466/T-474/T-478 : NOT_PROVEN, échantillon trop petit ; à refaire quand plus de runs existent).
