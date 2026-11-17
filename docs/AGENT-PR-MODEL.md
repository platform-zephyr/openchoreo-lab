# Modèle PR des agents (Claude, Codex)

Objectif : les agents proposent et livrent des applications en autonomie ; les changements de sécurité et les opérations
destructrices restent contrôlés. La séparation est imposée par GitHub, pas par la bonne volonté de l'agent.

## Ce qui est imposé (ruleset `main-protection`, `tools/apply-branch-protection.sh`)
- PR obligatoire, check `ci-ok` requis, pas de force push, pas de suppression de `main`.
- **Revue des code owners exigée** (`.github/CODEOWNERS`) : toute PR qui touche `platform/`, `tools/`, `tests/`, `.github/`,
  `security/`, `clusters/`, `docs/schema/`, `AGENTS.md`, `.agents/`, `missions/` exige l'approbation de Paul. Un agent ne
  peut donc pas modifier la CI, les politiques, le RBAC, les droits Argo ni les garde-fous seul.
- Libres (PR + `ci-ok` verte suffisent) : `apps/**`, `generated/**`, `docs/` hors schéma. C'est le golden path applicatif.
- La CI refuse déjà : suppression de release historique (`release-history`), Application/projet Argo hors périmètre
  (`argo_guard`), secrets (`gitleaks`), rendus Helm sans PSA restricted.

## Identité des agents (une seule action de Paul)
Un PAT n'est pas « sans droit de merge » : il a les droits de son propriétaire. Il faut donc une **identité distincte** :
1. Compte GitHub dédié (machine user) invité sur `openchoreo-lab` avec le rôle **Write** (jamais Admin/Maintain : le
   contournement du ruleset est réservé au rôle Admin).
2. PAT fine-grained de ce compte, limité au dépôt `openchoreo-lab` : *Contents* RW, *Pull requests* RW, *Metadata* R.
   **Sans** *Workflows*, *Administration*, *Secrets*, *Environments* (donc impossible de modifier `.github/workflows/`).
3. Expiration courte (≤ 90 jours), stocké dans Doppler, jamais dans Git. Le token de Paul ne va jamais à un agent.
Avec cette identité, l'agent peut ouvrir et fusionner une PR applicative dès que `ci-ok` est verte, et ne peut pas
fusionner une PR sensible sans Paul.

## Accès Kubernetes
Aucun accès en écriture : le déploiement passe par Git → Argo. Lecture : client MCP `openchoreo-agent-reader` (docs/AGENT-ACCESS.md).
Les opérations destructrices (suppression d'application, volumes, authz) passent par une PR sur des chemins protégés.
