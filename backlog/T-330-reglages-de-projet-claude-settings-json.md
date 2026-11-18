---
id: T-330
title: "Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie"
status: done
phase: P0
adr: [0022]
depends_on: []
class: REVUE
velocity: true
lane: agents-harness
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-330 — Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie

## Intention
Premier réglage versionné : deny de kubectl/helm/oc/occ vers un cluster, de Read des .env et clés, de `curl|sh` et du push forcé ; sandbox activé avec allowUnsandboxedCommands=false ; bashOutputMaxChars ; aucun outil d'écriture cluster. Fichier du noyau : Paul approuve.

## Périmètre de fichiers
.claude/settings.json, tests/hooks/settings.test.sh

## Critères de fin
- [x] `claude doctor` ne signale aucune entrée rejetée (preuve datée) — PASS RUNTIME 2026-11-18 (Claude Code 2.1.327) : aucune règle rejetée ; 4 avertissements hors fichier (install) + « globs Read/Edit ignorés par le sandbox sous Linux » (les règles de permission restent actives, la couche sandbox `denyRead` couvre les chemins `~/…` sans glob)
- [x] test CI (`tests/hooks/settings.test.sh`, PASS 2026-11-18) : le JSON est valide et ne contient aucune règle allow pour kubectl, helm, occ, curl, ssh
- [x] cas négatif : `claude -p --permission-mode dontAsk` + `kubectl get pods -A` refusé (`Permission to use Bash with command kubectl get pods -A has been denied`, permission_denials non vide) — PASS RUNTIME 2026-11-18, session cloud ; le dossier n'était pas « de confiance » (les `allow` ignorés), le refus vient donc de `deny` et/ou de `dontAsk` sans allow

## Notes
La doc indique que ce fichier n'est lu qu'en session cloud à un seul dépôt, pas en thread de projet : la CI reste la garantie. Voir §2.1 du rapport.

Proposé par la recherche `harness` (clé HAR-0) ; intégration 2 du 2026-11-18.

Choix de réglage : `defaultMode: acceptEdits` (la doc cloud n'honore que acceptEdits/plan/default/auto ; `dontAsk` reste le mode des sessions `-p` de CI) ; `disableBypassPermissionsMode`; sandbox sans `failIfUnavailable` (le bwrap manque en cloud, la CI reste la garantie). `kubectl`, `tofu`, `doppler`, `ssh` sont refusés en entier : la lecture du cluster passe par T-006.
