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
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-001 — Fusionner la PR #8 (installation fail-closed avec le security bundle)

## Intention
Débloquer `main` : intégrer la remédiation et l'installation fail-closed (STATE.md §6.1), diff public neutre.

## Périmètre de fichiers
tools/oke/, security/, docs/SECURITY-BUNDLE.md, tests/security-bundle/

## Critères de fin
- [ ] `ci-ok` vert sur la PR #8
- [ ] grep des mots sensibles vide sur le diff public
- [ ] PR fusionnée (squash), STATE.md à jour

## Notes
Coordinateur. Prérequis de tout ce qui installe sur OKE.
