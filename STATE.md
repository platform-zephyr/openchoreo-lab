# STATE — OpenChoreo Lab (HANDOFF / reprise sans mémoire conversationnelle)

Dernière mise à jour : 2026-11-17 ~20:45Z. Lire ensuite `missions/MISSION.md` (règles et autorisations de Paul).
**Objectif** : un IDP OpenChoreo 1.3.3 réellement utilisable sur le cluster OKE `oracle-a1` ; premier jalon attendu = un service `whoami` créé et livré de bout en bout PAR la plateforme (intention → app.yaml → appgen → PR → CI → merge → Argo CD → OpenChoreo → pod Ready → HTTP 200 → modification → rollback Git), avec PREUVE RUNTIME DATÉE sur OKE (pas seulement k3d). Pas de nouvelle étude.
**Règle de preuve** : PASS = preuve runtime datée. k3d ≠ OKE. Statique ≠ runtime. NOT_TESTED / BLOCKED ne sont jamais des PASS.

## 1. Où on en est (en une minute)
- OKE (preuves runtime 2026-11-17/18, `verify.sh`) : étapes 1-5, **6 control plane** (21:47Z), **7 data plane** (21:51Z, agent à portée réduite aux `dp-*`), **8 ClusterDataPlane** (21:56Z, agent connecté), **9 types/pipeline** (21:59Z), **11 Argo CD** (22:01Z, `default` verrouillé) : PASS. Installation fail-closed par security bundle 1.0.1. Résidu accepté : `B6-sa-effective` FAIL = SA `kgateway` (Secrets cluster-wide), traitement en cours (flux kgateway). 6b (Backstage) et 10 (CNPG/lab-pg, volume OCI) NON faits. `lab-platform` volontairement non synchronisé (il inclut lab-pg).
- **Pilote whoami sur OKE = PASS fonctionnel** : baseline HTTP 200 (22:27Z, 29 PASS, 0 PVC/LB/route externe, port-forward local) ; modification GitOps `WHOAMI_NAME` via PR #23 (Argo rev 8ae9c9a, release whoami-69a1749676, réponse `Name: whoami-gitops-oke-v2`, 22:45Z) ; rollback par PR de revert #24 (23:04Z : release d'origine whoami-647fc6bfc1, même UID de ComponentRelease, `Name:` disparu, HTTP 200). Drift Argo post-revert fermé par PR #25 (release historique restaurée + job CI `release-history`) : `lab-apps` Synced/Healthy (23:15Z). Leçons : image DOIT être qualifiée `docker.io/…` (CRI-O OKE refuse les noms courts) ; un `git revert` ne doit pas supprimer les releases historiques.
- k3d (jetable) : boucle `whoami` prouvée (18 PASS/6 FAIL, défauts corrigés statiquement depuis), preuves Argo réel (20 PASS), VAP/uninstall sur vrai API server (91+59 PASS), authz/MCP (50 PASS).
- **Plus de blocage OKE.** Prochaine phase : golden path n°2 stateless (ntfy interne, sans PVC), IDP utilisable (Backstage privé, Authentik, MCP, rôles agents), résidu kgateway avant tout credential réel.
- Un point de sécurité amont est en **coordination privée** : ne publie AUCUN détail dans ce dépôt public. Fichiers de sécurité locaux exclus de git (`.git/info/exclude`). **Handoff privé (hors dépôt)** : le retrouver avec `find ~/Library/Application\ Support/Claude -name HANDOFF-PRIVATE.md 2>/dev/null` (ne jamais en copier le contenu ici). Dépôt privé du bundle : `platform-zephyr/openchoreo-lab-security` (clone local à côté de ce dépôt ; `gh repo view` pour vérifier l'accès).

## 1b. Agents cloud (décisions de Paul, 2026-11-18)
Backlog = `backlog/` dans ce dépôt (ADR-0012 ; pas Linear ; une issue GitHub seulement pour lancer un agent). ADR 0001-0014 PROPOSÉS dans `docs/adr/` (PR #48). Dev et prod = Environments OpenChoreo sur le même OKE, dev frugal. MCP joignable par Cloudflare Tunnel + Access (exception unique). Modèle et gestes de Paul : `docs/CLOUD-AGENTS.md`. Doc, ADR et backlog seulement : rien n'est exécuté sur OKE pour ce modèle.

## 2. Accès OKE (un seul exécutant : le coordinateur ; les agents n'y ont pas accès)
- Session bastion ouverte le 2026-11-17 ~20:06Z avec l'accord de Paul (TTL 3 h → expire ~23:06Z). Kubeconfig temporaire généré par le script d'accès (emplacement : handoff privé), contexte `context-oracle-a1-*` (jamais `admin@homeops`).
- Fermer/rouvrir : script `open-oke-access.sh` de l'agent OKE (emplacement : handoff privé) avec `close` puis `open 10800`. **Piège** : si le tunnel répond « Permission denied » juste après `open` (propagation de la clé), attendre ~20 s et relancer seulement le tunnel avec la commande SSH de `oci bastion session get … ssh-metadata.command` (voir le script).
- Cluster : K8s v1.36.4, 1 nœud arm64, allocatable réel 1830m CPU / 8,4 GiB (pas 2 OCPU/12 Go), 35 pods max, disque éphémère ≈ 28 GB. Cilium 1.20.4 en chaining ; baseline kube-ops (VAP baseline x3 + CCNP `deny-imds` et `allow-egress-unisolated`) ; **la CCNP `allow-egress-unisolated` vivante est MODIFIÉE** (exclut les namespaces `platform.smadja.dev/egress-isolated=true`) : correctif = kube-ops PR brouillon #1629 (non fusionnée : l'état vivant diverge de Git ; ne pas créer deux propriétaires de la CCNP).

## 3. Étapes OKE (`tools/oke/install.sh --step N --apply`, `verify.sh --step N` ; dry-run par défaut)
| Étape | Statut |
|---|---|
| 0 préflight, 1 namespaces/quotas/NP, 2 Gateway API v1.5.1, 3 cert-manager, 4 ESO+lab-store, 5 kgateway v2.3.11 | **PASS** (2026-11-17 18:21-18:34Z) |
| Réseau : IMDS refusé ; intra-namespace ; egress isolé en timeout avec témoin ouvert après correctif C1 ; rollback CCNP 23 s | **PASS** (19:00-19:06Z, 7 namespaces d'essai ; `dp-*` PAS encore couverts) |
| 6 control plane, 7 data plane, 8 ClusterDataPlane, 9 types/pipeline | **PASS** (2026-11-17 21:47–21:59Z, bundle 1.0.1) ; 6b portail : à faire |
| 10 CNPG + lab-pg | **NON AUTORISÉ** (volume OCI 50 Go) |
| 11 Argo CD | **PASS** (22:01Z ; lab-root Synced ; lab-apps automatique limité à whoami ; lab-platform manuel) |
Mesures OKE (18:31Z, méthode MAX de 3 échantillons) : requests de tous les pods 385m/1830m (21 %), 1038Mi/8650Mi (12 %) ; seuil dur 70 % ; budget OpenChoreo = objectif ≤ 1,5 GiB et ≤ 0,3 vCPU. Les lignes `0m/0Mi` de `budget.log` des étapes 3-5 sont INVALIDES (bug corrigé).

## Security bundle (temporaire, privé)
Étapes 6, 6b, 7, 10 : `install.sh` exige le security bundle épinglé par `security/bundle.lock` (sinon arrêt avant toute écriture). Obtention, vérification, rollback, plan de retrait : `docs/SECURITY-BUNDLE.md`. Étape 12 intégrée à l'étape 7. Tests : `tests/security-bundle/run.sh`.

## 4. PR et branches
- openchoreo-lab `main` protégé (ruleset : PR + `ci-ok`, **0 approbation** : n'est PAS une frontière de sécurité). Mergées : #1-#7, #9-#15 (+ le présent handoff).
- **PR #8 `feat/oke-remediation-cp-values`** : OUVERTE, CI verte (tête `30ecead`). Contient : remédiation de la revue (P1-P3), VAP corrigées par un vrai API server, projets Argo séparés (preuve 20 PASS), `uninstall.sh` sûr, corrections appgen/contrat (137 tests), preuves GitOps k3d. **À FUSIONNER SEULEMENT après** intégration de l'installation fail-closed (voir §6) — sinon `install.sh` sur `main` pourrait installer le chart non corrigé.
- kube-ops (brouillons, NON mergés, décisions de Paul) : #1629 (correctif C1), #1630 (blueprints Authentik, clé de signature existante réutilisée). Worktrees temporaires créés dans kube-ops pour ces deux PR : lister avec `git -C <kube-ops> worktree list` et les retirer quand les PR sont fusionnées.
- Dépôt privé `platform-zephyr/openchoreo-lab-security` : bundle de sécurité (en cours de construction).

## 5. Flux d'agents (sans accès OKE ; périmètres de fichiers distincts ; ils rendent compte par notification à la session coordinatrice)
| Flux | Statut |
|---|---|
| Phase 2 k3d partagé `openchoreo` : RBAC strict + contrôleur corrigé + post-renderer + whoami sous moindre privilège + permissions effectives après install/upgrade | EN COURS (fichiers locaux uniquement, ne rien publier) |
| Security bundle minimal et temporaire (dépôt privé, `security/bundle.lock`, `helm_secure`, refus de rollback non durci, tests de refus) | EN COURS |
| A2 Argo (20 PASS), A3 VAP+uninstall (91+59 PASS), GitOps whoami k3d, corrections générateur (137 tests), Kyverno statique (97 tests CLI), architecture, étude stockage, étude migration Authentik | LIVRÉS et intégrés |
| IDP utilisable (préparation) : `docs/IDP-USABLE.md` (chemin, 3 trous, rôles agents, checklist 6b), `tests/idp-demo/run.sh` (DRY_RUN, lecture seule cluster), corrections statiques authz/IDENTITY/PORTAL | PR DRAFT `feat/idp-usable` : statique seulement, **rien d'exécuté sur OKE** |
Ne pas relancer de flux déjà livrés ; vérifier `ListAgents` d'abord.

## 6. Prochaines actions EXACTES (dans l'ordre)
1. Attendre les rapports (phase 2 ; bundle). Quand le bundle est prêt : vérifier que le diff PUBLIC est neutre (grep des mots sensibles), `git add` seulement `tools/oke/security-bundle.sh`, `tools/oke/install.sh`, `tools/oke/verify.sh`, `security/`, `docs/SECURITY-BUNDLE.md`, `tests/security-bundle/`, pousser sur la branche PR #8, CI verte, **fusionner #8 (squash)**.
2. Hygiène du working tree AVANT de fusionner/tirer `main` : des fichiers non suivis peuvent dupliquer des fichiers déjà sur `main` (docs/architecture, docs/identity-migration, docs/storage, docs/KYVERNO-POLICY-CONTRACT.md, platform/kyverno, tests/kyverno, tests/storage, clusters/README.md). **Ne supprimer AUCUN fichier non suivi** sans avoir vérifié (a) qu'il est IDENTIQUE à sa version sur `origin/main` (`git diff --no-index` ou `git show origin/main:<fichier>`) et (b) qu'aucun agent actif ne le modifie (`ListAgents`) ; en cas de doute, ne rien supprimer et fusionner autrement (worktree propre).
3. Étapes OKE 6 → 9 puis 11 (sans 10) avec `install.sh` fail-closed, budget automatique, `verify.sh --step N` après chaque étape (preuves datées). Revérifier le gate dans `OKE-EXEC.md` (dossier de notes de l'agent OKE, emplacement dans le handoff privé) avant d'agir. Rouvrir le bastion si besoin (§2).
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
Environnement local (chemins précis dans le handoff privé) : Colima profil `openchoreo` (`DOCKER_CONTEXT=colima-openchoreo`, ~8 GiB ; limite inotify basse : `sudo sysctl -w fs.inotify.max_user_instances=512` pour un kubelet k3d), k3d `openchoreo` avec son KUBECONFIG dédié, venv Python des tests et worktree de coordination dans le scratchpad de session. Helm 4.1.3 (les post-renderers sont des PLUGINS en Helm 4).

## 9. Vérification de reprise (à faire EN PREMIER après une compaction ; ne modifie PAS OKE)
1. Retrouver le handoff privé (commande du §1) et le lire.
2. `ListAgents` : repérer les agents actifs (phase 2 k3d, security bundle) ; ne PAS en recréer ; leurs résultats arrivent par notification.
3. `git worktree list` (ce dépôt et kube-ops), `git status --short`, `git log --oneline -3` sur la branche courante, `gh pr list` (PR #8 ouverte ?).
4. Security bundle : `gh repo view platform-zephyr/openchoreo-lab-security` (privé ?), état du clone local, présence de `security/bundle.lock` et de `docs/SECURITY-BUNDLE.md` dans ce dépôt, empreinte conforme au lock.
5. Préconditions OKE en LECTURE SEULE : `oci ce cluster list` (cluster `ACTIVE`), session bastion encore valide (sinon rouvrir via le script), `tools/oke/preflight.sh` (aucune écriture), état des étapes dans §3.
6. Reprendre ensuite les deux flux en cours, intégrer, fusionner la PR #8, puis les installations OKE autorisées. Pas de nouvelle étude ; ne pas redemander les décisions déjà enregistrées (§7).
