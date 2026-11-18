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

Décision à arbitrer par Paul (intégration 5, 2026-11-18) (GH-11, pas de ticket T-440) : une seule App (texte actuel) ou deux Apps, `openchoreo-agents` (Contents, Pull requests, Actions, Metadata ; SANS la permission workflows) et `openchoreo-renovate` (Contents, Pull requests, Workflows, Metadata ; sans merge), aucune des deux dans `bypass_actors`. Motif : Renovate doit modifier `.github/workflows/` (pins d'actions), permission qu'aucun agent ne doit avoir (ADR-0002 §5) ; une App ne coûte ni siège ni licence. Si Paul choisit deux Apps, ajouter ici : permissions des deux Apps dans `identities.yaml` (noms seulement) ; essai : une PR de l'App agents sur `.github/workflows/` est refusée au push ; essai : une PR de l'App Renovate sur `.github/workflows/` n'est pas fusionnable sans Paul ; clés privées en secrets d'environnement `factory` (branche `main` seule) ; et T-121 prend l'App Renovate. Alternative écartée : PAT fin (droits de Paul, durée longue).
