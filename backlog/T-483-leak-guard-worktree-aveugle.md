---
id: T-483
title: "leak-guard : ne plus rendre PASS à vide depuis un worktree sous .claude/worktrees/"
status: done
phase: P0
adr: [0002]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3
github_issue: null
---
# T-483 — leak-guard aveugle dans un worktree d'agent

## Intention
`tools/dev/leak-guard.sh` rend PASS sans rien voir quand il est lancé depuis un worktree sous `.claude/worktrees/` : l'allowlist de chemin `(?:^|/)\.claude/worktrees/` de `.gitleaks.toml` couvre alors tout l'arbre. Le PASS `leak-guard` de `tools/dev/check` lancé dans un worktree d'agent ne prouve donc rien. Faire en sorte que la garde scanne réellement (ancrer l'allowlist au dépôt, ou refuser de conclure PASS si le chemin racine est allowlisté), avec un test qui échoue avant le correctif.

## Périmètre de fichiers
.gitleaks.toml, tools/dev/leak-guard.sh, tests/leak-guard/

## Critères de fin
- [x] test : une valeur factice sous un worktree `.claude/worktrees/x/` est détectée (échoue avant, passe après)
- [x] le PASS ne peut plus être rendu à vide (garde de sanité ou allowlist ancrée)
- [x] `tools/dev/check --static --changed` : verdict reporté (commit ; à reporter dans la PR)

## Notes
Trouvé par l'agent de T-001 (2026-11-18). Fichier du noyau de sécurité : classe REVUE de fait si `.gitleaks.toml` est dans CODEOWNERS.

## Résultat (2026-11-18)
- Allowlist ancrée à la racine scannée (`^\.claude/worktrees/`) : un chemin absolu ou une racine sous `.claude/worktrees/` n'est plus ignoré (test rouge avant : gitleaks en chemin absolu rendait 0).
- Sonde de sanité dans `leak-guard.sh` : une valeur factice connue doit être détectée avec la même configuration, sinon code 2 (jamais PASS à vide).
- Correctif annexe : le chemin rapporté n'est plus résolu contre le cwd du script.
- Reproduction : `dir .` depuis le worktree détectait déjà ; seule l'invocation par chemin absolu était aveugle. Le critère « verdict reporté dans la PR » reste à faire à l'ouverture de la PR.
