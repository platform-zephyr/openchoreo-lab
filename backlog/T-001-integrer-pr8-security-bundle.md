---
id: T-001
title: "Fusionner la PR #8 (installation fail-closed avec le security bundle)"
status: todo
phase: P0
adr: [0002]
depends_on: []
class: REVUE
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-001 — Fusionner la PR #8 (installation fail-closed avec le security bundle)

## Intention
Débloquer `main` : intégrer la remédiation et l'installation fail-closed (STATE.md §6.1), diff public neutre.

## Périmètre de fichiers
tools/oke/, security/, docs/SECURITY-BUNDLE.md, tests/security-bundle/, STATE.md (critère « STATE.md à jour »)

## Critères de fin
- [ ] `ci-ok` vert sur la PR #8
- [ ] grep des mots sensibles vide sur le diff public
- [ ] PR fusionnée (squash), STATE.md à jour

## Notes
Coordinateur. Prérequis de tout ce qui installe sur OKE.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).
