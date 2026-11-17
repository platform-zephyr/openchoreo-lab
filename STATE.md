# STATE — OpenChoreo Lab (reprise après interruption)

Dernière mise à jour : 2026-11-17 ~19:00Z. Lire ensuite `missions/MISSION.md`. Aucune mémoire de conversation n'est requise.
Objectif : un IDP OpenChoreo 1.3.3 RÉELLEMENT utilisable sur le cluster OKE `oracle-a1` : un agent utilise le portail et les API pour déployer un service par PR GitOps, puis prouve qu'il fonctionne.
Règle de preuve : PASS = preuve runtime datée. `k3d` ≠ OKE. Statique ≠ runtime. NOT_TESTED / BLOCKED ne sont jamais des PASS.

## Accès OKE (un seul exécutant : le coordinateur)
- Session bastion OUVERTE le 2026-11-17 ~18:21Z avec l'accord de Paul (TTL 3 h, expire ≤ 21:21Z). Kubeconfig : `~/.cache/oke-access/kubeconfig` (0600, contexte `context-oracle-a1-*`, jamais `admin@homeops`). Fermeture : `bash <notes>/idp/agents/open-oke-access.sh close`. Réouverture : `… open 10800` (accord de Paul déjà donné pour ce mandat ; le script est dans `…/side-session-notes/local_35b37a0a-…/idp/agents/`).
- Les agents parallèles N'ONT PAS accès à OKE (consigne explicite dans chaque brief).
- Cluster : K8s v1.36.4, 1 nœud arm64, allocatable réel 1830m CPU / 8,4 GiB (pas 2 OCPU / 12 Go), Cilium 1.20.4 chaining, VAP baseline x3, CCNP `deny-imds` + `allow-egress-unisolated` (de kube-ops #1620, non mergée). Pas d'Argo/Authentik/pg-shared sur OKE.

## Étapes OKE (docs/PHASE-B.md ; `tools/oke/install.sh --step N --apply`, `verify.sh --step N`)
| Étape | Statut | Preuve |
|---|---|---|
| 0 préflight | PASS 2026-11-17 18:21Z | GO, rien modifié |
| 1 namespaces/quotas/NP | PASS | verify B1 FAIL=0 (18:23Z), admission refuse pod privilégié |
| 2 Gateway API v1.5.1 | PASS | verify B2 |
| 3 cert-manager | PASS | verify B3 |
| 4 ESO + ClusterSecretStore lab-store | PASS | verify B4 |
| 5 kgateway v2.3.11 | PASS | verify B5 |
| 6 control plane OpenChoreo | **EN ATTENTE** (remédiation des 3 bloquants de la revue) | — |
| 7-9 VAP, data plane, ClusterDataPlane, types | EN ATTENTE | — |
| 10 CNPG + lab-pg | **NON AUTORISÉ** (volume OCI 50 Go) | `--confirm-storage` jamais sans accord de Paul |
| 11 Argo CD | EN ATTENTE | — |
Mesures réelles après étapes 1-5 (18:31Z, méthode corrigée : MAX de 3 échantillons) : usage pile 3-5m CPU / 135 Mi ; requests de tous les pods 385m/1830m (21 %) et 1038Mi/8650Mi (12 %) ; seuil 70 %. Les lignes « 0m/0Mi » de budget.log pour 3-5 sont INVALIDES (bug corrigé par PR #4).

## Security bundle (temporaire, privé)
Étapes 6, 6b, 7, 10 : `install.sh` exige le security bundle épinglé par `security/bundle.lock` (sinon arrêt avant toute écriture). Obtention, vérification, rollback, plan de retrait : `docs/SECURITY-BUNDLE.md`. Étape 12 intégrée à l'étape 7. Tests : `tests/security-bundle/run.sh`.

## Sécurité réseau (preuves runtime OKE, tests `verify.sh --security`)
- IMDS : PASS (timeout :80, DNS :53 répond). Intra-namespace : PASS. Nettoyage `lab-netcontrol` : PASS (PR #5).
- **Egress isolé : BLOCKED (C1)** : l'allow-all `allow-egress-unisolated` neutralise le default-deny de nos namespaces. Aucune garantie réseau n'est acquise. Correctif : kube-ops PR brouillon **#1629** (exclut les namespaces `platform.smadja.dev/egress-isolated=true` ; ne fusionne pas #1620). Plan exécuté (lecture seule) : 7 namespaces concernés. Test `all` + rollback à exécuter sur OKE (script `tests/oke-baseline/c1-egress-isolation.sh` de la PR #1629).

## PR openchoreo-lab
Mergées : #1 socle, #2 apps, #3 pack Phase B, #4 budget/capacité/tests réseau, #5 nettoyage, #6 identité/authz/MCP/revue. `main` protégé (ruleset `main-protection` : PR + check `ci-ok`).

## Flux parallèles (agents sans accès OKE ; périmètres de fichiers distincts)
| Flux | Statut |
|---|---|
| Intégration (remédiation revue + values portail/Authentik) : tools/oke, platform/install, platform/policies, platform/portal, docs/PHASE-B.md, PORTAL.md | EN COURS |
| Boucle GitOps whoami sur k3d (tests/gitops-k3d) | EN COURS |
| RBAC cluster-agent moindre privilège (platform/cluster-agent, tests/rbac) | EN COURS (phase 1 sur SA clone ; phase 2 sur ordre du coordinateur) |
| Authz+MCP (platform/authz, tests/mcp) : 50 PASS k3d | LIVRÉ (PR #6) |
| Identité Authentik (platform/identity) | LIVRÉ en brouillon (PR #6) ; PR kube-ops à préparer |
| Portail (platform/portal, docs/PORTAL.md) | LIVRÉ en brouillon ; à intégrer |
| Revue indépendante (docs/REVIEW-PHASE-B.md) | LIVRÉE : 27 constats (3 bloquants) |
| Correctif C1 (kube-ops #1629) | PR brouillon ouverte |

## Bloquants de sécurité avant étape 6/7 (docs/REVIEW-PHASE-B.md)
1. cluster-agent : RBAC `*` sur secrets, `pods/exec` cluster-wide, VAP-1 sans CONNECT → remédiation en cours (flux RBAC + intégration).
2. Désinstallation : `helm uninstall` supprime les CRD d'ESO/kgateway-crds (à vérifier chart par chart), rollback ne doit jamais recréer/supprimer un volume 50 Go → tester sur k3d avant OKE.
3. Périmètre : `cnpg-system` → renommer `lab-cnpg` ; AppProject Argo `lab` trop large (Namespace/VAP) → séparer bootstrap privilégié et GitOps applicatif.

## Autorisations de Paul (mandat du 2026-11-17, à lire avec missions/MISSION.md)
- OK : PR dans openchoreo-lab (intégration après CI/revue/tests) ; PR ciblées kube-ops (C1) et blueprints Authentik (PRÉPARER ; l'application en production reste soumise à vérification périmètre/impact/rollback) ; namespaces `dp-*` générés ; label `openchoreo.dev/control-plane=true` sur `default` SEULEMENT si OpenChoreo 1.3.3 l'exige.
- NON : volume PostgreSQL OCI 50 Go ; toute exposition publique ; migration Talos ; modification de kube-system/production/politiques cluster-wide sans vérification ; nouvelle étude comparative.

## Décision d'architecture
Authentik externe = unique issuer OIDC (pas ThunderID). Clients distincts : portail (login), service backend (catalogue), agent-reader, agent-operator, CLI. Limite acceptée du pilote : homelab éteint la nuit ⇒ login impossible ; inacceptable pour un IDP permanent.

## Ordre de livraison (ne pas sauter)
1 CP+DP OpenChoreo fonctionnels → 2 Authentik connecté + authz vérifiées → 3 portail Backstage accessible (chemin privé de test) → 4 catalogue réellement alimenté → 5 MCP avec identités distinctes → 6 golden path whoami de bout en bout par GitOps → 7 rollback démontré. Miniflux/PostgreSQL seulement après le cycle stateless prouvé.

## Prochaines actions exactes
1. Intégrer le rapport de l'agent d'intégration (vérifier AppProject, VAP, désinstallation, values CP) ; CI ; PR ; merge.
2. Exécuter sur OKE le test C1 (`plan` fait ; `backup`, `apply`, `test`, `rollback` mesuré, ré-`apply`).
3. Quand le flux GitOps k3d a fini : lancer la phase 2 du flux RBAC (bascule RBAC réel k3d + whoami).
4. Étapes 6 → 9 sur OKE (budget auto, `verify.sh --step N` après chaque étape), puis 11 (Argo) sans lab-pg.
5. PR kube-ops pour les blueprints Authentik (texte dans docs/IDENTITY.md) ; réutiliser une clé de signature Authentik existante si possible.

## Journal
- 2026-11-17 : PR #1-#6 ; accès bastion ouvert (accord Paul) ; étapes 1-5 OKE PASS ; C1 confirmé runtime ; revue indépendante ; 8 flux d'agents lancés.
