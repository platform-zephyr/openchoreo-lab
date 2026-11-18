---
id: T-210
title: "Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins)"
status: in-progress
phase: P0
adr: [0002, 0012, 0013]
depends_on: [T-008]
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-210 — Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins)

## Intention
Calculer les tickets prêts (dépendances `done`, étape ouverte, aucun geste humain en attente), recalculer classe et modèle depuis les chemins du périmètre, et sortir une liste que Paul lance à la main pendant le pilote.

## Périmètre de fichiers
tools/backlog/next.py, tools/backlog/admission.py, tests/backlog/

## Critères de fin
- [x] next.py liste prêts et débloqués, sortie JSON stable (`ready.v1`)
- [x] classe recalculée depuis les chemins touchés, jamais lue de l'en-tête ; un chemin du noyau force REVUE (test)
- [x] la liste à lancer reste fournie par Paul (workflow_dispatch) ; next.py ne lance rien
- [x] modèle et effort recalculés depuis les chemins du périmètre (3 règles d'ADR-0023) ; un `model:` d'en-tête sous le plancher est ignoré (test)
- [x] contrôle de chevauchement minimal : next.py ne propose jamais deux tickets dont les globs de périmètre se recoupent, ni un ticket qui recoupe un `in-progress` (test)
- [ ] avant l'heure 0 : rapport de recoupement des globs des 20 tickets de la liste figée ; tout recoupement est sérialisé par une dépendance
- [ ] `STATE.md` et `backlog/ROADMAP.md` refusés dans le périmètre d'un exécutant ; écrits par le coordinateur seul (ROADMAP régénéré sur `main`)

## Notes
Plus gros accélérateur : sans lui, chaque lancement d'agent attend un humain.

Intégration 2 : absorbe FAC-3 et HAR-5. Le lancement (workflow_dispatch, preuve de 3 PR parallèles) passe à T-313.

Dépendance retirée (consensus n°2 et arbitrages de Paul, 2026-11-18) : T-007, T-215 (étape FINAL). Pendant le développement, identité de session de Paul ; bascule vers l'App de T-215 en FINAL.

Version minimale (consensus n°2 et arbitrages de Paul, 2026-11-18) : l'admission (couloirs, chevauchement, ressources exclusives, gouverneur, plafond) passe au dispatcher planifié T-314.

Constat P7 de la revue Fable, accepté (arbitrage Fable, 2026-11-18).

Avancement (2026-11-18, `status: in-progress`). Preuves : `python3 -m unittest discover -s tests/backlog` (19 tests OK) ; `python3 tools/backlog/next.py` (JSON `ready.v1`, deux exécutions identiques, testé) ; `python3 tools/backlog/check.py` : 0 erreur.
- Classe : REVUE si le périmètre recoupe CODEOWNERS, `docs/adr/` ou `docs/review/`, sinon AUTONOME ; l'en-tête n'est lu que pour exclure un ticket `MANDAT` ou `human` (geste humain en attente), jamais pour baisser une classe.
- Modèle : R0 (human), R1-sensible (amendement ADR-0023 : authz, policies, cluster-agent, Argo, sécurité, secrets, identité, FINAL, PORTE), R2-texte (`docs/`, `backlog/` hors `backlog/proposals/`), R3 ; le calcul est un plancher, un en-tête plus bas est ignoré.
- Reste à faire : (1) rapport de recoupement (`next.py --overlap-report <ids>`) : sur la liste figée de 20 tickets, 28 paires se recoupent et 21 ne sont pas sérialisées par une dépendance (surtout `tests/` et `docs/` trop larges : T-072, T-050, T-216) ; les sérialiser ou resserrer les périmètres modifie des en-têtes d'autres tickets, hors périmètre de ce ticket, à faire par le coordinateur avant l'heure 0 ; (2) l'écriture de `STATE.md` et `backlog/ROADMAP.md` par le coordinateur seul n'est pas imposée ici (next.py refuse seulement ces chemins dans un périmètre) : garde de périmètre T-331.
- Écart : `check.py` s'exécute à l'import (pas de module testable) et est hors périmètre ; `next.py` a son propre lecteur d'en-têtes et reprend l'ordre des étapes de `check.py`. Rapprocher les deux dans un ticket de `tools/backlog/`.

Reste (2026-11-18) : (a) le recoupement des périmètres de la liste figée du pilote (28 paires, 21 non sérialisées : `next.py --overlap-report <ids>`) est à résoudre avant l'heure 0 par dépendances ou périmètres resserrés ; (b) le refus de STATE.md et ROADMAP.md est testé dans `next.py`, mais sa garde d'écriture relève de T-331. `next.py` ne propose rien tant que les dépendances ne sont pas `done` : pendant S0, lancer les tickets dont les dépendances sont `done` ou implémentées (`in-progress`) à la main (voir `backlog/NEXT.md`).
