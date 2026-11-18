---
id: T-215
title: "Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1"
status: todo
phase: P4
adr: [0002]
depends_on: [T-061, T-061b]
class: REVUE + MANDAT
velocity: true
lane: gouvernance
stage: FINAL0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-215 — Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1

## Intention
Une identité agent sans droit d'admin et une seule GitHub App (statut de commit, Renovate, dispatch, remédiation). Aucun agent n'agit avec le compte admin de Paul. Ajoute le mandat de lot (étape, tickets, chemins, plafonds de diff et de dépense, expiration) signé par PR dans le noyau ; l'App reçoit les permissions de dispatch et de merge sous conditions (merge effectif : T-315).

## Périmètre de fichiers
docs/AGENT-IDENTITY.md, docs/AGENT-PR-MODEL.md, missions/mandates/, .github/ (CODEOWNERS : ligne missions/mandates/)

## Critères de fin
- [ ] compte agent rôle Write créé par Paul
- [ ] GitHub App plateforme installée sur ce dépôt seulement, permissions minimales listées
- [ ] essai réel : une PR du noyau ouverte par l'agent n'est pas fusionnable
- [ ] (repris de FAC-1) schéma `mandate.v1` + validateur ; un mandat expiré ou hors liste de chemins est refusé (test négatif)
- [ ] (repris de FAC-1) App : permissions listées (Contents RW, Pull requests RW, Actions RW, Metadata R), installée sur ce dépôt seul ; essai : une PR du noyau ouverte par l'App n'est pas fusionnable
- [ ] (repris de FAC-1) essai daté : une session cloud ouvre une PR du noyau ; l'identité de l'auteur et la non-fusionnabilité sont consignées
- [ ] GITHUB_TOKEN ne déclenche pas la CI sur les PR qu'il ouvre et plafonne à 1 000 req/h (vérification du 2026-11-18) : dispatch, Renovate et remédiation passent par l'App
- [ ] config git `noreply` imposée par le harness (hook ou réglage de session) ; aucun commit d'usine sous l'identité de Paul
- [ ] bascule vers l'App des workflows qui utilisaient l'identité de dev : dispatch (T-313, T-314), merge automatique (T-315), preuve (T-005), remédiation (T-106), Renovate (T-121)

## Notes
Absorbe les parties GitHub de T-005, T-106, T-121, T-164 et T-210.

MANDAT : création de l'App, option « Allow auto-merge ». Le mandat n'ouvre jamais secret, accès, dépense hors free tier, apply, INTERDIT (platform-guardrails). Fusion de FAC-1.

Étape FINAL (consensus n°2 et arbitrages de Paul, 2026-11-18) : pendant le développement, les sessions agissent avec l'identité de Paul (arbitrage 4) ; le pack identité est obligatoire avant de déclarer la plateforme finie (décision 1 déplacée).
