---
id: T-041
title: "Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur"
status: done
phase: P0
adr: [0012]
depends_on: []
class: REVUE
velocity: true
lane: connaissance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-041 — Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur

## Intention
Appliquer la proposition `docs/research/context-engineering/` dans ce dépôt.

## Périmètre de fichiers
AGENTS.md, CLAUDE.md, STATE.md, missions/MISSION.md (en-tête de fraîcheur), docs/state/journal/, docs/adr/README.md, golden-paths/README.md (périmés), tools/context-check/, tests/context-check/, .github/workflows/ci.yaml (job du check de contexte ; couplé à tools/dev/check et ci-map.tsv)

## Critères de fin
- [x] fichiers toujours chargés ≤ 130 lignes au total — STATIC, 2026-11-18 : `AGENTS.md` 26 + `CLAUDE.md` 1 + `STATE.md` 78 = 105 lignes (`python3 tools/context-check/check_context.py --root .` : 0 erreur). Reste : `STATE.md` ≤ 60 lignes / 6 Ko et en-tête de fraîcheur, en avertissement (`pending`) jusqu'à sa réécriture par la session coordinatrice.
- [x] check CI taille/liens/fraîcheur — job `context-check` (dans `needs` de `ci-ok`) et étape `tools/dev/check` écrits ; PASS local (STATIC, 21 tests) ; CI NOT_TESTED (aucun run sur la branche). ; CI : job `context-check` `success` sur la tête 7d90a57 de la PR #111 (run 44354802721, 2026-11-18, CI)
- [x] aucune règle impérative perdue (diff relu) — STATIC, 2026-11-18 : les 13 règles de l'ancien `AGENTS.md` restent mot pour mot ou fusionnées (périmètre écriture + lecture en une règle) ; pointeurs `backlog/`, `docs/adr/`, `docs/CLOUD-AGENTS.md`, `golden-paths/` gardés ; seule la liste des skills sort (leurs descriptions sont déjà chargées), sauf la règle `mattpocock-*` « méthode, jamais permission », gardée. Ajout : préséance des sources (proposition §6).

## Notes
Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Sorti de la liste figée du pilote (arbitrage Fable, 2026-11-18) : périmètre trop large (chevauchement, constat P7).

Livré (branche `claude/t-041-contexte`, 2026-11-18) : `AGENTS.md` court (26 lignes), en-tête de fraîcheur de `missions/MISSION.md`, `golden-paths/README.md` (gate OKE franchi), `tools/context-check/` + `tests/context-check/`, job CI et étape `context-check`. `docs/adr/README.md` était déjà à jour (0001-0024).
Reste à la session coordinatrice (garde T-331 : `STATE.md` lui est réservé) : réécrire `STATE.md` au gabarit `docs/research/context-engineering/openchoreo-lab-proposal/STATE.md`, archiver l'ancien dans `docs/state/journal/2026-11-18.md`, puis retirer `pending` de `tools/context-check/context-check.json`. Hors périmètre : D1-D3 (Paul), règle `deny` ThunderID après D2.
Décision du coordinateur (2026-11-18, écart 7) : un en-tête de fraîcheur périmé est un AVERTISSEMENT daté, jamais bloquant (sinon `ci-ok` rougirait sur toutes les PR après la date de revue) ; restent bloquants la taille, les liens et `@import` cassés, et les en-têtes absents ou invalides (indépendants du temps). Test : fichier périmé de 400 jours = avertissement et code 0.

Clôture (2026-11-18) : `STATE.md` réécrit par le coordinateur (57 lignes, 4,6 Ko, en-tête de fraîcheur), ancien contenu archivé dans `docs/state/journal/2026-11-18.md`, entrée `pending` retirée de `context-check.json` ; `check_context.py --root .` : 0 erreur, 2 avertissements (descriptions de skills > 450 caractères). Restent hors ticket : décisions D1-D3 de Paul et règle `deny` ThunderID.
