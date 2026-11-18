---
id: T-306
title: "Registre des identités et secrets `docs/state/identities.yaml` (noms, rôles, dates, jamais de valeur)"
status: todo
phase: P0
adr: [0002, 0022]
depends_on: []
class: REVUE
velocity: false
lane: gouvernance
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-306 — Registre des identités et secrets `docs/state/identities.yaml` (noms, rôles, dates, jamais de valeur)

## Intention
Tenir dès maintenant l'inventaire de toute identité ou tout secret créé pendant le développement (mode à sécurité allégée), pour pouvoir tout tourner à FINAL0 et à FINAL.

## Périmètre de fichiers
docs/state/identities.yaml, docs/schema/identities.v1.json, tools/backlog/identities_lint.py, tests/identities/, .github/CODEOWNERS

## Critères de fin
- [ ] schéma `identities.v1` : nom, rôle, portée, propriétaire, date de création, date de rotation, `dev: true|false` ; aucun champ de valeur (test de refus)
- [ ] registre initial : jeton d'abonnement Claude, identité de l'exécutant (permission `workflows`), accès Doppler élargi, jeton ESO et kubeconfig du lab, secrets machine Talos du lab (noms seulement)
- [ ] lint CI : une entrée sans date ou avec un champ ressemblant à une valeur échoue ; garde T-303 verte sur le fichier
- [ ] `docs/state/identities.yaml` ajouté à CODEOWNERS ; règle écrite : toute création d'identité ou de secret ajoute une entrée dans la même PR

## Notes
Constat F3 de la revue Fable, accepté (arbitrage Fable, 2026-11-18). Jamais de valeur, d'IP, d'hôte interne ni d'e-mail dans ce fichier public.
