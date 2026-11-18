---
id: T-421
title: "Indicateurs de maintenabilité `quality.v1` dans la data platform et le rapport de l'usine"
status: in-progress
phase: P1
adr: [0019]
depends_on: [T-414]
class: AUTONOME
velocity: false
lane: observabilité
stage: S3
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-421 — Indicateurs de maintenabilité `quality.v1` dans la data platform et le rapport de l'usine

## Intention
Historiser par merge : cc_max, cc_p95, fonctions > 15, fichiers > 400 l, erreurs ruff et mypy, couverture, shellcheck, % docstrings. Relier aux indicateurs de livraison (taux de revert, itérations CI par PR, délai) par fichier touché.

## Périmètre de fichiers
docs/schema/quality.v1.json, tools/quality/, docs/state/

## Critères de fin
- [ ] schéma JSON versionné, une ligne par merge sur `main`, aucune valeur secrète
- [ ] le rapport hebdomadaire T-323 contient une section qualité (tendance 4 semaines)

## Notes
Proposition QA-11 (backlog/proposals/quality.yaml), intégrée (intégration 5, 2026-11-18). Hypothèse [H] à tester : plus de complexité = plus d'itérations CI. Un indicateur informe, il ne bloque pas (seuls cliquet et seuils durs bloquent).

Le rapport de l'usine T-323 est différé après la porte : la section qualité de ce rapport s'ajoutera quand il existera ; les lignes `quality.v1` sont écrites dès ce ticket.

## Avancement (2026-11-18)
Fait : `docs/schema/quality.v1.json` (versionné, champs fermés, aucune valeur secrète) ; `tools/quality/history.py` (ajoute shellcheck, % docstrings et fichiers touchés, valide, refuse une ligne invalide, ignore un commit déjà présent) ; première ligne dans `docs/state/quality-history.jsonl` ; `tests/quality/test_history.py` (cas négatifs). Commande : `python3 tools/quality/check.py --output q.json && python3 tools/quality/history.py --report q.json`.

Reste :
- écrire la ligne automatiquement à chaque merge sur `main` (étape de workflow : `ci.yaml` est hors périmètre de cette session ; ticket de suite côté `.github/`) ;
- relier aux indicateurs de livraison (revert, itérations CI par PR) : `touched_files` est prêt, la jointure attend T-323 ;
- section qualité (tendance 4 semaines) du rapport hebdomadaire T-323, différé après la porte.
