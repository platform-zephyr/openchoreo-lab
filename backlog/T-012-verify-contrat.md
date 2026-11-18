---
id: T-012
title: "`spec.verify` : vérification fonctionnelle déclarée (G10)"
status: todo
phase: P1
adr: [0011, 0013]
depends_on: [T-005]
class: AUTONOME
velocity: false
lane: contrat-appgen
github_issue: null
---
# T-012 — `spec.verify` : vérification fonctionnelle déclarée (G10)

## Intention
L'app dit ce qu'on doit observer (code HTTP, redirection IdP) ; la preuve automatique l'exécute.

## Périmètre de fichiers
docs/schema/, tools/appgen/, golden-paths/_checks/

## Critères de fin
- [ ] champ dans le schéma
- [ ] lu par le Job de preuve
- [ ] exemples pour A, B, OIDC
