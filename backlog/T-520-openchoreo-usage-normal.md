---
id: T-520
title: "OpenChoreo 1.3.3 en usage normal : fonctionnement, déploiement OKE, test de Paul"
status: in-progress
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-opus-5-5
effort: low
routing: R2-texte
github_issue: null
---
# T-520 — OpenChoreo 1.3.3 en usage normal

## Intention
Principe de Paul : natif d'abord, aucune complexité inutile. Décrire l'usage normal d'OpenChoreo 1.3.3 (plans, objets,
parcours développeur et plateforme, identité), le déploiement recommandé sur un cluster OKE et l'écart avec
`tools/oke/install.sh`, puis un test d'usage de 30 à 45 min pour Paul. Lister les simplifications, à décider après le
test. Documentation seulement : aucun développement, aucune écriture cluster.

## Périmètre de fichiers
docs/research/OPENCHOREO-USAGE-NORMAL.md, backlog/T-520-openchoreo-usage-normal.md

## Critères de fin
- [x] Note ≤ 3 pages, français, STE80, chaque affirmation marquée [L], [D] ou [H] avec lien (openchoreo.dev v1.3.x, code `v1.3.3`)
- [x] Fonctionnement, déploiement OKE et écart avec `install.sh`, test de Paul (prérequis et checklist), simplifications S1-S6
- [x] Aucune valeur secrète, OCID, IP ni hôte interne dans la note
- [ ] `tools/dev/check --static --changed` et `python3 tools/backlog/check.py` : verdict reporté dans la PR
- [ ] Test de Paul joué et résultats notés (geste de Paul, après les prérequis P1-P6)

## Notes
Hors périmètre : `tools/appgen/`, `tools/oke/argo_guard*`, ADR, cluster. Les décisions S1-S6 se prennent après le test.
