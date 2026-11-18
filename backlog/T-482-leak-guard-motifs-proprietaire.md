---
id: T-482
title: "Passe leak-guard avec les motifs propres au propriétaire sur le diff de la PR #8 et sur main"
status: todo
phase: P0
adr: [0002]
depends_on: [T-001]
class: MANDAT
velocity: false
lane: gouvernance
stage: FINAL0
model: claude-haiku-5-5
effort: medium
routing: R2-texte
github_issue: null
---
# T-482 — Passe leak-guard avec les motifs propres au propriétaire

## Intention
Prouver que le diff public de la PR #8 (commit `071992c`) et `main` ne contiennent aucun « mot sensible » propre au propriétaire. Issu de T-001 (ancien critère 2).

## Périmètre de fichiers
docs/runbooks/leak-guard-motifs.md

## Critères de fin
- [ ] MANDAT Paul : secret CI `LEAK_GUARD_EXTRA_PATTERNS` défini (jamais dans le dépôt, nom seul consigné)
- [ ] `tools/dev/leak-guard.sh` avec ces motifs sur les fichiers de `071992c` et sur `main`, scanné depuis une copie hors de `.claude/worktrees/` : PASS daté, valeurs non affichées
- [ ] les emplacements génériques restés dans l'historique public sont listés (retrait par T-301, Paul)

## Notes
Avant FINAL0. Un PASS lancé dans un worktree sous `.claude/worktrees/` ne prouve rien (voir T-483).
