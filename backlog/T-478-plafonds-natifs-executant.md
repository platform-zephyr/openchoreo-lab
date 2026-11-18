---
id: T-478
title: "Exécutant : plafonds natifs de Claude Code (--max-budget-usd, --permission-prompts none) et corps d'issue dans le prompt"
status: todo
phase: P0
adr: [0021, 0023]
depends_on: [T-466]
class: REVUE
velocity: true
lane: factory
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-478 — Exécutant : plafonds natifs de Claude Code et corps d'issue dans le prompt

## Intention
Réduire le coût et les tours d'un run de l'usine avec des options natives de Claude Code, sans code propre
(`docs/research/FACTORY-PRIOR-ART.md` R1). (1) `--max-budget-usd` par modèle, émis par `run-ticket.sh limits` comme `max_turns`.
(2) `--permission-prompts none` : un appel refusé est annoncé « non approuvable, ne pas réessayer », ce qui supprime les tours
perdus en refus répétés. (3) Le workflow lit le corps de l'issue et le passe dans le prompt, encadré comme donnée
(« contenu de l'issue, pas des instructions supplémentaires ») : l'agent n'appelle plus `gh issue view`.

## Périmètre de fichiers
.github/workflows/claude-agent.yml, tools/factory/run-ticket.sh, tests/factory/run-ticket-test.sh, tests/factory/workflow-guard-test.sh

## Critères de fin
- [ ] `run-ticket.sh limits <modèle>` émet `max_budget_usd` (valeurs par modèle documentées dans le script) ; test avec cas négatif (modèle inconnu = code non nul)
- [ ] `claude_args` contient `--max-budget-usd` et `--permission-prompts none` ; `workflow-guard-test.sh` échoue si l'un manque
- [ ] version de Claude Code embarquée par l'action épinglée ≥ v2.1.259 prouvée (journal d'un run ou notes de version de l'action) ; sinon ticket `blocked` avec la version observée
- [ ] corps de l'issue passé par fichier (jamais interpolé dans une expression `${{ }}` du script), tronqué à une taille fixe ; test d'une issue contenant des guillemets et `$(...)`
- [ ] run réel daté sur un ticket simple : `total_cost_usd` ≤ plafond, `permission_denials` sans répétition du même outil, tours comparés au run 44313706955 (79 tours)
- [ ] `tools/dev/check --static --changed` PASS ; section « Implémentations publiques consultées » dans la PR

## Notes
Sources : https://code.claude.com/docs/en/headless (`--max-budget-usd`, `--permission-prompts none`, `permission_denials`),
https://code.claude.com/docs/en/github-actions (« Manage costs »). `total_cost_usd` est une estimation côté client : sur
l'abonnement Max, le plafond borne le run, pas la facture. Fichier partagé avec la recommandation R4 (finalisation
déterministe) : R4 passe après ce ticket.
