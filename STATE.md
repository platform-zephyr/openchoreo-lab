# STATE — OpenChoreo Lab (reprise après interruption)

Dernière mise à jour : 2026-11-17 ~19:45Z (mandat « finaliser OpenChoreo + stockage commun OKE/Talos »). Lire ensuite `missions/MISSION.md`. Aucune mémoire de conversation n'est requise.
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
| 6 control plane OpenChoreo | **EN ATTENTE** : installer avec un RBAC du control plane sans lecture globale de Secrets (flux A1) | — |
| 7-9 VAP, data plane, ClusterDataPlane, types | EN ATTENTE | — |
| 10 CNPG + lab-pg | **NON AUTORISÉ** (volume OCI 50 Go) | `--confirm-storage` jamais sans accord de Paul |
| 11 Argo CD | EN ATTENTE | — |
Mesures réelles après étapes 1-5 (18:31Z, méthode corrigée : MAX de 3 échantillons) : usage pile 3-5m CPU / 135 Mi ; requests de tous les pods 385m/1830m (21 %) et 1038Mi/8650Mi (12 %) ; seuil 70 %. Les lignes « 0m/0Mi » de budget.log pour 3-5 sont INVALIDES (bug corrigé par PR #4).

## Sécurité réseau (preuves runtime OKE, tests `verify.sh --security`)
- IMDS : PASS (timeout :80, DNS :53 répond). Intra-namespace : PASS. Nettoyage `lab-netcontrol` : PASS (PR #5).
- **Egress isolé : BLOCKED (C1)** : l'allow-all `allow-egress-unisolated` neutralise le default-deny de nos namespaces. Aucune garantie réseau n'est acquise. Correctif : kube-ops PR brouillon **#1629** (exclut les namespaces `platform.smadja.dev/egress-isolated=true` ; ne fusionne pas #1620). Plan exécuté (lecture seule) : 7 namespaces concernés. Test `all` + rollback à exécuter sur OKE (script `tests/oke-baseline/c1-egress-isolation.sh` de la PR #1629).

## PR
openchoreo-lab mergées : #1 socle, #2 apps, #3 pack Phase B, #4 budget/capacité/tests réseau, #5 nettoyage, #6 identité/authz/MCP/revue, #7 état. `main` protégé (ruleset : PR + `ci-ok`).
**#8 (remédiation revue + values Authentik/portail) : OUVERTE, CI verte (8/8 jobs dont `platform`), NON MERGÉE** : Paul exige des preuves sur un vrai API server/Argo (flux A2, A3) avant fusion. Bloquants P1 (Argo), P2, P3 corrigés statiquement ; preuves runtime en cours.
kube-ops (brouillons, non mergés) : **#1629** correctif C1 (CCNP `allow-egress-unisolated` exclut les namespaces `platform.smadja.dev/egress-isolated=true`), **#1630** blueprints Authentik (clients distincts, clé de signature existante réutilisée). L'état vivant d'OKE diverge de Git tant que #1629 n'est pas fusionnée (source de vérité à clarifier : une seule propriétaire de la CCNP).

## Flux (agents sans accès OKE ; un seul exécutant OKE = coordinateur)
| Flux | Cluster k3d | Statut |
|---|---|---|
| GitOps whoami k3d (tests/gitops-k3d) | `openchoreo` (partagé) | EN COURS (long) |
| A1 Isolation des Secrets (cluster-agent ET control plane) : analyse, correctif, tests | `lab-sec-a1` | EN COURS |
| A2 preuve négative Argo (projets lab-apps/lab-platform/lab-authz/lab-root/default verrouillé) | `lab-sec-argo` | EN COURS |
| A3 VAP CEL sur vrai API server + helm uninstall CRD + rollback | `lab-sec-vap` | EN COURS |
| Stockage OKE/Talos (docs/storage, tests/storage : recherche seule, aucun accès cluster) | — | EN COURS |
| RBAC cluster-agent phase 1 (SA clone) | — | LIVRÉ, NON COMMITÉ ; phase 2 à lancer après GitOps k3d |
| Portail, identité, authz/MCP | — | LIVRÉS (PR #6) ; portail/Authentik NON connectés (secrets clients = credentials de production) |

## Constats de sécurité ouverts (ne pas déclarer le modèle d'isolation sûr)
- **Isolation des Secrets (CRITIQUE, en coordination privée avec l'amont)** : un point de sécurité sur les droits de lecture des Secrets de composants OpenChoreo est en cours de traitement ; les détails ne sont volontairement PAS publiés dans ce dépôt (signalement privé en cours, dossier hors dépôt). Règle : AUCUN credential externe réel (secret client Authentik, tokens) dans un environnement accessible à ces composants tant que l'isolation n'est pas prouvée.
- C1 : prouvé sur OKE pour les 7 namespaces d'essai ; `dp-*` pas encore labellisés `egress-isolated` (à corriger dans le CPT `cell-restricted` + tests de trafic).

## Stockage OKE (audit lecture seule 2026-11-17 19:35Z : docs/storage/OKE-AUDIT-2026-11-17.md)
Aucun PV/PVC. StorageClass `oci-bv` (défaut, WaitForFirstConsumer, expansion OUI), `oci`. 2 Block Volumes `csi-…` de 50 Go AVAILABLE non attachés (restes de drills : ne jamais les supposer libres) + boot 50 Go = 150/200 Go ⇒ un seul PVC de 50 Go possible, NON autorisé. Disque éphémère du nœud ≈ 28 GB.

## Bloquants de sécurité avant étape 6/7 (docs/REVIEW-PHASE-B.md)
1. cluster-agent : moindre privilège du RBAC et VAP-1 (CONNECT/sous-ressources) → remédiation en cours (flux RBAC + intégration).
2. Désinstallation : `helm uninstall` supprime les CRD d'ESO/kgateway-crds (à vérifier chart par chart), rollback ne doit jamais recréer/supprimer un volume 50 Go → tester sur k3d avant OKE.
3. Périmètre : `cnpg-system` → renommer `lab-cnpg` ; AppProject Argo `lab` trop large (Namespace/VAP) → séparer bootstrap privilégié et GitOps applicatif.

## Autorisations de Paul (mandat du 2026-11-17, à lire avec missions/MISSION.md)
- OK : PR dans openchoreo-lab (intégration après CI/revue/tests) ; PR ciblées kube-ops (C1) et blueprints Authentik (PRÉPARER ; l'application en production reste soumise à vérification périmètre/impact/rollback) ; namespaces `dp-*` générés ; label `openchoreo.dev/control-plane=true` sur `default` SEULEMENT si OpenChoreo 1.3.3 l'exige.
- NON : volume PostgreSQL OCI 50 Go ; toute exposition publique ; migration Talos ; modification de kube-system/production/politiques cluster-wide sans vérification ; nouvelle étude comparative.

## Décision d'architecture
Authentik externe = unique issuer OIDC (pas ThunderID). Clients distincts : portail (login), service backend (catalogue), agent-reader, agent-operator, CLI. Limite acceptée du pilote : homelab éteint la nuit ⇒ login impossible ; inacceptable pour un IDP permanent.

## Ordre de livraison (ne pas sauter)
1 CP+DP OpenChoreo fonctionnels → 2 Authentik connecté + authz vérifiées → 3 portail Backstage accessible (chemin privé de test) → 4 catalogue réellement alimenté → 5 MCP avec identités distinctes → 6 golden path whoami de bout en bout par GitOps → 7 rollback démontré. Miniflux/PostgreSQL seulement après le cycle stateless prouvé.

## Prochaines actions exactes (mandat du 2026-11-17 soir)
0. Séquence: preuves A1/A2/A3 → merge #8 → étapes OKE 6→9 (CP avec RBAC scoped, DP avec cluster-agent corrigé) → Argo (étape 11, sans lab-pg) → whoami E2E sur OKE (intention → app.yaml → appgen → PR → CI → merge → Argo → OpenChoreo → Ready → HTTP 200 → rollback Git) → portail/Authentik/MCP (après correction LIST) → Miniflux (PostgreSQL non autorisé : 50 Go OCI). Stockage : recommandation en parallèle, sans bloquer.
(Anciennes actions ci-dessous : à lire avec ce qui précède.)
1. Intégrer le rapport de l'agent d'intégration (vérifier AppProject, VAP, désinstallation, values CP) ; CI ; PR ; merge.
2. Exécuter sur OKE le test C1 (`plan` fait ; `backup`, `apply`, `test`, `rollback` mesuré, ré-`apply`).
3. Quand le flux GitOps k3d a fini : lancer la phase 2 du flux RBAC (bascule RBAC réel k3d + whoami).
4. Étapes 6 → 9 sur OKE (budget auto, `verify.sh --step N` après chaque étape), puis 11 (Argo) sans lab-pg.
5. PR kube-ops pour les blueprints Authentik (texte dans docs/IDENTITY.md) ; réutiliser une clé de signature Authentik existante si possible.

## Journal
- 2026-11-17 19:45Z : nouveau mandat ; audit stockage OKE ; constat de sécurité (coordination privée) ; 4 flux de sécurité/stockage lancés ; PR #8 gardée ouverte.
- 2026-11-17 : PR #1-#6 ; accès bastion ouvert (accord Paul) ; étapes 1-5 OKE PASS ; C1 confirmé runtime ; revue indépendante ; 8 flux d'agents lancés.
