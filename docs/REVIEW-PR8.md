# Revue indépendante — PR #8 (`feat/oke-remediation-cp-values`, 71bbaff)

> Relecture hors cluster, le 2026-11-17. Aucun kubeconfig, aucun accès OKE. Arbre relu : `git archive origin/feat/oke-remediation-cp-values` (les modifications NON commitées du poste — `reduced-clusterrole.yaml`, `vap-cluster-agent-scope.yaml`, `cell-rolebinding-cpt.yaml`, `values-rbac.yaml` — sont HORS PR et non relues).
> Contrôles faits : `shellcheck -x` et `bash -n` sur `tools/oke/*.sh` (0 constat) ; sha256 des charts = `versions.env` ; `helm template` CP (avec et sans portail), ESO, cert-manager, kgateway-crds, DP ; `psa_check.py restricted` sur le CP (rc=0) ; `argo_guard.py` sur l'arbre (rc=0) puis sur un arbre piégé (voir P1) ; ruleset GitHub `main-protection` lu par `gh api`.

## Verdict

**MERGEABLE APRÈS CORRECTIONS** : P1 (bloquant) et P2, P3 (claims de la PR faux, correctifs d'une ligne). B1 (VAP-1) et B3 (périmètre) sont corrigés. Les values CP sont conformes à `docs/IDENTITY.md`. B2 n'est corrigé qu'en apparence.

## Bloquant avant merge

### P1. B2 non corrigé : une PR mergée peut toujours obtenir les droits cluster-admin d'Argo
- **Preuve.**
  - `project-lab.yaml:47` : `argoproj.io/Application` est dans `namespaceResourceWhitelist`, et `lab-argocd` est une destination. `lab-root` (projet `lab`, `selfHeal`) synchronise `install/argocd/apps/`. `lab-platform` synchronise `policies/*.yaml` et les autres fichiers inclus, qui peuvent eux aussi contenir une `Application`.
  - Une `Application` déclare librement son `spec.project`. Argo CD crée seul le projet `default` (tout dépôt, toute destination, tout kind), et rien dans le pack ne le verrouille (`values/argocd.yaml`). Un `project: lab-authz` avec `syncPolicy.automated` contourne aussi la « sync MANUELLE » des liaisons Authz `lab-*` : le projet n'a aucune contrainte de chemin.
  - Simulation : un fichier `platform/policies/zz.yaml` contenant `kind: Application, project: default, automated`. Résultat : `argo_guard.py` rend **rc=0, 0 écart**. Le contrôle 2 ne regarde que `apps/`, et le contrôle 4 accepte `Application` parce qu'elle est en whitelist.
  - `argo_guard.py` ne tourne pas en CI (`docs/CI-PLATFORM-CHECKS.md:3` : « NON intégré », `HELM_SHA256: "A_RELEVER"`). Les checks de la PR n'incluent pas de job `platform`.
  - Ruleset `main-protection` : `required_approving_review_count: 0`, `require_code_owner_review: false`. Le CODEOWNERS invoqué par `project-lab.yaml:64` et `lab-authz.yaml:2` n'a donc aucun effet.
- **Scénario.** Un agent merge une PR verte (`ci-ok`). `lab-platform` crée l'Application `evil` (projet `default`). Argo applique n'importe quel objet avec son ClusterRole `*/*/*` : `kube-system`, les VAP baseline de kube-ops, un `ClusterAuthzRoleBinding` admin. L'interdit de MISSION.md:17 tombe.
- **Ce qu'une PR mergée peut encore modifier en cluster-scoped, même sans ce contournement :**
  - les 5 types OpenChoreo nommés (`service-restricted`, `cell-restricted`, `cnpg-lab-db`, `persistent-volume-claim`, `health-probes`), y compris leurs `postRenderValidations` ;
  - `lab-cluster-agent-scope` et `lab-cell-pod-hardening` (VAP et VAPB) : passage en `Warn` ou retrait de règles ;
  - le Namespace `lab-pg`, y compris ses labels PSA ;
  - via `lab-authz`, les `ClusterAuthzRole*` `lab-*`.
- **Correctif minimal.**
  1. Étape 11 : appliquer un AppProject `default` verrouillé (`sourceRepos: []`, `destinations: []`, aucune whitelist), puis le vérifier dans `verify --step 11`.
  2. Créer un projet `lab-root` limité à `Application` dans `lab-argocd`. `lab-root` utilise ce projet, et on retire `Application` de la whitelist de `lab`.
  3. `argo_guard.py` : refuser `kind: Application` hors de `apps/` ; refuser tout `spec.project` différent de `lab`, `lab-root` ou `lab-authz`, où qu'il apparaisse ; refuser `syncPolicy.automated` sur `lab-authz`.
  4. Intégrer le job CI `platform`, puis activer `require_code_owner_review` avec au moins 1 approbation (au minimum sur `platform/**`).

## À corriger avant toute exécution de `uninstall.sh` (claims I2/I4 de la PR faux)

### P2. `crd_in_use_outside` reste ouvert : il compare le groupe exact
- **Preuve.** `uninstall.sh:98` : `select(.spec.group == $g)`. Le rendu de kgateway-crds v2.3.11 donne **8 CRD du groupe `gateway.kgateway.dev`**, alors que `undo_5:187` appelle la fonction avec `kgateway.dev`. Elle n'inspecte donc aucune CRD et renvoie 1 (« inutilisée »), puis `helm_rm kgateway-crds` supprime les 8 CRD. Même défaut pour `acme.cert-manager.io` et `generators.external-secrets.io` : `rm_crds` les supprime par suffixe (`grep "\.$1$"`) sans en vérifier l'usage. Aujourd'hui, ce chemin est inaccessible (`crds-before.txt` absent, étapes 1-5 déjà jouées), mais la garde n'échoue pas fermé.
- **Correctif.** `select(.spec.group == $g or (.spec.group | endswith("." + $g)))`. Échouer fermé si aucune CRD ne correspond alors que `rm_crds` en trouve.

### P3. `undo_1` sans garde Argo : la suppression de `lab-pg` recrée un volume de 50 Go
- **Preuve.** `uninstall.sh:229-245` : pas d'appel à `refuse_if_argo`. Le Namespace `lab-pg` et le Cluster CNPG sont pourtant synchronisés avec `selfHeal` (`project-lab.yaml:44`, `lab-platform.yaml:29`). Les `dp-*` sont supprimés sans vérifier qu'il ne reste aucun Component, contrairement à `undo_9`.
- **Scénario.** Argo actif, on lance `--step 1 --apply`. Le namespace `lab-pg` et son PVC sont supprimés, puis Argo recrée le Namespace et le Cluster : un nouveau block volume de 50 Go est créé (interdit sans `--confirm-storage`).
- **Correctif.** `refuse_if_argo 1` en tête de `undo_1`, plus la garde « aucun Component » de `undo_9`.

## Vérifié, sans écart bloquant

- **VAP-1 (B1, I6).**
  - Couverture : `operations: [CREATE, UPDATE, DELETE, CONNECT]` et `resources: ["*", "*/*"]` (l.40-42). Les sous-ressources d'accès aux pods (dont `pods/exec`) sont refusées hors `dp-*` par la règle R2 (l.95-100), les sous-ressources de nœud par R1. `oldObject != null` est gardé à la création (l.69). Les variables qui lisent `object` ne sont évaluées que pour CREATE/UPDATE ou pour `jobs` (CEL paresseux). La baisse `restricted` → `baseline` est refusée en UPDATE (l.115).
  - Fonctionnement légitime de l'agent : le chart DP n'a ni Role ni lease ; le CPT `cell-restricted` pose les 3 labels exigés (l.70-75) ; les CCT interdisent Role et RoleBinding, donc R4 et R5 ne bloquent rien d'attendu.
  - `verify.sh` v7 ajoute `B7-exec`, `B7-psa-ok` et `B7-psa-lock`.
- **Désinstallation (I1).** Rendus vérifiés : les 23 CRD d'ESO et les 6 de cert-manager portent `resource-policy: keep`. `release_keeps_crds` refuse la désinstallation tant que la release ESO installée sur OKE (sans `keep`) n'a pas été mise à jour (`--step 4 --apply`). `kgateway-crds` n'est jamais désinstallé sans `--delete-crds`. Le chart ESO n'a pas de dossier `crds/`. `refuse_if_argo` est présent dans `undo_7`, `undo_9` et `undo_10`.
- **Values du CP.**
  - OIDC : issuer `https://auth.smadja.dev/`, `jwks_url …/application/o/openchoreo/jwks/` et `audiences: []`, rendus dans `openchoreo-api-config`, conformes à IDENTITY §1-§2.
  - Authz : `bootstrap.mappings` remplacés (admin, developer, catalog-reader), et `mcp-tryout`/`service_mcp_client` sont absents du rendu.
  - PSA restricted : rc=0 sur les 5 workloads.
  - Exposition : aucun PVC, LoadBalancer, NodePort, HTTPRoute ou Gateway.
  - Requests : 40m/456 Mi, plus kgateway, soit 50m/552 Mi ; plus le Job de bootstrap (LimitRange 10m/32 Mi), soit 584/640 Mi. Les sélecteurs de `03-idp-egress.yaml` correspondent aux labels rendus.
- **install.sh.**
  - Ordre : VAP avant l'agent (étape 7), egress IdP avant le CP.
  - Dry-run par défaut : `steps.log` et `budget_gate` ne servent qu'avec `--apply`, et `--step N` seul ne fait que des lectures plus des fichiers locaux.
  - L'étape 10 meurt sans `--confirm-storage` en `--apply` (l.187).
  - Codes 3, 4 et 5 : `exit` dans `budget_gate`, `capacity_gate || exit $?`.
  - `guard_ns_ownership` est actif aux étapes 1 et 10.
- **Périmètre (B3).** `cnpg-system` est remplacé par `lab-cnpg` (namespaces, quotas, NP, `TRIAL_NS`) ; la migration est gardée et échoue fermé ; MISSION.md consigne les exceptions.

## À corriger après le merge

| # | Gravité | Constat | Preuve | Correctif |
|---|---|---|---|---|
| A1 | important | Le projet `lab` laisse une PR ouvrir `lab-pg` ou contourner les CCT | `project-lab.yaml:46,48` : `NetworkPolicy` (allow-all dans `lab-pg`) et `openchoreo.dev/*` namespacé (ComponentType, ProjectType, Trait, DataPlane namespacés, sans `postRenderValidations`) | Lister les kinds OpenChoreo applicatifs ; argo_guard : NP de `lab-pg` par nom |
| A2 | important | Le Namespace `lab-pg` est modifiable par PR, labels PSA compris | `project-lab.yaml:44`, aucune VAP | argo_guard : labels PSA fixes ; ou sortir `lab-pg-namespace.yaml` d'Argo |
| A3 | important | R3–R6 de VAP-1 ne sont prouvés que par des dry-run sur OKE, sans cycle OpenChoreo réel | Aucune entrée dans `tests/k3d/evidence` | Rejouer whoami + cnpg-lab-db sur k3d avec la VAP avant l'étape 7 |
| m1 | mineur | VAP-1 admet un `dp-*` créé directement en `baseline`, ou supprimé puis recréé | l.110 | Lier `baseline` à une annotation du CPT ; test de baisse en UPDATE dans v7 |
| m2 | mineur | R4 cite `ClusterRole/lab-cluster-agent-cell` et `cell-rolebinding-cpt.yaml`, absents de la PR (non commités sur le poste) | `vap…:17,127` | Commiter le flux RBAC ou retirer R4 du commentaire |
| m3 | mineur | Règle morte vers `cnpg-system` : admettrait un futur opérateur de kube-ops sur `lab-pg:8000` | `platform/data/lab-pg-namespace.yaml:37` | Remplacer par `lab-cnpg` (l'overlay 51 l'autorise déjà) |
| m4 | mineur | `AGENTS.md` non aligné (`default`, `dp-*` et `cnpg-system` en lecture seule) ; exceptions « à acquitter par Paul » sans garde dans `step_9` | `AGENTS.md:8,20` ; `MISSION.md:22-23` | Aligner AGENTS.md après l'accord de Paul |
| m5 | mineur | `rollout restart` des 3 Deployments : surge de +136 Mi au-dessus du quota de 640 Mi. `wait Available` passe sur les anciens pods | `install.sh:125-126` | `rollout status` par Deployment, en série |
| m6 | mineur | Étape appliquée mais absente de `steps.log` si `budget_gate` sort en 3/4/5 | `install.sh:224-225` | Journaliser avant le gate |
| m7 | mineur | Le gate stoppe à 1,5 Gi alors que MISSION en fait un objectif | `MISSION.md:9`, `lib.sh:141` | Documenter (choix prudent) |
| m8 | mineur | Commentaire périmé : `platform/identity/authz/openchoreo-authz.yaml` → `platform/authz/` | `values/openchoreo-control-plane.yaml:94` | Corriger |
