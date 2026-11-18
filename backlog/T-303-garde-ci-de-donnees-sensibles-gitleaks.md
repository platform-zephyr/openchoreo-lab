---
id: T-303
title: "Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes)"
status: in-progress
phase: P0
adr: [0002, 0006]
depends_on: []
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-303 — Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes)

## Intention
Empêcher toute nouvelle fuite dans un dépôt public : job requis par ci-ok ; motifs propres au propriétaire chargés depuis un secret CI, jamais écrits dans le dépôt.

## Périmètre de fichiers
.gitleaks.toml, .github/workflows/ci.yaml, tools/dev/leak-guard.sh, tests/leak-guard/

## Critères de fin
- [x] job requis (`leak-guard`, dans `needs` de ci-ok), échoue sur un OCID, une IPv4 non documentaire, un e-mail hors noreply, un chemin local, un hôte interne
- [x] aucune valeur réelle dans .gitleaks.toml
- [x] (repris de HAR-6) cas négatifs : une IP privée, un OCID factice et un jeton factice font échouer la garde
- [x] (repris de HAR-6) cas positif : les adresses documentaires (plages réservées) passent
- [ ] (repris de HAR-6) même script en local, en CI et dans le hook Stop (T-331) ; seuls fichier et ligne sont affichés, jamais la valeur

## Notes
Livré (2026-11-18, non poussé) : `tools/dev/leak-guard.sh`, `.gitleaks.toml`, `.gitleaksignore` (dette : 129 emplacements fichier:règle:ligne, sans valeur, à vider par le nettoyage), `tests/leak-guard/run.sh` (24 cas), job `leak-guard` dans `ci.yaml`. Motifs du propriétaire : secret CI `LEAK_GUARD_EXTRA_PATTERNS` (ou `LEAK_GUARD_EXTRA_PATTERNS_FILE` hors dépôt), un regex par ligne ; absent = règles génériques seules. Reste à vérifier : exécution du job sur un runner arm64 (preuve CI), création du secret par Paul (geste humain), branchement dans le hook Stop (T-331) ; d'où `in-progress`.
Proposé par la recherche `sensitive` (clé SEC-4) ; intégration 2 du 2026-11-18.

En S0, tout de suite (consensus n°2 et arbitrages de Paul, 2026-11-18) : c'est la seule protection des données sensibles pendant le développement.
