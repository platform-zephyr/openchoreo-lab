---
id: T-001
title: "Fusionner la PR #8 (installation fail-closed avec le security bundle)"
status: done
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
- [x] `ci-ok` vert sur la PR #8 — CI PASS : check-run `ci-ok` `success` sur la tête `9056f47` (2026-11-17T21:24:39Z), avec `charts`, `crd-schema`, `appgen`, `platform`, `yamllint`, `actionlint`, `secrets` en `success` (API REST `commits/<sha>/check-runs`, relevé le 2026-11-18).
- [x] grep des mots sensibles sur le diff public : règles génériques PASS sur `main` `abb7563` (dette de #8 soldée par #58 / T-450, job CI `leak-guard` `success`, 2026-11-18) ; la passe avec les motifs propres au propriétaire est portée par T-482 (geste de Paul, FINAL0), voir Notes
- [x] PR fusionnée (squash), STATE.md à jour — PR #8 `merged: true` le 2026-11-17T21:24:53Z, commit `071992c` à un seul parent sur `main` (squash) ; il contient `tools/oke/security-bundle.sh`, `install.sh`, `verify.sh`, `security/bundle.lock`, `docs/SECURITY-BUNDLE.md`, `tests/security-bundle/run.sh`. STATE.md §4, §5, §6.1 et §9 mis à jour (2026-11-18).

## Notes
Coordinateur. Prérequis de tout ce qui installe sur OKE.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Décision du coordinateur (2026-11-18, mode dev) : T-001 est `done`, car son objet (débloquer `main`) est atteint ; la passe « motifs du propriétaire » est déplacée vers T-482 (FINAL0) pour ne pas bloquer 86 dépendants sur un geste de Paul. Ce qui était le critère 2 : Il exige le secret CI `LEAK_GUARD_EXTRA_PATTERNS` (motifs du propriétaire, geste de Paul, jamais dans le dépôt), puis une passe de `tools/dev/leak-guard.sh` avec ces motifs sur les fichiers de `071992c` et sur `main`. L'historique public garde les 109 emplacements génériques du diff de #8 : seule la réécriture d'historique (T-301, Paul) les retire. `main` lui-même ne porte plus de verrou : l'installation fail-closed y est depuis le 2026-11-17.
Piège constaté : `leak-guard.sh` lancé depuis un worktree sous `.claude/worktrees/` rend PASS sans rien voir (l'allowlist de chemin de `.gitleaks.toml` couvre tout l'arbre) ; scanner une copie hors de ce dossier.
