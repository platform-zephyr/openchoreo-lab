---
id: T-484
title: "Plancher de couverture : viser tools/appgen/appgenlib/ au lieu de la façade appgen.py"
status: todo
phase: P0
adr: [0024]
depends_on: [T-214]
class: REVUE
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-484 — Plancher de couverture d'appgen sur le paquet

## Intention
Depuis T-214, `tools/appgen/appgen.py` n'est plus qu'une façade (couverte à 100 %, bloc `__main__` exclu) ; le plancher de 85 % de `tools/quality/check.py` (`APPGEN`) ne mesure donc plus le code d'appgen. Seule la couverture du diff (80 %) reste active. Faire viser `tools/appgen/appgenlib/` au plancher, sans l'abaisser.

## Périmètre de fichiers
tools/quality/check.py, tests/quality/

## Critères de fin
- [ ] `APPGEN` désigne `tools/appgen/appgenlib/` avec un plancher d'au moins 85 % (couverture actuelle du paquet : 96,5 %) ; test : un paquet non couvert fait échouer le plancher
- [ ] le cliquet `python3 tools/quality/check.py` reste PASS
- [ ] `tools/dev/check --static --changed` : verdict reporté dans la PR

## Notes
Trouvé par l'agent de T-214 (2026-11-18). `tools/quality/` est dans CODEOWNERS : classe REVUE.
