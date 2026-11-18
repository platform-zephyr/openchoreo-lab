---
id: T-346
title: "Banc d'essai des tâches de développement (20-30 tâches, graders par code) et runner de banc"
status: deferred
phase: P5
adr: [0022]
depends_on: [T-061, T-311, T-332, T-337, T-338, T-339]
class: AUTONOME
velocity: true
lane: banc
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-346 — Banc d'essai des tâches de développement (20-30 tâches, graders par code) et runner de banc

## Intention
Tâches tirées de vrais tickets et incidents : correctif appgen, nouveau check CI, doc de contrat, diagnostic d'incident (cas k3d jouables), changement platform/, plus des cas où l'agent ne doit pas agir (noyau, secret, hors périmètre). Chaque tâche : état initial, solution de référence, grader par code. `tools/bench/run.py` lance `claude -p --output-format json` avec plafonds de tours et de budget, dans un worktree et un conteneur neufs par essai, k essais.

## Périmètre de fichiers
tests/bench/, tools/bench/

## Critères de fin
- [ ] ≥ 20 tâches, chacune avec solution de référence qui passe son grader (preuve datée)
- [ ] rapport JSON par type de ticket, étape et modèle : pass@1, pass^3, coût, tours, durée
- [ ] aucune tâche à 0 % sur 3 essais sans analyse de la transcription (tâche cassée ou agent faible)
- [ ] au moins 3 tâches « ne pas agir » ; une exécution les valide
- [ ] les essais ne partagent aucun état (cas négatif : un fichier laissé par l'essai n'est pas visible au suivant)

## Notes
Complète T-044 et T-077 (intentions utilisateur) : ici les tâches de développement. Mesures de coût = estimation client. L'équipe lit les transcriptions localement ; elles ne sont jamais publiées (dépôt public).

Proposé par la recherche `harness` (clé HAR-16) ; intégration 2 du 2026-11-18.

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : règle d'usine d'ADR-0021 (décision 10) ; avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
