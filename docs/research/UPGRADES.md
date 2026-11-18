# Montées de version automatisées — recherche et proposition d'ADR

Date : 2026-11-18 · Domaine : UPGRADES · Complète `backlog/proposals/upgrades.yaml`.

## Conclusion d'abord
- Un seul pipeline pour tout : **détection** (Renovate + veille par agent) → **PR** → **classification** exécutable
  (`upgrade-gate`) → **preuves** (CI k3d, `development`, app-status) → **merge/promotion** → **revert automatique**.
- L'autonomie se règle par **catégorie**, pas par PR : automerge sous porte pour apps stateless, digests et outils ;
  PR traitée par un agent pour le reste ; MANDAT uniquement pour ce qu'une PR ne peut pas appliquer
  (OpenChoreo, OKE, Talos, providers Tofu : application sur cluster ou état Tofu) et pour les données irréversibles.
- La **politique d'automerge vit dans `.github/renovate.json`**, donc dans le noyau protégé (ADR-0002) : ni Renovate ni
  un agent ne peuvent élargir leur propre automerge. C'est l'invariant qui rend l'automatisation acceptable.
- **Constat sur l'existant** : `.github/renovate.json` du labo n'a ni `internalChecksFilter: strict`, ni dashboard, ni
  limite de PR, ni catégorie plateforme ; ses `postUpgradeTasks` (appgen render) ne tournent que sous Renovate
  auto-hébergé [V 2026-11-18 + https://docs.renovatebot.com/self-hosted-configuration/ : `allowedCommands` est une option globale d'administrateur ; app Mend hébergée : commandes autorisées visibles seulement dans les journaux du portail Mend, usage restreint (https://docs.renovatebot.com/mend-hosted/hosted-apps-config/) ; depuis Renovate 43, `postUpgradeTasks` ne passe plus par un shell par défaut] ; `versions.env` (digest OCI + sha256 du chart) n'est suivi par aucun manager. T-064 est trop large.
- Le pipeline cible **n'existe pas encore** : il dépend de T-003 (dev/promotion), T-005 (preuve runtime) et T-065 (revert).

## Ce qui a pu être lu
Lu : ADR 0002/0004/0005/0006/0011, backlog (T-064/002/003/065, INDEX, FORMAT), `install-upgrade-support.md`,
`SECURITY-BUNDLE.md`, `.github/renovate.json`, `kube-ops/renovate.json`, `homelab-infra/renovate.json` (règles PLT-172/207,
roadmap PLT-127/128/140/141 : titres seulement), `homelab-infra/docs/architecture/talos-bootstrap.md`, `terraform/oracle-a1/main.tf`.
**Web : vérifié le 2026-11-18** (docs.renovatebot.com, docs.sigstore.dev, slsa.dev, docs.github.com, docs.oracle.com, docs.siderolabs.com, github.com/ossf/scorecard) via `curl`. Les marques **[V date + URL]** ci-dessous remplacent les anciens **[E]** ; ce qui reste **[E]** ou **[NV]** n'a pas pu être lu (CNPG et Argo CD : montées de version non revérifiées ; voir `VERIFICATION-2026-11-18.md`).

## 1. Pratiques communes
| Pratique | Contenu | Source |
|---|---|---|
| Automerge par catégorie | `automerge` + `automergeType: pr` ; la fusion n'a lieu que si les checks requis passent ; `platformAutomerge` (**activé par défaut**) délègue à GitHub, qui place la PR dans la merge queue ; avec `platformAutomerge=false`, Renovate tente la fusion directe (réussit si Renovate est dans la liste de contournement de la queue) puis ajoute la PR à la queue [V 2026-11-18 + https://docs.renovatebot.com/key-concepts/automerge/] | Renovate key-concepts/automerge [V] |
| `minimumReleaseAge` | Retient une version N jours après publication (défense contre versions retirées et paquets compromis). `internalChecksFilter` vaut **`strict` par défaut** dans la doc actuelle (`flexible` crée la PR avec la version pending la plus haute et peut « osciller » ; `none` ne filtre pas) ; pour retenir réellement la PR, combiner `minimumReleaseAge`, `prCreation="not-pending"` et `strict`, et activer le dashboard. Le check `renovate/stability-days` est `pending` tant que l'âge n'est pas atteint. Les **mises à jour de sécurité contournent** `minimumReleaseAge` (le gestionnaire de paquets applique son propre âge au lockfile) ; `minimumReleaseAge=0` vaut `null` depuis 42.19.5 ; la source de données doit fournir un horodatage de release [V 2026-11-18 + https://docs.renovatebot.com/configuration-options/#minimumreleaseage et https://docs.renovatebot.com/key-concepts/minimum-release-age/] | Renovate configuration-options [V]  ; kube-ops, homelab-infra (3/7/14 jours) |
| Digest pinning | `docker:pinDigests`, `helpers:pinGitHubActionDigests` ; un « digest update » sur un tag déjà épinglé = le tag a bougé : bon pour une image de base, **suspect pour une action GitHub** | presets `docker:pinDigests`, `helpers:pinGitHubActionDigests` [V 2026-11-18 + https://docs.renovatebot.com/presets-docker/ et https://docs.renovatebot.com/presets-helpers/] ; incident tj-actions/changed-files, CVE-2025-30066 : tags v1 à v45.0.7 repointés vers un commit malveillant, épinglage par SHA protecteur [V 2026-11-18 par recoupement de sources secondaires : https://thehackernews.com/2025/03/github-action-compromise-puts-cicd.html ; page CISA en 403] |
| Groupement et débit | `groupName` par écosystème lié (ex. OpenTofu dans homelab-infra PLT-207, Netbird dans kube-ops), `prConcurrentLimit`/`prHourlyLimit`, `schedule` nocturne, `prPriority` | kube-ops (20/5), homelab-infra (12/3) |
| Dashboard | `dependencyDashboard: true` = inventaire, approbation par case (`dependencyDashboardApproval`) pour les majeures et pour le rattrapage initial | kube-ops, homelab-infra |
| Confiance | `mergeConfidence:all-badges` (âge, adoption, taux de réussite des tests chez d'autres) sert de signal, jamais de porte seule [V 2026-11-18 + https://docs.renovatebot.com/merge-confidence/ : la page existe ; le détail des critères (âge, adoption, réussite) n'a pas été extrait] | kube-ops |
| Rattrapage initial | PLT-140 : un rattrapage groupé puis couverture par catégorie ; PLT-128 : les PR d'outillage avant les digests (prPriority) | homelab-infra roadmap (titres) |
| Porte runtime | PLT-141 : automerge d'images stateless uniquement derrière un gate runtime (PLT-129) | homelab-infra roadmap (titres) |
| Signatures | cosign keyless : `cosign verify --certificate-identity(-regexp) … --certificate-oidc-issuer https://token.actions.githubusercontent.com` ; Kyverno `verifyImages` l'impose à l'admission | Sigstore docs [V 2026-11-18 + https://docs.sigstore.dev/cosign/verifying/verify/ : `--certificate-identity` et `--certificate-oidc-issuer` confirmés] ; Kyverno docs [V 2026-11-18 + https://kyverno.io/docs/policy-types/cluster-policy/verify-images/sigstore/ : émetteur `token.actions.githubusercontent.com` pour la signature sans clé avec GitHub Actions] |
| Provenance | SLSA v1 : **les attestations d'artefacts GitHub seules donnent Build L2**, pas L3 ; L3 exige en plus des workflows réutilisables vérifiés (ou `slsa-github-generator`) ; vérification `gh attestation verify` / `slsa-verifier` | slsa.dev [V 2026-11-18 + https://slsa.dev/spec/v1.0/levels : niveaux Build L0 à L3] ; GitHub docs [V 2026-11-18 + https://docs.github.com/en/actions/concepts/security/artifact-attestations : « Artifact attestations by itself provides SLSA v1.0 Build Level 2 »] |
| Scorecard | OpenSSF Scorecard : Pinned-Dependencies, Token-Permissions, Dangerous-Workflow, Maintained ; utile en **signal** sur l'amont et en **audit** de notre dépôt (Branch-Protection sera faible avec 0 approbation, c'est assumé) | https://github.com/ossf/scorecard/blob/main/docs/checks.md [V 2026-11-18 : ces quatre checks existent, ainsi que Code-Review, SAST, Dependency-Update-Tool, Vulnerabilities, Signed-Releases] |
| Rollback | Revert Git de la PR de bump ; Talos garde l'image précédente (A/B) et revient si le démarrage échoue [V 2026-11-18 + https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/lifecycle-management/upgrading-talos : « Upgrades use an A-B image scheme in order to facilitate rollbacks. If an upgrade fails to boot, Talos will roll back to the previous version. »] ; Helm rollback proscrit ici (SECURITY-BUNDLE) | Talos docs [V] |

## 2. Politique par catégorie
Légende : **AUTO** = Renovate fusionne seul (classe AUTONOME) si `ci-ok` + `upgrade-gate` + preuve dev PASS pour les apps.
**ASSISTÉ** = PR ouverte automatiquement, un agent la traite (résumé, correction du contrat, preuves) et fusionne si PASS
et hors noyau, sinon REVUE. **MANDAT** = préparation autonome, application par Paul/coordinateur dans une fenêtre.

| Catégorie | patch / digest | minor | major | `minimumReleaseAge` | Porte |
|---|---|---|---|---|---|
| Image app stateless (A, D) | AUTO | AUTO si 0 BREAKING dans le résumé, sinon ASSISTÉ | ASSISTÉ | digest 0 (même tag) ; patch 3 j ; minor 7 j ; major 14 j | CI + arm64 + dev PASS + promotion |
| Image app stateful (B, C) | ASSISTÉ + sauvegarde < 24 h prouvée | ASSISTÉ + sauvegarde + restauration < 7 j | MANDAT (migration de schéma) | 7 / 14 / 30 j | idem + `fresh-backup` |
| Chart Helm tiers (E) | AUTO si le rendu n'ajoute aucun kind/droit/CRD | ASSISTÉ | MANDAT si nouveau CRD, RBAC cluster ou privilège (= F) | 7 / 14 / 30 j | diff de rendu `appgen` + dev PASS |
| Images de base, outils CI/mise | AUTO | AUTO (hors 0.x) | ASSISTÉ | 3 j | `ci-ok` |
| Actions GitHub (`.github/` = noyau) | ASSISTÉ, 1 PR groupée par semaine | ASSISTÉ | REVUE | 14 j | `ci-ok`, jamais AUTO |
| Opérateurs plateforme : cert-manager, ESO, kgateway, Gateway API, Kyverno | ASSISTÉ, répétition k3d N-1→N | ASSISTÉ + répétition | MANDAT | 14 j | k3d upgrade + `versions.env` recalculé ; apply OKE par coordinateur |
| Argo CD (`platform/install/argocd/` = noyau) | REVUE | REVUE | MANDAT | 14 j | k3d gitops + argo-escalation |
| CNPG (opérateur) et PostgreSQL | opérateur : ASSISTÉ ; PG patch : voir stateful | PG minor : stateful ci-dessus | PG major : MANDAT | 14 / 30 j | `fresh-backup` + drill |
| OpenChoreo (charts, CRD, bundle privé) | MANDAT (patch de la mineure courante, bundle à reconstruire) | MANDAT, **une mineure à la fois** | interdit de sauter | 14 j | répétition k3d + runbook |
| Kubernetes OKE (plan de contrôle puis pool) | MANDAT | MANDAT | MANDAT | n/a | fenêtre approuvée, sauvegardes, preflight |
| Talos (homelab) et talosctl | MANDAT | MANDAT | MANDAT | 14 j | fenêtre, sauvegarde etcd, image Factory |
| Providers et outils Tofu | ASSISTÉ (plan en artefact) | ASSISTÉ | MANDAT | 7–14 j | plan sans ressource payante, apply MANDAT |

Règles transverses :
1. **CVE** : `vulnerabilityAlerts` contourne l'âge, **jamais** la porte de preuve.
2. **Jamais d'automerge** sur : `0.x`, données `important/irreplaceable`, tout fichier du noyau ADR-0002, nouvelle source d'image
   (registre hors liste), image sans manifeste `linux/arm64` (OKE), changement de `securityExceptions`.
3. **Contrat d'abord** : si un bump exige un champ de `app.yaml` (ex. nouvelle variable), l'agent corrige la PR ; l'automerge ne s'applique
   qu'aux bumps qui ne modifient que la ligne de version/digest et les fichiers `generated/`.
4. **Débit** : `prConcurrentLimit: 4`, `prHourlyLimit: 2`, nuit (Europe/Paris) ; en `development` **une montée à la fois**
   (≤ 2 apps, ADR-0004) : file sérialisée.
5. **Rattrapage initial** : approbation par le dashboard, groupé par catégorie, du plus sûr au plus risqué.

## 3. Porte de merge automatique (apps)
1. Renovate ouvre la PR (digest/patch/minor) ; `postUpgradeTasks` ou job CI régénère `generated/` (Renovate auto-hébergé requis [V 2026-11-18 + https://docs.renovatebot.com/self-hosted-configuration/]).
2. `upgrade-gate` (check requis, UPG-3) classe la PR (catégorie, classe de donnée, arm64, registre, signature, diff de rendu) et refuse l'automerge si une règle transverse s'applique.
3. CI k3d verte (`ci-ok`) puis merge sur `main` : seul l'Environment **development** reçoit la release (pin par environnement, ADR-0004).
4. Job PostSync : `app-status.v1` en `development`. PASS RUNTIME → `appgen promote` ouvre et fusionne la PR de promotion ; FAIL/BLOCKED → PR de revert automatique (T-065) et dépôt du résumé dans la PR Renovate.
5. Après promotion : preuve `production` ; FAIL → revert ; un `git revert` conserve les releases historiques (leçon STATE.md, job `release-history`).
6. Le revert n'annule **pas** une migration de schéma : d'où la sauvegarde fraîche obligatoire pour B/C et le MANDAT pour les majeures PG.

## 4. Plateforme, OpenChoreo, Kubernetes, Talos
- **OpenChoreo** (install-upgrade-support.md) : une mineure à la fois, dernier patch d'abord ; Helm ne met pas à jour les CRD → `kubectl apply --server-side --force-conflicts -f crds/` par plan puis `helm upgrade --reset-then-reuse-values` (control, data, workflow, observability) ;
  1.3.3 supporté jusqu'à la GA de 1.6. Ici s'ajoute le **bundle de sécurité privé** : un nouveau chart exige un nouveau bundle (version, digest du contrôleur, `security/bundle.lock`), donc
  **aucun bump de `OPENCHOREO_*` par Renovate seul** (règle `enabled: false` + veille). L'agent prépare : résumé des changements, diff des CRD, répétition k3d, PR du lock ; Paul/coordinateur reconstruit le bundle et applique.
  Retrait du bundle quand l'amont corrige (SECURITY-BUNDLE, plan de retrait) = la meilleure simplification de ce domaine.
- **Opérateurs** (cert-manager, ESO, kgateway, Gateway API, CNPG) : `versions.env` porte version + digest OCI + sha256 du chart ; Renovate ne sait pas les recalculer → outil `bump-versions` (UPG-7). Les CRD Gateway API suivent leurs règles de canal ; vérifier la compatibilité kgateway/Gateway API avant de grouper.
- **OKE** [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengupgradingk8smasternode.htm et .../contengupgradingk8sworkernode.htm : plan de contrôle d'abord, tous les nœuds doivent être READY, **pas de retour arrière** de version du plan de contrôle ; pour les nœuds, deux modes de cycling : « Replace boot volume » (cordon, drain, volume de démarrage remplacé **sans terminer l'instance**, donc sans nouvelle capacité A1) et « Replace nodes » ; le drain est automatique et les charges non drainées sont perturbées ; `maximum_surge` non relu] : plan de contrôle d'abord (en place, sans coupure des charges : non confirmé par la page), puis pool de nœuds. **Piste nouvelle : « Replace boot volume » évite le risque « out of host capacity » d'un nœud supplémentaire.** Un seul nœud A1 : le drain est impossible sans coupure (PDB à 1 réplique bloque l'éviction, `replicas: 1`). Deux options : cycling avec nœud supplémentaire temporaire (`maximum_surge`) si le quota Always Free le permet (**faux** : le quota Always Free A1 est de 1 500 OCPU-heures et 9 000 Go-heures par mois, soit 2 OCPU / 12 Go en continu, ce que le labo utilise déjà : un nœud de surge dépasserait le quota ; voir `COST-FREE-TIER.md` [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm]), ou remplacement en place avec **coupure planifiée** (acceptée, ADR-0004 : pas de HA). Les PVC OCI se rattachent s'ils restent dans le même domaine de disponibilité. `ignore_changes` sur `image_id` dans `terraform/oracle-a1/main.tf` : les mises à jour d'image de nœud sont donc une opération explicite, pas un effet de `tofu apply`.
- **Talos** : `talos-bootstrap.md` impose le day-2 par l'API d'upgrade avec image Factory, jamais `tofu apply -replace` (disque protégé par `ignore_changes`) ; un redémarrage du seul nœud de contrôle = coupure ; prérequis : sauvegardes Velero/CNPG vérifiées, santé etcd, DiskPressure, image précédente et accès console. Les agents n'ont pas le `talosconfig` : **préparation autonome, application MANDAT**.
- **Fenêtres** : fichier déclaratif `ops/maintenance-windows.yaml` (noyau) = mandat ponctuel de Paul (composant, version, créneau, conditions d'abandon) ; hors fenêtre, rien ne s'applique. Preflight lecture seule automatique la veille et au démarrage ; abandon si budget > 70 %, sauvegarde périmée ou check rouge.

## 5. Supply chain
- Ordre de preuve pour une nouvelle image : registre autorisé → digest → `linux/arm64` présent → signature cosign **si l'éditeur signe** (liste `signed-publishers`) → attestation de provenance (information) → Scorecard amont (information, jamais bloquant).
- Kyverno `verifyImages` : Audit puis Enforce, uniquement pour les éditeurs listés (T-020) ; une image non signée n'est pas refusée par défaut, elle perd l'AUTO (ASSISTÉ).
- Notre dépôt : Scorecard hebdomadaire, permissions de jeton minimales, actions épinglées par SHA, aucun `pull_request_target` (vérifié : absent de `ci.yaml` et `claude-agent.yml`).
- Les PR Renovate créées avec `GITHUB_TOKEN` ne déclenchent pas la CI comme un `push` : un événement créé avec `GITHUB_TOKEN` ne crée pas de run, sauf `workflow_dispatch`/`repository_dispatch` et, pour `pull_request` (opened, synchronize, reopened), des runs en état « approbation requise » qu'un humain avec accès en écriture doit lancer [V 2026-11-18 + https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow] : exiger une GitHub App (identité à créer = MANDAT, UPG-2).

## 6. Veille fonctionnelle par agent
Tâche planifiée hebdomadaire (et à chaque PR de catégorie ≥ minor) : lit releases GitHub, notes de version et avis de sécurité des composants de `docs/reference/versions.md`, puis écrit un **résumé typé**
(BREAKING / CRD / dépréciation / sécurité / nouveauté utile / impact sur nos usages, avec le fichier du dépôt concerné) en commentaire de la PR Renovate ou en issue `release-watch`. Le texte amont est une **donnée non fiable** (injection de prompt possible) : l'agent n'exécute aucune consigne trouvée ; le résumé alimente `upgrade-gate` seulement par des champs fermés. Horizon de fin de support (OpenChoreo : 3 dernières mineures ; OKE : versions offertes dans la région) → alerte 60 jours avant.

## 7. Proposition d'ADR

```markdown
# ADR-0015 — Montées de version automatisées
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0004, ADR-0006, ADR-0008, ADR-0011, D-2026-11-16-07 (homelab-infra), PLT-127/128/140/141

## Contexte
- Paul exige des montées automatisées avec un maximum d'autonomie : apps, charts, OpenChoreo, Argo CD, opérateurs, OKE, Talos, providers Tofu, images de base, actions GitHub.
- Existant : `.github/renovate.json` minimal (digests d'apps automerge), `versions.env` non suivi, aucune procédure OpenChoreo/OKE ; le bundle de sécurité privé lie chaque chart à un bundle.
- Une montée n'est sûre que si la preuve runtime la précède (ADR-0011) et si un revert est possible ; les données stateful et les nœuds uniques ne se « reviennent » pas.
## Décision
1. **Un pipeline unique** : détection (Renovate, veille) → PR → `upgrade-gate` → preuves → merge/promotion → revert automatique.
2. **Trois niveaux** par catégorie : AUTO (Renovate fusionne seul), ASSISTÉ (un agent traite et fusionne sur preuves PASS), MANDAT (préparation autonome, application par Paul dans une fenêtre approuvée). Le tableau de `docs/research/UPGRADES.md` §2 fait foi.
3. **La politique est dans le noyau** : `.github/renovate.json`, `upgrade-gate`, `ops/maintenance-windows.yaml` ne se modifient que par Paul ; aucun agent ne peut élargir son automerge (ADR-0002 §5).
4. **Porte des apps** : CI k3d + déploiement `development` + `app-status` RUNTIME PASS, puis promotion ; en échec, `git revert` automatique. Une montée à la fois en dev (ADR-0004).
5. **Jamais d'automerge** : 0.x, noyau, données `important/irreplaceable`, source d'image nouvelle, image sans `linux/arm64`. Stateful : sauvegarde fraîche prouvée avant toute montée ; majeure PG ou migration de schéma = MANDAT.
6. **Âge minimal** par catégorie (3 à 30 jours) avec `internalChecksFilter: strict` ; les CVE contournent l'âge, pas la preuve.
7. **Plateforme** : OpenChoreo une mineure à la fois (CRD, bundle reconstruit), OKE et Talos par fenêtre déclarée ; l'agent prépare, répète sur k3d, résume ; il n'applique pas.
8. **Supply chain** : digest obligatoire ; signature cosign vérifiée pour les éditeurs qui signent ; provenance et Scorecard en signaux ; actions GitHub jamais en AUTO.
9. **Veille** : un agent résume chaque release (champs fermés), le texte amont reste non fiable.
## Conséquences
- Nouvelle surface : `upgrade-gate`, `bump-versions`, runbooks OpenChoreo/OKE/Talos, `docs/reference/versions.md`, App GitHub pour Renovate (MANDAT).
- Coût : temps de CI k3d, un créneau dev occupé par montée ; coupure assumée du nœud unique pendant les fenêtres.
- T-064 est remplacé par la série UPG ; T-065 (revert) devient prérequis de l'AUTO.
## Alternatives écartées
- **Automerge large sur tout patch/minor** : un tag compromis ou une migration silencieuse atteint la prod sans preuve.
- **Tout en revue humaine** (état kube-ops) : dette de versions croissante (platform-overview homelab-infra), contraire à ADR-0002.
- **Flux/Argo Image Updater écrivant dans le cluster** : contourne Git, interdit par AGENTS.md.
- **Hébergement Renovate par l'App Mend** : pas de `postUpgradeTasks` utilisable en pratique (commandes limitées, réglage par Mend) [V partiel 2026-11-18 + https://docs.renovatebot.com/mend-hosted/hosted-apps-config/], donc `generated/` non régénéré.
## Vérification
- Indicateurs : part de PR de montée fusionnées sans humain, délai détection → prod, taux de revert, âge médian des dépendances, composants proches de la fin de support.
- Preuves : une montée AUTO complète datée (dev → prod), un échec volontaire → revert, une répétition k3d d'une mineure OpenChoreo, un test de refus de l'automerge pour chaque règle « jamais ».
## Références
`docs/research/UPGRADES.md`, `docs/reference/openchoreo/install-upgrade-support.md`, `docs/SECURITY-BUNDLE.md`, `.github/renovate.json`.
```

## 8. Sources (lues le 2026-11-18, sauf mention)
Renovate : docs.renovatebot.com (key-concepts/automerge, configuration-options : `minimumReleaseAge`, `internalChecksFilter`, `vulnerabilityAlerts`,
`postUpgradeTasks`, `customManagers`) ; Sigstore cosign verify ; slsa.dev/spec/v1.0 ; docs.github.com (artifact attestations, merge queue) ;
scorecard.dev ; Kyverno `verifyImages` ; Oracle OKE (upgrade du plan de contrôle, `node_pool_cycling_details`, limites Always Free A1) ;
docs.siderolabs.com (upgrading Talos : lu) ; cloudnative-pg.io (installation_upgrade, major upgrade : NON LU) ; argo-cd.readthedocs.io (upgrading : NON LU) ;
openchoreo.dev/docs/v1.3.x/platform-engineer-guide/upgrades/ (déjà résumé dans `install-upgrade-support.md`).
