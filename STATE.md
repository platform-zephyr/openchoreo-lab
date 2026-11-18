---
owner: coordinateur (Paul valide)
updated: 2026-11-18
review_days: 7
---
# STATE — openchoreo-lab

<!-- Réécrit (jamais en ajout) à chaque jalon par le coordinateur, seul rédacteur. Max 60 lignes / 6 Ko, vérifié par tools/context-check. Historique : docs/state/journal/AAAA-MM-JJ.md (ajout seul). Aucun secret, aucune IP, aucun chemin privé. -->

**Objectif** : IDP OpenChoreo 1.3.3 utilisable ; une intention en langage naturel devient une app livrée par PR, avec preuve runtime datée. Cible : homelab par défaut (VM Talos « lab »), OKE optionnel (ADR-0003, D11).
**Mode** : dev (sécurité allégée, les agents fusionnent après `ci-ok`, revue des code owners suspendue jusqu'à FINAL0). **Reprise sans mémoire** : skill `orchestrate-backlog`, puis `docs/state/HANDOFF-COORDINATEUR.md`, `backlog/NEXT.md` et `python3 tools/backlog/priority.py --top 10`.

## Jalons (statut · date · preuve)
| Jalon | Statut | Date (Z) | Preuve |
|---|---|---|---|
| OKE étapes 0-9 et 11, pilote `whoami` (déploiement, modification, rollback par PR) | PASS | 2026-11-17 | `docs/state/journal/2026-11-18.md` §3 et §1 |
| Installation fail-closed (security bundle 1.0.1, PR #8 fusionnée) | PASS (CI) | 2026-11-17 | commit `071992c` |
| Suite k3d (4 suites) après T-469 : 52 PASS, 0 FAIL, 1 NOT_TESTED | PASS (RUNTIME k3d) | 2026-11-18 | run 44343243035 ; k3d n'est pas OKE |
| Usine d'agents `claude-agent.yml` (plan, dev, verdict, rapport) | PASS | 2026-11-18 | run 44338002716 (2 agents, 28 et 17 tours) |
| Statistiques de l'usine (`tools/factory/stats.py`) | PASS (STATIC) | 2026-11-18 | `docs/research/FACTORY-STATS-REPORT-2026-11-18.md` |
| Capacités du cluster homelab (schéma et fichier) | PASS (STATIC) | 2026-11-18 | PR #112 ; valeurs NOT_TESTED |
| Mesures du homelab (T-360) | NOT_TESTED (script livré, Paul le lance) | — | `docs/research/HOMELAB-MESURES.md` |
| VM Talos « lab », OpenChoreo sur le homelab (T-361 à T-364) | NOT_TESTED | — | gestes de Paul |
| Pilote 24 h à N=3 (T-322) | NOT_TESTED | — | prérequis dans `backlog/NEXT.md` |
| `factory/PAUSE` et disjoncteur de quota | NOT_PROVEN | — | T-311 |

## Prochaines actions (ordre)
1. Paul lance le script de mesure (T-360) et colle la sortie : débloque T-366 et la taille des VM.
2. Clore T-002 : `k3d-integration` vert sur `main` après T-458 (débloque 16 tickets).
3. Statut de ticket dérivé et fin de `STATUS.md` committé (branche `claude/statut-derive`).
4. Prouver `factory/PAUSE`, le disjoncteur et un lot de 5 dispatchs (T-311), puis pilote T-322.
5. Chaîne de vrai déploiement : T-361 → T-364, puis T-005 et T-006 (statut publié, retour pour les agents), T-015.

## Bloquants et décisions humaines (noms seulement)
- Paul : script de mesure T-360 ; VM et isolation réseau (T-361, T-362) ; secret `LEAK_GUARD_EXTRA_PATTERNS` (T-482) ; 2FA de l'organisation (lecture du 2026-11-18 : FAIL) ; clé de signature du tag `core-baseline` à déclarer à GitHub ; restriction réseau de l'environnement cloud en fin de livraison.
- Paul : décisions D1-D3 de `docs/research/context-engineering/CONTEXT-ENGINEERING.md` §8 ; FINAL0 (App définitive T-215, retrait du contournement admin T-400, signature du tag).
- Arbitrer avant FINAL0 : mode de permission de l'action (`auto` n'est pas une liste blanche stricte).

## Flux actifs (ne pas relancer un flux déjà livré)
| Flux | Statut |
|---|---|
| Run k3d de preuve de T-458 (`claude/t-458-reste`) | en cours |
| Agent « statut dérivé » (`claude/statut-derive`) | en cours |

## Pièges connus
- La session coordinatrice est root, les runners non : tester aussi hors root.
- Un job CI rouge peut être une annulation (exécution remplacée) : regarder la tête courante de la PR.
- Un ticket doit se clore dans la PR qui le livre : un statut en retard garde des dépendants bloqués (cas T-214).
- `leak-guard` : scanner une copie hors de `.claude/worktrees/` (T-483 corrige la garde).
- Image toujours qualifiée `docker.io/…` sur OKE ; un `git revert` ne supprime jamais les releases historiques.
- Un point de sécurité amont est en coordination privée : ne publier AUCUN détail ici.

## Accès et exécution
Les agents n'ont ni kubeconfig ni accès cluster ; ils changent le dépôt par PR. Un seul exécutant sur le cluster réel (le coordinateur, avec Paul). Écritures : `AGENTS.md`.

## Où trouver quoi
Contrat `docs/APP-CONTRACT.md` · archétypes `golden-paths/` · skills `.agents/skills/` · mission `missions/MISSION.md` · décisions `docs/adr/` · backlog `backlog/` · usine `docs/AGENT-RUNNERS.md` · preuves `tests/`, `backlog/evidence/`.
