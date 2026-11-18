---
id: T-303
title: "Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes)"
status: todo
phase: P0
adr: [0002, 0006]
depends_on: []
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R07-ci-github-actions
github_issue: null
---
# T-303 — Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes)

## Intention
Empêcher toute nouvelle fuite dans un dépôt public : job requis par ci-ok ; motifs propres au propriétaire chargés depuis un secret CI, jamais écrits dans le dépôt.

## Périmètre de fichiers
.gitleaks.toml, .github/workflows/ci.yaml, tools/dev/leak-guard.sh, tests/leak-guard/

## Critères de fin
- [ ] job requis, échoue sur un OCID, une IPv4 non documentaire, un e-mail hors noreply, un chemin local, un hôte interne
- [ ] aucune valeur réelle dans .gitleaks.toml
- [ ] (repris de HAR-6) cas négatifs : une IP privée, un OCID factice et un jeton factice font échouer la garde
- [ ] (repris de HAR-6) cas positif : les adresses documentaires (plages réservées) passent
- [ ] (repris de HAR-6) même script en local, en CI et dans le hook Stop (T-331) ; seuls fichier et ligne sont affichés, jamais la valeur

## Notes
Proposé par la recherche `sensitive` (clé SEC-4) ; intégration 2 du 2026-11-18.
