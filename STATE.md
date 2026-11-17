# STATE — OpenChoreo Lab (HANDOFF / reprise sans mémoire conversationnelle)

Dernière mise à jour : 2026-11-17 ~20:45Z. Lire ensuite `missions/MISSION.md` (règles et autorisations de Paul).
**Objectif** : un IDP OpenChoreo 1.3.3 réellement utilisable sur le cluster OKE `oracle-a1` ; premier jalon attendu = un service `whoami` créé et livré de bout en bout PAR la plateforme (intention → app.yaml → appgen → PR → CI → merge → Argo CD → OpenChoreo → pod Ready → HTTP 200 → modification → rollback Git), avec PREUVE RUNTIME DATÉE sur OKE (pas seulement k3d). Pas de nouvelle étude.
**Règle de preuve** : PASS = preuve runtime datée. k3d ≠ OKE. Statique ≠ runtime. NOT_TESTED / BLOCKED ne sont jamais des PASS.

## 1. Où on en est (en une minute)
- OKE : étapes 1-5 installées et vérifiées (namespaces/quotas/NP, Gateway API, cert-manager, ESO+`lab-store`, kgateway). Correctif réseau C1 appliqué sur le cluster et prouvé. **Rien d'autre** n'est installé (ni control plane, ni data plane, ni Argo, ni Backstage, ni Kyverno, ni Authentik, ni PostgreSQL).
- k3d (jetable) : boucle `whoami` prouvée (18 PASS/6 FAIL, défauts corrigés statiquement depuis), preuves Argo réel (20 PASS), VAP/uninstall sur vrai API server (91+59 PASS), authz/MCP (50 PASS).
- **Bloqué avant OKE** : (a) la PR #8 n'est pas fusionnée (elle doit embarquer l'installation FAIL-CLOSED par « security bundle » privé) ; (b) phase 2 k3d du durcissement RBAC en cours ; (c) l'image du contrôleur corrigé doit atteindre OKE (registre privé : peut exiger un jeton de lecture de Paul).
- Un point de sécurité amont est en **coordination privée** : ne publie AUCUN détail dans ce dépôt public. Fichiers de sécurité locaux exclus de git (`.git/info/exclude`) ; dossier privé et handoff privé : `/Users/paul/Library/Application Support/Claude/side-session-notes/local_35b37a0a-e0e8-4d8a-9e10-404bff013ad6/openchoreo-lab/security-private/HANDOFF-PRIVATE.md`. Dépôt privé du bundle : `platform-zephyr/openchoreo-lab-security` (clone local `/Users/paul/Developer/Perso/openchoreo-lab-security`).

## 2. Accès OKE (un seul exécutant : le coordinateur ; les agents n'y ont pas accès)
- Session bastion ouverte le 2026-11-17 ~20:06Z avec l'accord de Paul (TTL 3 h → expire ~23:06Z). Kubeconfig `~/.cache/oke-access/kubeconfig`, contexte `context-oracle-a1-*` (jamais `admin@homeops`).
- Fermer/rouvrir : `bash "<notes>/idp/agents/open-oke-access.sh" close` puis `open 10800` (`<notes>` = `/Users/paul/Library/Application Support/Claude/side-session-notes/local_35b37a0a-e0e8-4d8a-9e10-404bff013ad6`). **Piège** : si le tunnel répond « Permission denied » juste après `open` (propagation de la clé), attendre ~20 s et relancer seulement le tunnel avec la commande SSH de `oci bastion session get … ssh-metadata.command` (voir le script).
- Cluster : K8s v1.36.4, 1 nœud arm64, allocatable réel 1830m CPU / 8,4 GiB (pas 2 OCPU/12 Go), 35 pods max, disque éphémère ≈ 28 GB. Cilium 1.20.4 en chaining ; baseline kube-ops (VAP baseline x3 + CCNP `deny-imds` et `allow-egress-unisolated`) ; **la CCNP `allow-egress-unisolated` vivante est MODIFIÉE** (exclut les namespaces `platform.smadja.dev/egress-isolated=true`) : correctif = kube-ops PR brouillon #1629 (non fusionnée : l'état vivant diverge de Git ; ne pas créer deux propriétaires de la CCNP).

## 3. Étapes OKE (`tools/oke/install.sh --step N --apply`, `verify.sh --step N` ; dry-run par défaut)
| Étape | Statut |
|---|---|
| 0 préflight, 1 namespaces/quotas/NP, 2 Gateway API v1.5.1, 3 cert-manager, 4 ESO+lab-store, 5 kgateway v2.3.11 | **PASS** (2026-11-17 18:21-18:34Z) |
| Réseau : IMDS refusé ; intra-namespace ; egress isolé en timeout avec témoin ouvert après correctif C1 ; rollback CCNP 23 s | **PASS** (19:00-19:06Z, 7 namespaces d'essai ; `dp-*` PAS encore couverts) |
| 6 control plane, 6b portail, 7 data plane, 8 ClusterDataPlane, 9 types/pipeline | **À FAIRE** : uniquement via l'installation fail-closed (bundle) |
| 10 CNPG + lab-pg | **NON AUTORISÉ** (volume OCI 50 Go) |
| 11 Argo CD | À FAIRE (projets lab-root / lab-platform / lab-apps / lab-authz, `default` verrouillé) |
Mesures OKE (18:31Z, méthode MAX de 3 échantillons) : requests de tous les pods 385m/1830m (21 %), 1038Mi/8650Mi (12 %) ; seuil dur 70 % ; budget OpenChoreo = objectif ≤ 1,5 GiB et ≤ 0,3 vCPU. Les lignes `0m/0Mi` de `budget.log` des étapes 3-5 sont INVALIDES (bug corrigé).

## 4. PR et branches
- openchoreo-lab `main` protégé (ruleset : PR + `ci-ok`, **0 approbation** : n'est PAS une frontière de sécurité). Mergées : #1-#7, #9-#15 (+ le présent handoff).
- **PR #8 `feat/oke-remediation-cp-values`** : OUVERTE, CI verte (tête `30ecead`). Contient : remédiation de la revue (P1-P3), VAP corrigées par un vrai API server, projets Argo séparés (preuve 20 PASS), `uninstall.sh` sûr, corrections appgen/contrat (137 tests), preuves GitOps k3d. **À FUSIONNER SEULEMENT après** intégration de l'installation fail-closed (voir §6) — sinon `install.sh` sur `main` pourrait installer le chart non corrigé.
- kube-ops (brouillons, NON mergés, décisions de Paul) : #1629 (correctif C1), #1630 (blueprints Authentik, clé de signature existante réutilisée). Worktrees temporaires créés dans kube-ops : `…/scratchpad/ko-c1`, `…/scratchpad/ko-authentik` (à retirer : `git -C kube-ops worktree remove …`).
- Dépôt privé `platform-zephyr/openchoreo-lab-security` : bundle de sécurité (en cours de construction).

## 5. Flux d'agents (sans accès OKE ; périmètres de fichiers distincts ; ils rendent compte par notification à la session coordinatrice)
| Flux | Statut |
|---|---|
| Phase 2 k3d partagé `openchoreo` : RBAC strict + contrôleur corrigé + post-renderer + whoami sous moindre privilège + permissions effectives après install/upgrade | EN COURS (fichiers locaux uniquement, ne rien publier) |
| Security bundle minimal et temporaire (dépôt privé, `security/bundle.lock`, `helm_secure`, refus de rollback non durci, tests de refus) | EN COURS |
| A2 Argo (20 PASS), A3 VAP+uninstall (91+59 PASS), GitOps whoami k3d, corrections générateur (137 tests), Kyverno statique (97 tests CLI), architecture, étude stockage, étude migration Authentik | LIVRÉS et intégrés |
Ne pas relancer de flux déjà livrés ; vérifier `ListAgents` d'abord.

## 6. Prochaines actions EXACTES (dans l'ordre)
1. Attendre les rapports (phase 2 ; bundle). Quand le bundle est prêt : vérifier que le diff PUBLIC est neutre (grep des mots sensibles), `git add` seulement `tools/oke/security-bundle.sh`, `tools/oke/install.sh`, `tools/oke/verify.sh`, `security/`, `docs/SECURITY-BUNDLE.md`, `tests/security-bundle/`, pousser sur la branche PR #8, CI verte, **fusionner #8 (squash)**.
2. Hygiène du working tree AVANT de fusionner/tirer `main` : des fichiers non suivis dupliquent des fichiers déjà sur `main` (docs/architecture, docs/identity-migration, docs/storage, docs/KYVERNO-POLICY-CONTRACT.md, platform/kyverno, tests/kyverno, tests/storage, clusters/README.md) → les supprimer localement (ils sont sur `main`) puis `git fetch && git merge --ff-only origin/main`.
3. Étapes OKE 6 → 9 puis 11 (sans 10) avec `install.sh` fail-closed, budget automatique, `verify.sh --step N` après chaque étape (preuves datées). Revérifier le gate dans `…/idp/agents/OKE-EXEC.md` avant d'agir. Rouvrir le bastion si besoin (§2).
4. Passer `lab-apps` en synchro automatique (`automated: {prune: false, selfHeal: true}`, `allowEmpty: true` seulement pour lab-apps) par petite PR, après validation k3d (APP-CONTRACT §5-§6).
5. **whoami sur OKE** : `app.yaml` → `appgen render/check` → PR → CI → merge → Argo → OpenChoreo → pod Ready → HTTP 200 → modification (replicas/version) → `git revert` → état restauré ; identifiants FACTICES tant que l'isolation n'est pas validée ; ne déployer ni Miniflux ni d'autres apps avant ce PASS.
6. Ensuite : portail Backstage (accès privé par port-forward), Authentik (clients distincts, créés par Paul), MCP avec rôles distincts (platform/authz/, tests/mcp/) — AUCUN credential externe réel avant validation de l'isolation.

## 7. Décisions humaines (strictement nécessaires, à l'heure actuelle)
- Registre de l'image du contrôleur corrigé : jeton de LECTURE d'un package privé ghcr (geste de Paul) ou package public après coordination amont.
- Fusion de kube-ops #1629 (C1) et #1630 (Authentik) ; puis création des clients/secrets côté Authentik de production (Paul).
- Autorisation d'un volume OCI de 50 Go (PostgreSQL/lab-pg) : NON donnée ; les 2 volumes orphelins de 50 Go (docs/storage/OCI-ORPHAN-VOLUMES.md) ne sont PAS à supprimer sans identification certaine.
- Option : exiger une revue humaine sur `platform/**` (ruleset) ; mettre le dépôt en privé le temps de la coordination ; second nœud A1 PAYG (docs/architecture/DECISIONS-OPEN.md).

## 8. Où trouver quoi
Contrat applicatif : `docs/APP-CONTRACT.md`, `tools/appgen/`, `apps/`, `generated/` ; golden paths et skills agents : `golden-paths/`, `.agents/skills/` ; pack OKE : `docs/PHASE-B.md`, `platform/install/`, `tools/oke/` ; preuves : `tests/k3d/`, `tests/gitops-k3d/`, `tests/argo-escalation/`, `tests/vap/`, `tests/uninstall-k3d/`, `tests/mcp/`, `docs/GITOPS-PROOF.md`, `docs/ARGO-ESCALATION.md`, `docs/GITOPS-TRUST-BOUNDARY.md`, `docs/VAP-UNINSTALL-PROOF.md` ; architecture/stockage/identité : `docs/architecture/`, `docs/storage/`, `docs/identity-migration/`, `docs/IDENTITY.md` ; Kyverno : `platform/kyverno/`, `docs/KYVERNO-POLICY-CONTRACT.md`.
Environnement local : Colima profil `openchoreo` (`DOCKER_CONTEXT=colima-openchoreo`, ~8 GiB, limite inotify basse : `sudo sysctl -w fs.inotify.max_user_instances=512` pour un kubelet k3d), k3d `openchoreo` (KUBECONFIG `/private/tmp/claude-501/-Users-paul-Desktop-perso/775067df-86e8-413f-97d7-8573a60947a2/scratchpad/openchoreo/kubeconfig`), venv Python des tests `…/scratchpad/venv`, worktree de coordination `…/scratchpad/wt-coord`. Helm 4.1.3 (les post-renderers sont des PLUGINS en Helm 4).
