---
id: T-314
title: "Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission"
status: todo
phase: P0
adr: [0021]
depends_on: [T-061, T-210, T-311, T-313]
class: REVUE
velocity: true
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-314 — Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission

## Intention
À chaque tick : relire backlog, PR, runs ; admettre les prêts selon T-210 et le gouverneur ; lancer T-313 ; ne jamais dupliquer un lancement (vérifier branche, PR et run avant).

## Périmètre de fichiers
.github/workflows/factory-dispatch.yml, tools/factory/dispatch.py

## Critères de fin
- [ ] idempotence : deux ticks consécutifs ne lancent pas deux fois le même ticket (test)
- [ ] preuve : 24 h de ticks, 0 doublon, 0 lancement pendant PAUSE ou disjoncteur ouvert
- [ ] étape fermée = aucun lancement ; seules une ou deux étapes ouvertes à la fois
- [ ] (repris de T-210) tests : deux tickets du même couloir, deux scopes qui se chevauchent, une ressource exclusive occupée : un seul est admis
- [ ] (repris de T-210) test : deux tickets aux périmètres recoupés ne sont jamais proposés ensemble
- [ ] (repris de T-210) test : périmètres disjoints dans un même couloir sont proposés ensemble
- [ ] (repris de T-210) plafond global 4 au départ (relevé par T-322), 2 par couloir, 1 sur contrat-appgen avant T-214 ; contrat de mission d'Atlas (max_attempts 2)
- [ ] (repris de T-210) l'admission lit le gouverneur de quota (T-311) quand il existe : refus au-delà du seuil (test hors ligne)
- [ ] (repris de T-210) le modèle et l'effort de chaque ticket admis viennent de des 3 règles d'ADR-0023 ou, à défaut, de l'en-tête

## Notes
S0 et le pilote restent manuels (CONSENSUS #11) ; le cron s'active après la preuve de T-313.

Proposé par la recherche `factory` (clé FAC-5) ; intégration 2 du 2026-11-18.

Dans la liste figée du pilote (consensus n°2 et arbitrages de Paul, 2026-11-18) : construit pendant le pilote, cron activé seulement après la décision de T-322.
