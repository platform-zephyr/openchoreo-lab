# Revue indépendante — pack d'installation OKE (Phase B)

> Relecture hors cluster, le 2026-11-17. Aucun accès à OKE, aucun kubeconfig lu. Sources lues : `docs/PHASE-B.md`, `platform/install/**`, `tools/oke/*`, `platform/{policies,cluster-agent,component-types,project-types,resource-types,traits,data}`, `tools/appgen/appgen.py` (parties quota, secrets et PVC), `.github/workflows/ci.yaml`, `.github/renovate.json`, `tests/k3d/RESULTS.md`, `AGENTS.md`, `missions/MISSION.md`, `CLEANUP.md`.
> Contrôles faits : les 8 charts ont été récupérés et leur sha256 correspond à `versions.env`. `helm template` a été lancé avec les values du dépôt, dans le scratchpad. `psa_check.py` rend rc=0 sur les 8 rendus. Aucun PVC, aucun `volumeClaimTemplates`, aucun Service LoadBalancer ou NodePort dans les rendus. Toutes les images rendues sont épinglées par digest.
> Journaux locaux lus (`~/.cache/openchoreo-lab-phaseb/`) : les **étapes 1 à 5 sont déjà appliquées** sur OKE (steps.log, 18:22-18:28Z).

## Conclusion

Le pack est soigné : sha256 des charts, digests, PSA vérifiée statiquement, aucun LoadBalancer ni PVC rendu, CI épinglée par SHA, sans injection. Trois points bloquent pourtant la suite :

1. **VAP-1 ne couvre pas `pods/exec`.** Elle ignore l'opération CONNECT et les sous-ressources. Or le chart du DP donne `pods/exec` au cluster-agent sur tout le cluster. Dès l'étape 7, un agent compromis peut exécuter des commandes dans n'importe quel pod, y compris les pods privilégiés de kube-system, et prendre la main sur le nœud.
2. **L'AppProject `lab` laisse une PR toucher au cluster entier.** Il autorise les kinds `Namespace` et `ValidatingAdmissionPolicy` sans restriction de nom. Une PR mergée peut donc réétiqueter `kube-system` ou réécrire les VAP baseline de kube-ops, avec le ClusterRole `*/*/*` d'Argo.
3. **Le périmètre réel contredit `AGENTS.md` et `MISSION.md`.** Le pack écrit dans `cnpg-system` (namespace créé dès l'étape 1) et dans `default`. Il supprime aussi des `dp-*`.

Décompte : **3 bloquants, 12 importants, 12 mineurs.**

## Bloquants

### B1. VAP-1 laisse passer `pods/exec` et les sous-ressources du cluster-agent (point 6)
- **Preuve.** `platform/policies/vap-cluster-agent-scope.yaml:22-24` : `operations: [CREATE, UPDATE, DELETE]`, `resources: ["*"]`. Dans une VAP, `"*"` exclut les sous-ressources (il faut `"*/*"`), et CONNECT n'est pas listé.
- **RBAC rendu du chart DP 1.3.3** : permissions larges sur plusieurs ressources, dont des sous-ressources sensibles. Détail volontairement retiré de ce dépôt public (coordination privée en cours) ; voir le dossier privé.
- **Scénario.** Le jeton de l'agent fuit, ou le CP est compromis et pilote l'agent. On lance alors `kubectl exec --as=…:cluster-agent-dataplane -n kube-system <pod cilium> -- sh`. La VAP n'est pas évaluée. Le pod est privilégié avec hostNetwork, ce qui donne root sur le nœud et l'accès à tout le cluster. `verify.sh` B7 ne teste que la création d'une ClusterRoleBinding, donc il passe.
- **Correctif minimal.**
  - Dans VAP-1, passer à `operations: [CREATE, UPDATE, DELETE, CONNECT]` et `resources: ["*", "*/*"]`.
  - Ajouter à `verify.sh v7` un `expect_deny` qui lance `kubectl exec --as=$sa -n openchoreo-control-plane <pod de sonde> -- true`, avec le motif `lab-cluster-agent-scope`.

### B2. L'AppProject `lab` permet à une PR de modifier `kube-system` ou les VAP de kube-ops (points 6, 7 et 8)
- **Preuve.**
  - `platform/install/argocd/project-lab.yaml:25-32` : `clusterResourceWhitelist` contient `Namespace`, `ValidatingAdmissionPolicy` et `ValidatingAdmissionPolicyBinding`, sans contrainte de nom.
  - `argocd/apps/lab-platform.yaml:25` synchronise `policies/*.yaml` et `data/lab-pg-namespace.yaml` depuis `main` (`selfHeal: true`, SSA).
  - Le ClusterRole rendu `argocd-application-controller` vaut `*/*/*`.
  - `FailOnSharedResource` ne protège que des objets suivis par une autre Application Argo.
- **Scénario.** Une PR ajoute `platform/policies/x.yaml` avec l'un de ces contenus :
  - `kind: Namespace`, `name: kube-system` ou `databases`, avec des labels PSA `privileged` ;
  - `kind: ValidatingAdmissionPolicyBinding`, `name: baseline-pod-hardening…`, avec `validationActions: [Warn]`.

  Argo l'applique sur tout le cluster. C'est à la fois un contournement d'admission et une modification de kube-ops, deux interdits de MISSION.md. Autre vecteur : `namespaceResourceWhitelist openchoreo.dev/*` dans `default` (`project-lab.yaml:34`) inclut `AuthzRole` et `AuthzRoleBinding`, ce qui permet à une PR de s'octroyer des droits MCP en écriture.
- **Correctif minimal.**
  - Retirer `Namespace`, `ValidatingAdmissionPolicy` et `ValidatingAdmissionPolicyBinding` de la whitelist.
  - Retirer `policies/*.yaml` et `data/lab-pg-namespace.yaml` de `include` : ils restent amorcés par `install.sh`, aux étapes 7 et 10.
  - Ajouter `namespaceResourceBlacklist` sur `openchoreo.dev` `AuthzRole` et `AuthzRoleBinding`.
  - Vérifier que la règle `main-protection` exige la revue des code owners.

### B3. Le périmètre écrit contredit `AGENTS.md` et `MISSION.md` (point 8)
- **Preuve.**
  - `MISSION.md:12` interdit de toucher « un namespace d'OKE autre que `openchoreo-*` / `lab-*` ».
  - `AGENTS.md:8,20` : écriture limitée à `openchoreo-*`/`lab-*` ; `cnpg-system`, `default` et `dp-*` sont en **lecture seule**.
  - Or :
    - `manifests/00-namespaces.yaml:96-106` crée `cnpg-system`, déjà appliqué à l'étape 1 ;
    - `install.sh:139` y installe CNPG ;
    - `install.sh:130` étiquette `default`, et l'étape 9 y écrit des objets ;
    - `uninstall.sh:103-104` supprime des `dp-*`.
  - `PHASE-B.md §3` parle d'« exceptions documentées », mais aucun texte de règle n'a été modifié, et aucune décision de Paul n'est tracée.
- **Scénario.** Un agent qui suit AGENTS.md à la lettre refuse l'étape 9 ou 10, ou l'exécute en violant la règle. Pire : kube-ops installera CNPG dans `cnpg-system` (C7). Ce namespace porte déjà `part-of=openchoreo-lab`, donc `uninstall.sh --all` le supprimera (voir I3).
- **Correctif minimal.**
  - Renommer `cnpg-system` en `lab-cnpg` tant qu'il est vide. Fichiers à modifier : `00` et `01`, `02:229-375`, la NP `allow-intra-dns-operator` de `platform/data/lab-pg-namespace.yaml:37`, `install.sh:139`, `TRIAL_NS` et `STACK_NS_RE` (`lib.sh:23-28`), puis supprimer `cnpg-system` à la main.
  - Faire consigner par Paul, dans `MISSION.md` et `AGENTS.md`, l'exception `default` (label et objets OpenChoreo) et la suppression des `dp-*` étiquetés `cell=restricted`.

## Importants

| # | Constat | Preuve | Scénario d'échec | Correctif minimal |
|---|---|---|---|---|
| I1 | `helm uninstall` de deux charts supprime leurs CRD sans passer par `--delete-crds` (point 1) | Rendu ESO : 23 CRD sans `helm.sh/resource-policy: keep`. Rendu kgateway-crds : 8 CRD, dans `templates/`, sans `keep`. Appels dans `uninstall.sh:96-97` (`helm_rm … external-secrets`, `kgateway-crds`). | `uninstall.sh --step 4` supprime toutes les ExternalSecret et tous les ClusterSecretStore du cluster, y compris un futur Doppler de kube-ops. La garde `rm_crds` ne s'applique jamais. | `values/external-secrets.yaml` : `crds.annotations: {helm.sh/resource-policy: keep}`, puis `helm upgrade` de l'étape 4. `undo_5` : ne pas désinstaller `kgateway-crds` sans `--delete-crds`. |
| I2 | `crd_in_use_outside` laisse passer en cas d'échec et ignore les objets cluster-scoped | `uninstall.sh:42-43` : si `kubectl get` échoue, `jq -e` reçoit une entrée vide et renvoie un code non nul, lu comme « inutilisée ». Le filtre `namespace != ""` exclut ClusterIssuer, ClusterSecretStore et GatewayClass. Les CRD présentes avant l'essai ne sont jamais mémorisées (`preflight.sh:56` se contente de les lister). | Avec `--delete-crds`, une erreur d'API transitoire, ou un `ClusterSecretStore` appartenant à kube-ops, suffit à supprimer des CRD partagées. | Échouer franchement si `kubectl get` rate. Compter aussi les objets cluster-scoped qui ne portent pas `part-of=openchoreo-lab`. Enregistrer les CRD présentes au preflight (`$STATE_DIR/crds-before.txt`) et refuser de les supprimer. |
| I3 | La garde `part-of` est posée par l'installation elle-même (point 1) | `00-namespaces.yaml` (SSA de l'étape 1) et `install.sh:142` ajoutent `part-of=openchoreo-lab` à un namespace qui existait déjà. `preflight.sh:62` se contente d'un `warn`. Le test d'`uninstall.sh:108` est donc toujours vrai. | Un namespace kube-ops du même nom (`cnpg-system`, voir B3) reçoit PSA restricted et default-deny à l'étape 1, puis il est supprimé par `--all`. | `preflight.sh` : passer en `block` tout namespace de `TRIAL_NS` qui existe sans le label. `install.sh step_1` : même refus avant l'apply. |
| I4 | Rollback d'une étape alors qu'Argo tourne : `selfHeal` recrée l'objet (point 2) | `uninstall.sh:71-77` (`undo_10`), `undo_9` et `undo_7`. `lab-platform.yaml:29-31` : `selfHeal: true` sur `data/lab-pg-cluster.yaml`. | Après l'étape 11, `uninstall.sh --step 10` supprime `lab-pg` et son volume, puis Argo recrée le Cluster. On obtient un nouveau PVC et un **nouveau block volume de 50 Go**, alors que l'opérateur croit avoir annulé l'étape. | `undo_7`, `undo_9` et `undo_10` : `die` si `application/lab-platform` existe (même modèle que la garde Components de `undo_9`). |
| I5 | Droits de lecture du cluster-agent à réduire (point 6) | Détail retiré de ce dépôt public (coordination privée en cours). Correctif : RBAC par namespace de cellule ; preuves hors dépôt. | Important |
| I6 | L'agent peut réétiqueter la PSA d'un `dp-*` | VAP-1 l.46-47 autorise CREATE et UPDATE de tout `Namespace dp-*` par l'agent, sans contrôle des labels. VAP-2 ne refuse ni les capabilities ajoutées, ni seccomp `Unconfined`, ni `runAsUser: 0`. | L'agent passe `pod-security…/enforce` à `privileged` sur `dp-x`, puis crée un pod root avec `SYS_ADMIN` et seccomp `Unconfined`. VAP-2 et la baseline kube-ops (privileged, host*, hostPath) ne bloquent pas ce pod, d'où un risque d'évasion du conteneur. | VAP-1 : si `isAgent && isNamespace`, exiger `object.metadata.labels['pod-security.kubernetes.io/enforce'] == 'restricted'`. Exception prévue : `podSecurity: baseline` d'appgen ; dans ce cas, exiger `baseline` et non `privileged`. |
| I7 | Stockage : pas de StorageClass explicite, et le quota de 200 Go sera plein (point 2) | `platform/data/lab-pg-cluster.yaml:37-39` ne fixe pas de StorageClass ; son commentaire renvoie à un « overlay `oci-bv` » qui n'existe pas dans `51-lab-pg-oke-overlay.yaml`. `preflight.sh:69-72` n'affiche que la liste. `MISSION.md:5` prévoit AIOStreams « SQLite sur PVC ». `appgen.py:759-760` fixe `pvcs = len(volumes)`, sans plafond OKE. | Si la classe par défaut n'est pas `oci-bv` (ou a `reclaimPolicy: Retain`), on obtient un PVC Pending et un échec à 600 s, ou un volume orphelin facturé après le nettoyage. Après lab-pg, on est à 200/200 Go : le moindre PVC de la Phase C est facturé. | `preflight.sh` : `block` si la classe par défaut n'est pas `oci-bv` avec `reclaimPolicy: Delete`. Corriger le commentaire. Dans `clusters/oke/capabilities.yaml`, retirer `block-rwo` tant que le quota est plein : appgen refusera alors tout `storage`. |
| I8 | B8-agent : test de « connexion » faussement positif (point 5) | `verify.sh:118-119` : PASS si **n'importe quelle** condition vaut `True`. | Une condition `Created` ou `Reconciled` à `True` alors que l'agent n'est pas connecté donne un PASS qui prétend prouver la connexion mTLS. | Filtrer sur le type exact de la condition (relevé sur k3d), par exemple `select(.type=="Connected" or .type=="Ready")`. |
| I9 | Preuves de budget invalides et documentation en retard sur les faits | `budget.log` l.1-3 : « étape 3 cpu=0m mem=0Mi », écrit par une version antérieure du gate (les mesures valaient zéro), alors que `steps.log` marque les étapes 3 à 5 comme appliquées. `PHASE-B.md:3` dit encore « NON exécuté ». `PHASE-B.md:83` parle de « minimum retenu », alors que le code compare au **maximum**, et décrit une pile plus étroite que `STACK_NS_RE`. | Une relecture prend les étapes 3 à 5 pour « budget PASS ». Seule la mesure de 18:31Z (135 Mi, max) est valable. Cela contredit AGENTS.md (« PASS = preuve datée »). | Annoter `budget.log` (lignes invalidées) et mettre à jour PHASE-B §0, §4 et §8, ainsi que STATE.md. |
| I10 | La CI ne vérifie rien de `platform/**`, qu'Argo applique pourtant depuis `main` (point 7) | `ci.yaml:41` : `yamllint apps tools tests .github`, sans `platform`. Aucun job ne lance `shellcheck` sur `tools/oke`, `psa_check` ou `kubeconform` sur `platform/`. | Une PR qui casse une VAP ou un CPT passe `ci-ok`, puis Argo la synchronise automatiquement (`selfHeal`, étape 11). | Ajouter `platform` au yamllint et un job `shellcheck -x tools/oke/*.sh`. Ajouter `kubeconform` sur `platform/` avec les schémas déjà générés. |
| I11 | Le `|| true` de `stack_usage` masque une panne de kubectl (point 4) | `lib.sh:120-121` : `kubectl get pods … \| jq \| grep … \|\| true`. | Si l'appel échoue, la liste des namespaces attendus est vide et le contrôle « namespace absent du summary » est sauté. On obtient une sous-mesure qui passe le budget. | Séparer : `pods="$(kubectl get pods -A … -o json)" \|\| { unavailable …; return 4; }`, puis appliquer `grep \|\| true` sur le seul filtrage. |
| I12 | `lab-store` donne à toute cellule le mot de passe SQL des autres applications | `20-eso-lab-store.yaml:54-55` (`^dp-`, sans restriction de clé). `cnpg-lab-db.yaml:114,212` : clé prévisible `lab-pg-roles/<name>`. Le préfixe `<NAME>_` n'est imposé que par appgen (`appgen.py:391-401`). | Une ExternalSecret écrite hors appgen (MCP, agent, PR sur `generated/` qui contourne la CI) lit `lab-pg-roles/miniflux-db`. Toute cellule `pg-client` joint 5432 : la primitive « isolation SQL inter-apps » tombe. | Avant la Phase C : test de refus T09c (cellule A qui lit la clé de B). Store par cellule, ou VAP sur `ExternalSecret.spec.data[].remoteRef.key` limité à `<projet>_*`. |

## Mineurs

| # | Constat | Preuve | Correctif |
|---|---|---|---|
| m1 | Motif de B1-admission trop large : un refus de quota passe pour un refus PSA | `verify.sh:56-57` (`forbidden\|denied`). Une erreur `exceeded quota` contient « forbidden ». | Motif `violates PodSecurity "restricted` ; un second test dédié à la VAP baseline. |
| m2 | S-imds deviendra BLOCKED pour toujours après le correctif C1 | `verify.sh:207-213` : le témoin `:53` part du namespace isolé ; une fois C1 corrigé, `lab-allow-dns` n'autorise que kube-dns. | Sonder IMDS et `:53` depuis `lab-netcontrol`, non isolé, où seule `deny-imds` agit. |
| m3 | `security()` sans `trap` ; `lab-netcontrol` hors de `TRIAL_NS` | `verify.sh:198-238` ; `lib.sh:27-28`. | Ajouter `trap` de nettoyage, et `lab-netcontrol` à `TRIAL_NS` ou à `undo_1`. |
| m4 | Tag Envoy par défaut mutable ; un Gateway sans `parametersRef` aurait un Service LoadBalancer par défaut | `values/kgateway.yaml:17-18` → `KGW_DEFAULT_IMAGE_TAG=v2.3.11` (rendu). Le quota LB=0 protège les namespaces d'essai et les `dp-*`, pas `default`. | Constater ; ajouter à `verify` un contrôle « tous les Gateway portent `parametersRef` ». |
| m5 | Listener HTTP en clair (19080), `allowedRoutes: All` | Rendu DP `gateway-default`. | Une cellule peut capter le hostname d'une autre : à couvrir par un test en Phase C. |
| m6 | `capacity_gate` : division entière (70,9 % passe) ; le parseur ignore `G`, `k`, les sidecars natifs et l'overhead | `lib.sh:143-146`, `lib.sh:103-108`. | `pcpu*10` ou comparaison `rcpu*100 > acpu*70` ; ajouter `G`/`k`. |
| m7 | Numéros d'étape faux dans les commentaires | `11-gateway-tls.yaml:1` (« étape 5 », en réalité 7), `51-…:1` (« 12 », en réalité 10), `40-…:1` (« 11 », en réalité 9), `20-…:1` (« 3 », en réalité 4), `30-…:1` (« 7 », en réalité 8), `project-lab.yaml:1` (« 10 », en réalité 11), `values/openchoreo-data-plane.yaml:31-33` (« 6/9 », en réalité 7/12), `cert-manager.yaml:3,34` (ClusterIssuer inexistante, « verify --step 2 »). `PHASE-B.md:193-194` demande des actions déjà faites (`capabilities.yaml:19`, `lab-pg-namespace.yaml:8-9`). | Corriger le texte ; un rollback lu dans le mauvais ordre est le risque réel. |
| m8 | `fetch_chart` échoue sur ce poste pour Argo et CNPG | `lib.sh:192-193` : `helm pull --repo` rend l'erreur `no cached repo found … crowdsec-index.yaml` ; observé dans le scratchpad. | `HELM_REPOSITORY_CONFIG` et `HELM_REPOSITORY_CACHE` isolés dans `$STATE_DIR`. |
| m9 | Libellé de `measure.sh` non assaini | `measure.sh:14` (`../` possible). | `label="${label//[^A-Za-z0-9._-]/_}"`. |
| m10 | Le code de sortie 2 est ambigu | `verify.sh:250` (BLOCKED) contre `lib.sh:34` (`die` = 2). | `die` en 6 dans verify, ou BLOCKED en 3. |
| m11 | CI et Renovate | `renovate.json` : automerge des digests pour les actions et les `apps/**`, donc un déploiement Argo en Phase C sans revue. `ci.yaml:158` : test `grep` fragile. Le `pip` n'utilise pas de hashes. | `ci-ok` : `contains(needs.*.result, …)` ; automerge des apps seulement après la Phase C. |
| m12 | Relancer l'étape 9 ou 10 après l'étape 11 provoque un conflit SSA avec le gestionnaire d'Argo | `install.sh:36` (`KA` sans `--force-conflicts`). | Échec franc : le documenter dans PHASE-B (Argo devient seul écrivain). |

## Vérifié, sans écart

- **sha256 des charts.** Les 8 `.tgz` correspondent à `versions.env`. Les digests OCI de CP et DP correspondent au `helm pull`.
- **Pas de PVC dans les rendus.** Le StatefulSet Argo n'a pas de `volumeClaimTemplates`, et la persistance de Backstage est coupée (Backstage désactivé).
- **Pas de LoadBalancer.** Tous les Services rendus sont en ClusterIP. Le Gateway du DP référence `lab-envoy-clusterip`. Le quota `services.loadbalancers=0` couvre les namespaces d'essai et le CPT.
- **PSA.** `psa_check.py` rend rc=0, restricted partout, baseline pour le DP. L'exception baseline du DP est justifiée par le schéma du chart.
- **Images épinglées.** Aucune image rendue n'est sans digest.
- **TLS conservé.** Argo n'a pas `insecure`, Gateway en HTTPS, `tls-server-name` vérifié par la garde. Aucun secret en clair dans le dépôt.
- **CI GitHub.** `pull_request` (pas de `_target`), `permissions: contents: read`, actions épinglées par SHA, `persist-credentials: false`. Aucun `github.event.*` dans un `run`.
- **Dry-run par défaut.** `install.sh` ne fait rien sans `--apply`, et `--confirm-storage` est exigé à l'étape 10.

## Les 5 corrections à faire AVANT la prochaine étape (6, puis 7)

1. **VAP-1** (B1) : `operations` + `CONNECT`, `resources: ["*", "*/*"]`, verrou PSA sur les `Namespace dp-*` (I6), test d'exec refusé dans `verify.sh v7`. Requis avant l'étape 7 : c'est elle qui installe l'agent.
2. **Désinstallation sûre** (I1 à I4) :
   - ESO : `crds.annotations` avec `keep`, puis `helm upgrade` de l'étape 4 ;
   - pas de `helm uninstall kgateway-crds` sans `--delete-crds` ;
   - `crd_in_use_outside` doit échouer franchement et compter les objets cluster-scoped ;
   - `preflight` en BLOCK sur les namespaces préexistants ;
   - `undo_{7,9,10}` refusés tant que `lab-platform` existe.
3. **Périmètre** (B3) : renommer `cnpg-system` en `lab-cnpg` tant qu'il est vide, et faire consigner par Paul, dans MISSION.md et AGENTS.md, l'exception `default` et `dp-*`.
4. **AppProject `lab`** (B2) : retirer `Namespace`, VAP et VAPB de la whitelist ; retirer `policies/` et `lab-pg-namespace` de `include` ; mettre `Authz*` en blacklist. Pour l'étape 11, mais avant toute PR sur `platform/` ; plus I10 (CI sur `platform/**`).
5. **Intégrité des preuves et des gardes** (I8, I9, I11, m1) :
   - invalider les lignes de `budget.log` qui valent 0m/0Mi ;
   - supprimer le `|| true` de `stack_usage` ;
   - type exact de condition dans B8 ;
   - motif PSA précis dans B1 ;
   - statut et méthode (MAX) à jour dans `PHASE-B.md`.
