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

## Gouverneur minimal de l'usine (T-311, ADR-0021)
- **Kill-switch** : le fichier `factory/PAUSE` sur `main` (noyau, CODEOWNERS) arrête tout lancement d'agent et tout merge
  automatique. Pour arrêter : créer le fichier (vide) par PR ; pour reprendre : le supprimer. Lecture par
  `factory/pause-check.sh` (code 10 = en pause). `claude-agent.yml` le contrôle dans le job `plan`, puis à nouveau dans
  chaque job de la matrice (un job peut attendre longtemps derrière `max-parallel`). Un agent qui arme l'auto-merge
  exécute d'abord `factory/pause-check.sh` avec `PAUSE_REF=origin/main` et n'arme rien si le code est 10. Limite connue :
  une PR dont l'auto-merge est déjà armé n'est pas désarmée par la pause ; le désarmement (`gh pr merge --disable-auto`)
  relève du dispatcher (T-210) et de T-315.
- **Concurrence 3** : la matrice du job `dev` porte `max-parallel: 3` (valeur de `factory/config.yaml`, vérifiée par
  `tests/factory/pause-test.sh`). Un `workflow_dispatch` avec 5 issues crée 5 jobs : 3 tournent, 2 attendent, aucun n'est
  annulé. Pas de groupe de concurrence unique : un groupe n'admet qu'un run actif et un en attente et annule le suivant.
  Le plafond vaut par run de workflow : pendant le pilote, un seul dispatch à la fois (liste figée de T-322). Le groupe
  par issue (`claude-agent-issue-<n>`, sans annulation) évite deux agents sur la même issue.
- **Quota** : les valeurs de coût sont des estimations côté client, pas la facture ; aucun solde d'abonnement n'est lu
  (NOT_PROVEN). Une clé API facturée au token exige un plafond mensuel Console (geste MANDAT de Paul). Aucun euro par
  agent n'est promis.
