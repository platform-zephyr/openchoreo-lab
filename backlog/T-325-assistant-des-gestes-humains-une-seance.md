---
id: T-325
title: "Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT"
status: done
phase: P0
adr: [0013, 0021]
depends_on: [T-008]
class: AUTONOME
velocity: true
lane: connaissance
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-325 — Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT

## Intention
Produire pour chaque étape la liste ordonnée des gestes exacts (noms de secrets, pas de valeurs ; liens ; durée) et un script interactif qui vérifie chaque effet en lecture seule (secret présent, label, App installée, runner enregistré).

## Périmètre de fichiers
tools/factory/gestes.sh, docs/GESTES-PAUL.md (généré)

## Critères de fin
- [x] sortie pour S0 : toutes les demandes des tickets S0 en MANDAT, ordonnées, ≤ 30 min estimées (2026-11-18 : `docs/GESTES-PAUL.md`, 4 gestes T-305, T-431, T-433, T-434 dans l'ordre des dépendances, 29 min estimées ; T-301, « hors chemin critique », listé hors séance ; `tools/factory/gestes.sh verify-doc` PASS)
- [x] aucune valeur de secret ni sortie sensible affichée ou écrite (test gitleaks) (2026-11-18 : garde à motifs fermée, code 3 sans afficher la valeur ; `tests/factory/gestes-test.sh` PASS dont gitleaks sur le document généré ; `tools/dev/leak-guard.sh` PASS)
- [x] le script marque chaque geste PASS/FAIL/NOT_TESTED avec horodatage (2026-11-18 : sondes sur fixtures dans `tests/factory/gestes-test.sh` ; relevé réel `gestes.sh check` : T-305 PASS, T-433 FAIL, T-431 et T-434 NOT_TESTED)

## Notes
Le geste est fait par Paul ; le script ne crée aucun accès (platform-guardrails §2). Réduit le temps de séance, pas les droits.

Proposé par la recherche `factory` (clé FAC-16) ; intégration 2 du 2026-11-18.

Passé de S0 à S1 (consensus n°2 et arbitrages de Paul, 2026-11-18) : pas nécessaire au pilote 24 h (voie parallèle).

Livré (2026-11-18) : `tools/factory/gestes.sh` (`list`, `generate`, `verify-doc`, `check`, `seance`), `docs/GESTES-PAUL.md` (généré), `tests/factory/gestes-test.sh`. Une déclaration de Paul sans sonde reste `NOT_TESTED`, jamais `PASS`. La durée est une estimation conventionnelle (3 min par ticket sauf mention dans le ticket). Branché par T-475 (STATIC PASS 2026-11-18) : `gestes-test.sh` (dont `verify-doc` sur le document réel et gitleaks) tourne dans l'étape `factory` de `tools/dev/check`, job `dev-factory` de `ci.yaml` (gitleaks installé, épinglé). Run CI : NOT_TESTED avant la fusion.
