---
owner: coordinateur (Paul valide)
updated: 2026-11-18
review_days: 7
---
# STATE — openchoreo-lab

<!-- GABARIT. Réécrit (jamais en ajout) à chaque jalon par le coordinateur, seul rédacteur. Max 60 lignes / 6 Ko, vérifié par tools/context-check. Historique et détails : docs/state/journal/AAAA-MM-JJ.md (une ligne par événement, ajout seul) et docs/proofs/. Les valeurs et chemins de preuve ci-dessous illustrent le format (état du 2026-11-18 condensé) ; les fichiers `docs/proofs/…` cités sont indicatifs. Aucun secret, aucun chemin privé. -->

**Objectif** : IDP OpenChoreo 1.3.3 utilisable sur OKE `oracle-a1` ; une intention en langage naturel devient une app livrée par PR, avec preuve runtime datée.
**Phase** : golden path n°2 (stateless interne) + IDP utilisable. **Reprise sans mémoire** : lire ce fichier, puis `docs/state/journal/` (2 derniers jours).

## Jalons (une ligne chacun : statut · date · preuve)
| Jalon | Statut | Date (Z) | Preuve |
|---|---|---|---|
| OKE étapes 0-5 (préflight, ns, Gateway API, cert-manager, ESO, kgateway) | PASS | 2026-11-17 | `docs/proofs/oke-steps-0-5.md` |
| OKE étapes 6-9 + 11 (control plane, data plane, types, Argo) | PASS | 2026-11-17 | `docs/proofs/oke-steps-6-11.md` |
| Pilote `whoami` sur OKE (déploiement, modification, rollback par PR #23, #24, #25) | PASS | 2026-11-17 23:15 | `docs/proofs/whoami-oke.md` |
| 6b portail Backstage · 10 CNPG `lab-pg` | NOT_TESTED · NON AUTORISÉ | — | — |
| Résidu `B6-sa-effective` (SA `kgateway`, Secrets cluster-wide) | FAIL accepté, en traitement | 2026-11-17 | `docs/proofs/b6-sa-effective.md` |

## Prochaines actions (ordre ; une ligne chacune ; identifiant de ticket)
1. `ntfy` interne sans PVC par `add-app` (archétype A) : issue #__ .
2. Traiter le résidu kgateway avant tout credential réel : issue #__ .
3. Portail Backstage privé (port-forward) puis rôles MCP distincts : issues #__ .

## Bloquants et décisions humaines (noms seulement, jamais de valeur)
- Paul : fusion kube-ops #1629 et #1630 ; clients Authentik ; volume OCI 50 Go (NON donné, ne pas supprimer les 2 volumes orphelins).
- Paul : décisions D1-D3 de `docs/research/context-engineering/CONTEXT-ENGINEERING.md` §8.

## Flux actifs (ne pas relancer un flux déjà livré)
| Flux | Statut | Rendu attendu |
|---|---|---|
| IDP utilisable (`feat/idp-usable`) | PR DRAFT, statique seulement | rien d'exécuté sur OKE |

## Pièges connus
- Image toujours qualifiée `docker.io/…` (CRI-O OKE refuse les noms courts).
- `git revert` ne doit jamais supprimer les releases historiques (job CI `release-history`).
- Un point de sécurité amont est en coordination privée : ne publier AUCUN détail ici.

## Accès et exécution
Un seul exécutant sur OKE (le coordinateur) ; les agents n'ont ni kubeconfig ni bastion. Procédure d'accès : handoff privé hors dépôt. Écritures : `AGENTS.md` règles 2 et 6.

## Où trouver quoi
Contrat `docs/APP-CONTRACT.md` · archétypes `golden-paths/` · skills `.agents/skills/` · mission et mandats `missions/MISSION.md` · décisions `docs/adr/` · scripts OKE `tools/oke/` · preuves `docs/proofs/`.
