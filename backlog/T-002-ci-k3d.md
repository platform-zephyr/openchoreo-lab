---
id: T-002
title: "CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue"
status: in-progress
phase: P0
adr: [0002, 0004]
depends_on: []
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-002 — CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue

## Intention
Rendre la CI k3d fiable : c'est le contrôle compensatoire de l'autonomie sur `platform/` (ADR-0002 §4).

## Périmètre de fichiers
.github/workflows/k3d-integration.yml, tools/k3d/

## Critères de fin
- [x] gitops-k3d gardé en échec connu, pas retiré (matrice `known_fail`, STATIC : actionlint OK ; 2026-11-18)
- [x] tests AUD : audit activé ou NOT_TESTED, jamais PASS (sonde d'audit + réétiquetage `results.tsv`, STATIC : actionlint OK, awk simulé ; comportement réel NOT_TESTED tant qu'aucun run)
- [x] limite « chart sans bundle » écrite (workflow, `ci-bootstrap.sh`, `docs/CI-K3D.md`, résumé de job ; à reprendre dans la description de la PR)
- [ ] suites vap, k3d, argo-escalation vertes

## Notes
Revue de la PR #36 faite le 2026-11-18 (4 points).

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Reste : critère 4 exige un run GitHub réel (NOT_TESTED, aucun run possible depuis cette session). `development` : le bootstrap ne l'invente plus si `platform/` le fournit (STATIC, yq 4.54.3 testé avec un faux manifeste). `docs/research/GITHUB-CONFIG.md` est absent du dépôt : la règle « pas de merge_group » est consignée dans le workflow et `docs/CI-K3D.md`.

Décision de Paul (2026-11-18, D-3) : ce ticket se ferme par un lancement manuel vert de `k3d-integration` sur `main` après les corrections T-456 à T-458, pas par un run sur PR.

Décision de Paul (2026-11-18, D-3) déjà notée ci-dessus. Corrections préalables : T-456 (clé ESO, défaut réel de l'archétype B), T-457 (B-09 en KNOWN_FAIL au niveau du cas), T-458 (ancre de gitops-k3d). Fermeture : lancement manuel vert de `k3d-integration` sur `main` (`gh workflow run k3d-integration.yml`). Les suites k3d ne tournent plus automatiquement.
