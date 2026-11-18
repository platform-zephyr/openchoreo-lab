# Modèle PR des agents (Claude, Codex)

Objectif : les agents proposent et livrent des applications en autonomie ; les changements de sécurité et les opérations
destructrices restent contrôlés. La séparation est imposée par GitHub, pas par la bonne volonté de l'agent.

## Ce qui est imposé (ruleset `main-protection`, `tools/apply-branch-protection.sh`)
- PR obligatoire, check `ci-ok` requis, pas de force push, pas de suppression de `main`.
- **Revue des code owners exigée sur le seul noyau de confiance** (`.github/CODEOWNERS`, ADR-0002 du 2026-11-18) :
  CI (`.github/`), mandat et règles (`missions/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `docs/adr/`), sécurité amont
  (`security/`), droits des agents et frontière GitOps (`platform/authz/`, `platform/cluster-agent/`,
  `platform/install/argocd/`, `argo_guard`), VAP (`platform/policies/`) et leurs tests. Un agent ne peut donc pas
  élargir ses propres droits, affaiblir la CI ni réécrire une décision seul.
- Libres (PR + `ci-ok` verte suffisent) : tout le reste, y compris `platform/` hors noyau (types, traits, Kyverno,
  environments), `tools/appgen`, `golden-paths/`, `.agents/`. Une PR qui touche `platform/` doit avoir la CI k3d verte.
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
