---
id: T-330
title: "Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie"
status: todo
phase: P0
adr: [0022]
depends_on: [T-061]
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
- [ ] `claude doctor` ne signale aucune entrée rejetée (preuve datée)
- [ ] test CI : le JSON est valide et ne contient aucune règle allow pour kubectl, helm, occ, curl, ssh
- [ ] cas négatif : un `kubectl get pods` lancé en session `-p --permission-mode dontAsk` est refusé (NOT_TESTED si la session cloud ne lit pas le fichier, à noter)

## Notes
La doc indique que ce fichier n'est lu qu'en session cloud à un seul dépôt, pas en thread de projet : la CI reste la garantie. Voir §2.1 du rapport.

Proposé par la recherche `harness` (clé HAR-0) ; intégration 2 du 2026-11-18.
