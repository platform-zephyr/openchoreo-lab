# Fidélité à OpenChoreo 1.3.x : écarts et surcouches du labo

Date : 2026-11-18 · Ticket : T-060 (recherche demandée par Paul) · Statut : `STATIC` (doc et code lus, aucun cluster touché).

## Conclusion d'abord

1. **Le labo n'a pas de fork du cœur OpenChoreo, à une exception près.** Les charts Helm sont les charts officiels.
   Les types (CCT, CPT, CRT, traits), les rôles d'autorisation et l'ESO passent par les **points d'extension prévus
   et documentés**. Exception : le security bundle temporaire (§E17). Il impose un post-renderer et une image du
   contrôleur. Les détails sont en coordination privée avec l'amont et n'apparaissent pas ici.
2. **Les trois écarts les plus coûteux** à chaque montée de version :
   - **`app.yaml` + `tools/appgen`** : environ 2 100 lignes de code, 2 300 lignes de tests, un schéma et un contrat
     de 650 lignes. Le code **réimplémente** `occ componentrelease generate` et `occ releasebinding generate`.
     L'amont fournit ces deux commandes en mode file-system (§E3).
   - **L'outillage d'installation** : `tools/oke/` (2 649 lignes), `platform/install/manifests/` (1 471 lignes) et
     le security bundle. Il rejoue la procédure documentée de l'amont. Il ajoute aussi des post-traitements hors
     Helm, à refaire après chaque `helm upgrade` (§E7, §E17, §E2).
   - **La couche de politiques** : Kyverno (12 politiques, 1 122 lignes) et 2 VAP (278 lignes). Elle chevauche en
     partie les validations CEL du CCT. Elle est voulue par Paul (§E6).
3. **Le correctif kgateway de T-060 est à ne pas fusionner en l'état** (§E2). Les raisons :
   - il modifie le RBAC rendu par le chart, hors Helm, et doit être rejoué après chaque `helm upgrade` ;
   - son test ne prouve pas que le routage HTTPS fonctionne encore ;
   - le code de kgateway v2.3.11 lit les Secrets par un informer **cluster-wide** ; sans `list`/`watch` cluster-wide,
     cet informer échoue (hypothèse forte, non mesurée) ;
   - le droit de lecture cluster-wide des Secrets est commun aux contrôleurs Gateway API ; kube-ops l'accepte déjà
     pour l'opérateur Cilium.
4. **kgateway couvre toutes les fonctions Gateway API que kube-ops utilise réellement** (§K). Les différences sont
   opérationnelles : IP de LoadBalancer, identité réseau du proxy, pods Envoy séparés. L'amont documente aussi
   **Cilium Gateway** comme module remplaçable par `gateway.gatewayClassName`.

Légende : **FAIT** = doc ou code lus (lien). **HYPOTHÈSE** = déduction non mesurée. Verdicts : ALIGNER (revenir au
standard), GARDER (justifié), PROPOSER EN AMONT, À MESURER. Effort : S ≤ 1 j, M 2 à 5 j, L > 5 j.

## Tableau de synthèse

| # | Écart ou surcouche | Standard amont | Complexité ajoutée | Justification réelle | Verdict | Effort |
|---|---|---|---|---|---|---|
| E1 | Passerelle **kgateway** | Module par défaut, remplaçable | `values/kgateway.yaml` (30 l.), `12-gateway-parameters.yaml` (40 l.) | Défaut amont | **GARDER** (option Cilium : À MESURER) | — |
| E2 | Post-traitement RBAC kgateway (branche T-060) | Aucun ; ClusterRole du chart | 2 scripts (90 l.), 2 tests, rejeu après chaque upgrade | Exigence de sécurité de Paul (B6) | **ALIGNER** : abandonner ; **À MESURER** l'alternative | S |
| E3 | Contrat `app.yaml` + `tools/appgen` | Component + Workload en YAML, `occ … --mode file-system` | ≈ 2 100 l. de code, 2 300 l. de tests, schéma 405 l., contrat 650 l. | Surface agent unique (ADR-0001, ADR-0013) ; sécurité | **GARDER** la façade ; **ALIGNER** la génération des releases sur `occ` | M |
| E4 | CCT `service-restricted`, CPT `cell-restricted`, CRT `cnpg-lab-db` | Types personnalisés = extension prévue | 3 fichiers, ≈ 800 l. ; 247 l. de diff contre `service` | Sécurité de Paul (PSA restricted, default-deny) | **GARDER** ; **PROPOSER EN AMONT** un type durci | S par version |
| E5 | Traits `health-probes` (copie) et `persistent-volume-claim` (fork + `dataClass`) | Traits livrés par les samples | 1 fork de 7 lignes ; 1 copie | `dataClass` = choix local (ADR-0008) | `health-probes` **GARDER** ; PVC **ALIGNER** | S |
| E6 | VAP (2) et Kyverno (12) | Aucune couche d'admission livrée | 1 400 l. ; chevauchement avec le `postRender` du CCT | Décision de Paul (Kyverno obligatoire) | **GARDER** ; **À MESURER** le chevauchement | S |
| E7 | Installation par `tools/oke/install.sh` + manifests | Procédure Helm + `kubectl apply` documentée | 2 649 l. de scripts, 1 471 l. de manifests | Gardes OKE, quotas, NetworkPolicy, preuves | **GARDER** Helm officiel ; **ALIGNER** les post-traitements | M |
| E8 | `all.yaml` (types par défaut) non appliqué | Étape 4 : types, environnements, pipeline par défaut | Faible | Types amont non durcis | **GARDER** ; **À MESURER** l'effet sur `occ scaffold` et Backstage | S |
| E9 | Environments `development`/`production`, pipeline `standard`, pins de promotion | `development`/`staging`/`production`, binding édité par `occ releasebinding generate` | `promotion.py` 57 l. + fichier de pins | Frugalité (ADR-0004) | Environments **GARDER** ; pins **ALIGNER** | S |
| E10 | ApplicationSet `lab-o` (Argo CD) | Outil GitOps libre ; exemples Flux | 416 l. Argo + `argo_guard.py` 598 l. | Argo = règle de kube-ops | **GARDER** | — |
| E11 | Rôles d'autorisation `lab-*` pour agents et humains | `ClusterAuthzRole` personnalisés prévus | 414 l. | Agents en lecture seule (règle de Paul) | **GARDER** ; **PROPOSER EN AMONT** un rôle agent | — |
| E12 | RBAC complémentaire du cluster-agent (quotas, LimitRange) | Extension documentée du ClusterRole | 29 l. | Manque amont (CPT avec quota impossible sans) | **GARDER** ; **PROPOSER EN AMONT** | S |
| E13 | Store ESO `lab-store` (provider kubernetes) | OpenBao dans la procédure | 69 l. | Pas de jeton externe (choix local) | **À MESURER** (ADR-0014 vise OpenBao) | M |
| E14 | Plans observabilité et workflow non installés ; portail optionnel | Plans optionnels | Faible | Budget (ADR-0015, ADR-0017) | **GARDER** ; **À MESURER** la perte pour les agents IA | — |
| E15 | MCP en lecture seule | Skills amont : MCP en écriture | Faible | Règle GitOps de Paul | **GARDER** | — |
| E16 | `tools/k3d/ci-bootstrap.sh` | `install/k3d/k3d-install.sh` | 106 l. | Mêmes charts et pins qu'OKE | **GARDER** | — |
| E17 | Security bundle (post-renderer + image du contrôleur) | Charts et image officiels | `security-bundle.sh` 234 l. + dépôt privé | Sécurité, coordination amont privée | **GARDER temporairement**, retrait planifié | — |

---

## Détail par écart

### E1 — Passerelle kgateway

- **Amont (FAIT)** :
  - kgateway est le module par défaut. OpenChoreo « supports any Kubernetes Gateway API compliant gateway ». La doc
    cite « Traefik, Cilium Gateway, Kong, Istio, Nginx Gateway Fabric ». Source :
    [api-gateway/modules.md l.9 et l.25](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/api-gateway/modules.md).
  - Un module doit fournir une `GatewayClass` et satisfaire les `Gateway`/`HTTPRoute` créés par OpenChoreo. Source :
    [modules/building-a-module.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/modules/building-a-module.md).
  - Les charts exposent `gateway.gatewayClassName` (défaut `kgateway`). Source :
    [values DP l.58-64](https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/helm/openchoreo-data-plane/values.yaml).
    Ce point a été rendu configurable par [openchoreo#3700](https://github.com/openchoreo/openchoreo/issues/3700).
  - Les objets propres à kgateway ne sont rendus que si la classe vaut `kgateway`
    ([openchoreo#4068](https://github.com/openchoreo/openchoreo/issues/4068)). Il y en a deux sortes :
    - `HTTPListenerPolicy` (DP) : active l'upgrade WebSocket
      ([httplistenerpolicy.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/helm/openchoreo-data-plane/templates/gateway/httplistenerpolicy.yaml)) ;
    - `TrafficPolicy` (CP) : `request: 0s` et `streamIdle: 24h` pour le **streaming MCP** d'`openchoreo-api`
      ([traffic-policy.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/helm/openchoreo-control-plane/templates/openchoreo-api/traffic-policy.yaml)),
      plus des politiques semblables pour Backstage et l'assistant.
- **Nous** : kgateway v2.3.11, version de la doc v1.3.x, dans `openchoreo-control-plane`, comme la doc
  ([on-your-environment.mdx l.102-115](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/getting-started/try-it-out/on-your-environment.mdx)).
  Ajouts : `securityContext` et `resources` (le chart n'en pose pas), et un `GatewayParameters` en ClusterIP (forme
  documentée dans [api-gateway/topology.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/api-gateway/topology.md)).
- **Complexité** : 70 lignes de values et de manifest, un digest à suivre pour le contrôleur et pour Envoy.
- **Justification** : c'est le défaut amont. Aucune déformation.
- **Verdict** : **GARDER**. L'option Cilium Gateway est **À MESURER** (§K.4) sur le homelab, où Cilium porte déjà la
  Gateway API dans kube-ops. Sur OKE, la baseline kube-ops coupe la Gateway Cilium (commentaire de
  `platform/install/values/kgateway.yaml`).

### E2 — Post-traitement RBAC de kgateway (branche `claude/t-060-kgateway-sa`, commit `6966ee9`)

- **Ce que fait la branche (FAIT, lu)** :
  - `tools/oke/kgateway-rbac.py` lit le manifeste de la release. Il retire `secrets` du ClusterRole `kgateway-<ns>`.
    Il ajoute un Role et un RoleBinding `kgateway-secrets` dans `openchoreo-control-plane` et
    `openchoreo-data-plane`, avec les verbes d'origine.
  - `tools/oke/kgateway-rbac.sh` applique ce résultat en server-side apply forcé (`--force-conflicts`, field manager
    distinct de Helm), puis redémarre le contrôleur. Il est appelé après `helm upgrade` à l'étape 5.
  - Le test k3d vérifie `kubectl auth can-i` et la condition `Available` du Deployment.
- **Amont kgateway (FAIT)** :
  - Le chart v2.3.11 donne `create, delete, get, list, patch, watch` sur `secrets` et `serviceaccounts` par un
    ClusterRole ([role.yaml l.38-49](https://github.com/kgateway-dev/kgateway/blob/v2.3.11/install/helm/kgateway/templates/role.yaml)).
  - Ces droits sont générés depuis les marqueurs RBAC du code
    ([doc.go l.19 et l.29](https://github.com/kgateway-dev/kgateway/blob/v2.3.11/api/v1alpha1/kgateway/doc.go)) :
    lecture pour le contrôleur, écriture pour le « Proxy deployer ».
  - L'informer des Secrets n'a **pas de namespace** : `kclient.NewFiltered[*corev1.Secret]` avec un simple
    `FieldSelector` et un filtre d'objets en mémoire
    ([collections.go l.109-115](https://github.com/kgateway-dev/kgateway/blob/v2.3.11/pkg/pluginsdk/collections/collections.go)).
    Le réglage `discoveryNamespaceSelectors` filtre après la liste, il ne réduit pas l'appel à l'API
    ([même fichier l.98-106](https://github.com/kgateway-dev/kgateway/blob/v2.3.11/pkg/pluginsdk/collections/collections.go)).
  - Un contrôleur de démarrage crée le Secret `oauth2-hmac-secret` dans le namespace du pod
    ([bootstrap/controller.go](https://github.com/kgateway-dev/kgateway/blob/v2.3.11/pkg/kgateway/bootstrap/controller.go)).
- **Le droit est-il inhérent ? (FAIT)** :
  - **La lecture cluster-wide l'est** dans la conception actuelle. `WatchNamespaces` est refusé par l'amont
    ([kgateway#10245](https://github.com/kgateway-dev/kgateway/issues/10245), « not planned », renvoi vers
    `discoveryNamespaceSelector`).
  - Le filtrage par type de ressource est clos « not planned »
    ([kgateway#13786](https://github.com/kgateway-dev/kgateway/issues/13786)).
  - La découverte des Secrets par label est fermée sans fusion
    ([kgateway#14530](https://github.com/kgateway-dev/kgateway/pull/14530)). Elle visait la mémoire, pas le RBAC.
  - Le même droit de **lecture** existe chez **Cilium**. L'opérateur reçoit `secrets: get, list, watch` dans son
    ClusterRole dès que `gatewayAPI.enabled` vaut `true`
    ([cilium v1.20.4 clusterrole.yaml](https://github.com/cilium/cilium/blob/v1.20.4/install/kubernetes/cilium/templates/cilium-operator/clusterrole.yaml)).
    kube-ops active ce réglage
    ([cilium/values.yaml l.62-63](https://github.com/SmadjaPaul/kube-ops/blob/ef50472bc427bbb5fb342cebf2f4db408157f5b3/k8s/infrastructure/network/cilium/values.yaml)).
  - L'**écriture** cluster-wide (`create/patch/delete`) est propre à kgateway. Elle sert le déploiement des proxys.
- **Correctif amont existant (FAIT)** :
  - [kgateway#14105](https://github.com/kgateway-dev/kgateway/pull/14105), fusionnée le 2026-07-13, ajoute
    `rbac.create` (défaut `true`). Ce réglage permet de **ne pas rendre** le ClusterRole et de fournir le sien. Il est
    présent dans le chart v2.5.2
    ([role.yaml v2.5.2](https://github.com/kgateway-dev/kgateway/blob/v2.5.2/install/helm/kgateway/templates/role.yaml)),
    absent de v2.3.11.
  - Il ne retire pas le besoin de lecture cluster-wide : l'informer reste cluster-wide.
  - Aucun correctif amont ne rend la lecture des Secrets namespacée (recherche du 2026-11-18).
- **Risque du correctif (HYPOTHÈSE forte, non mesurée)** :
  - Sans `list`/`watch` cluster-wide, la liste initiale de l'informer reçoit un 403. La collection `Secrets` ne se
    synchronise jamais.
  - Le certificat TLS du listener HTTPS de `gateway-default` (dans `openchoreo-data-plane`) ne serait alors plus
    résolu, ou la configuration xDS ne serait pas publiée.
  - Le test de la branche ne lit ni `ResolvedRefs` du listener, ni une requête HTTPS de bout en bout. `Available`
    ne le prouve pas.
  - Statut du routage après correctif : **NOT_TESTED**.
- **Complexité** : 90 lignes de scripts, 2 tests, un field manager concurrent de Helm sur le ClusterRole, un
  redémarrage du contrôleur, un rejeu obligatoire après chaque upgrade. Le filtre échoue fermé si le chart change de
  forme. Le chart passe donc de « officiel » à « officiel + mutation hors Helm ».
- **Justification réelle** : le contrôle `B6-sa-effective` de `tools/oke/verify.sh` exige qu'aucun ServiceAccount du
  namespace du control plane n'accède aux Secrets. kgateway y tombe parce que la doc amont l'installe dans ce
  namespace. C'est une exigence de sécurité de Paul. Le périmètre du contrôle est un choix local.
- **Verdict** : **ALIGNER**, c'est-à-dire ne pas fusionner ce post-traitement. **À MESURER** :
  1. Prouver l'hypothèse sur k3d : appliquer la branche, puis lire `ResolvedRefs` du listener HTTPS, les logs
     `forbidden` du contrôleur et une requête HTTPS (effort S).
  2. Si Paul garde l'exigence : passer à kgateway ≥ v2.5 avec `rbac.create=false` et un ClusterRole versionné en Git.
     Ce ClusterRole garde la **lecture** cluster-wide et limite l'**écriture** par des Roles. Ce chemin est une option
     documentée du chart, pas une mutation. Il est à valider : on ne sait pas si l'écriture du deployer passe par un
     cache cluster-wide. Il faut aussi sortir de la version de kgateway citée par la doc OpenChoreo (effort M).
  3. Sinon, traiter la lecture comme un résidu accepté, comme pour l'opérateur Cilium dans kube-ops. Il faut alors
     restreindre `B6-sa-effective` aux ServiceAccounts OpenChoreo et ajouter un contrôle « aucune écriture de Secrets
     cluster-wide hors deployer » (effort S).
  4. Ou remplacer kgateway par Cilium Gateway sur le homelab (§K.4).

### E3 — Contrat `app.yaml` + `tools/appgen` au lieu des descripteurs amont

- **Amont (FAIT)** :
  - Le dépôt GitOps contient directement `component.yaml`, `workload.yaml`, `releases/` et `release-bindings/`
    ([gitops/overview.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/overview.md)).
    Les exemples sont dans [openchoreo/sample-gitops](https://github.com/openchoreo/sample-gitops).
  - `occ workload create`, `occ componentrelease generate` et `occ releasebinding generate` fonctionnent en
    `--mode file-system`
    ([build-and-release-workflows.mdx l.64-95](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/automations/build-and-release-workflows.mdx)).
  - La promotion en masse est fournie par
    [bulk-promote.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/automations/bulk-promote.mdx)
    (`--use-pipeline`).
  - Le schéma du ComponentType est le contrat pour le développeur
    ([component-types/overview.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/component-types/overview.md)).
- **Nous (FAIT)** :
  - `apps/<nom>/app.yaml` (`platform.smadja.dev/v2alpha1`, schéma `docs/schema/app.schema.json`) est compilé vers
    `generated/` au format sample-gitops.
  - `render_component.py` calcule lui-même la ComponentRelease (nom = hash SHA-256 de la spec) et les ReleaseBinding.
  - `promotion.py` reprend l'idée de `occ releasebinding generate --use-pipeline`, sans l'appeler (en-tête du fichier).
  - **Incohérence documentaire** : `docs/APP-CONTRACT.md` §0.3 dit encore « Il appelle `occ` en mode
    file-system ». Aucun appel à `occ` n'existe dans `tools/appgen/appgenlib/`.
- **Complexité** : ≈ 2 134 lignes de code, ≈ 2 276 lignes de tests, schéma de 405 lignes, contrat de 650 lignes.
  Chaque changement de CRD amont (ComponentRelease, ReleaseBinding, Workload) touche `appgen`, ses tests et le schéma.
- **Justification réelle** :
  - une seule surface d'écriture pour les agents (ADR-0001, ADR-0013) ;
  - des refus sémantiques en CI : digest, préfixe des secrets, egress, classes de données, `--allow-oke` ;
  - la reprise du contrat `v1` de kube-ops.
  - La façade est donc un choix de Paul. La réimplémentation de la génération des releases est un **choix local**.
    Aucun manque amont n'est démontré.
- **Verdict** :
  - **GARDER** la façade `app.yaml` et la validation.
  - **ALIGNER** la génération : `appgen` écrit `component.yaml` et `workload.yaml`, puis délègue ComponentRelease et
    ReleaseBinding à `occ … --mode file-system`, épinglé par version.
  - Corriger APP-CONTRACT §0.3 dans tous les cas.
  - Effort M. Gain : les montées de version d'OpenChoreo ne touchent plus le format des releases.
  - **À MESURER** avant : vérifier que le nom de release produit par `occ` reste déterministe. Le labo s'appuie sur
    l'immuabilité par hash (`load_release_history`).

### E4 — Types personnalisés : CCT `service-restricted`, CPT `cell-restricted`, CRT `cnpg-lab-db`

- **Amont (FAIT)** :
  - « In most organizations, these defaults are a starting point, not the finish line ». La doc invite à « Enforce
    best practices and security policies » par des types personnalisés
    ([component-types/overview.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/component-types/overview.md)).
  - Le ProjectType sert à « Seed every cell namespace with baseline policies: default-deny NetworkPolicies,
    ResourceQuotas » ([project-types.md l.12-19](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/project-types.md)).
  - Le CPT `default` se décrit comme un « starting template »
    ([cluster-project-types/default.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/cluster-project-types/default.yaml)).
  - Le CCT `service` amont ne pose **aucun** `securityContext`
    ([service.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/component-types/service.yaml)).
  - L'amont livre un CRT `postgres` sur StatefulSet, éphémère par défaut, `retainPolicy: Delete`
    ([postgres.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/cluster-resource-types/postgres.yaml)).
- **Nous** :
  - Copie durcie de `service`, avec un en-tête qui liste les modifications (247 lignes de diff).
  - CPT avec PSA restricted en constante, default-deny, quotas, egress paramétré.
  - CRT sur CNPG, `Retain`, secrets générés.
  - Les HTTPRoute restent standard (`gateway.networking.k8s.io/v1`), donc portables à une autre passerelle.
- **Complexité** : ≈ 800 lignes. À chaque version, il faut rejouer le diff de `service.yaml` amont sur
  `service-restricted.yaml`.
- **Justification réelle** : exigences de sécurité de Paul (ADR-0006) et protection des données (ADR-0008). Usage
  conforme au modèle amont.
- **Verdict** : **GARDER**. **PROPOSER EN AMONT** un `service` durci (PSA restricted) dans les samples. Cela
  réduirait le diff à maintenir. Effort S par version.

### E5 — Traits `health-probes` et `persistent-volume-claim`

- **Amont (FAIT)** : les deux traits sont livrés dans
  [component-traits/](https://github.com/openchoreo/openchoreo/tree/v1.3.3/samples/getting-started/component-traits)
  (`health-probes-trait.yaml`, `pvc-trait.yaml`).
- **Nous (FAIT, diff du 2026-11-18)** :
  - `health-probes` est **identique** à l'amont (bloc dans `40-openchoreo-env.yaml`).
  - `persistent-volume-claim` est un **fork** : un paramètre `dataClass` (6 lignes) et une ligne `labels` qui fusionne
    `platform.smadja.dev/data-class`.
- **Justification** : classe de donnée (T-025, ADR-0008). C'est un choix local. Le CPT pose déjà ce label sur le
  namespace.
- **Verdict** :
  - `health-probes` : **GARDER**.
  - PVC : **ALIGNER**. Revenir au trait amont et porter le label par une autre voie : namespace via le CPT, ou mutation
    Kyverno à mesurer. Autre voie : **PROPOSER EN AMONT** un paramètre `labels` générique dans le trait.
  - Effort S.

### E6 — Politiques d'admission : 2 VAP et Kyverno

- **Amont (FAIT)** : la doc v1.3.x ne cite ni Kyverno, ni Gatekeeper, ni ValidatingAdmissionPolicy (recherche dans
  `versioned_docs/version-v1.3.x`). Les garde-fous amont sont les validations CEL des types
  ([validation-rules.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/component-types/validation-rules.md)).
- **Nous** : 2 VAP (278 lignes) et 12 politiques Kyverno (1 122 lignes avec l'installation). La matrice
  d'ownership est dans `docs/KYVERNO-POLICY-CONTRACT.md`.
- **Justification réelle** : décision de Paul (« Kyverno est une primitive OBLIGATOIRE », contrat Kyverno). Les VAP
  tiennent sans webhook. kube-ops a aussi Kyverno et Gatekeeper (`k8s/infrastructure/controllers/`).
- **Effet sur OpenChoreo** : aucune déformation. Ces politiques s'ajoutent en dehors d'OpenChoreo.
  - **HYPOTHÈSE** : une politique Deny qui refuse un objet rendu par le cluster-agent bloque une release. Ce risque
    est connu (`vap-cluster-agent-scope` a été prouvé compatible sur k3d, `platform/README.md`).
- **Verdict** : **GARDER**. **À MESURER** le chevauchement : digest, `securityContext` et `Service` ClusterIP sont
  vérifiés à la fois dans le `postRender` du CCT, dans la VAP 2 et dans Kyverno K-01/K-03/K-04. Réduire là où deux
  couches visent la même cible. Effort S.

### E7 — Installation : `tools/oke/install.sh` et `platform/install/manifests/`

- **Amont (FAIT)** : Gateway API CRD, cert-manager, ESO, kgateway, OpenBao, puis charts CP/DP par
  `helm upgrade --install`. TLS, enregistrement et défauts passent par `kubectl apply`
  ([on-your-environment.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/getting-started/try-it-out/on-your-environment.mdx)).
- **Nous** :
  - **Mêmes charts officiels**, épinglés par version, digest OCI et sha256 (`platform/install/versions.env`).
  - Ajouts : namespaces, quotas, NetworkPolicy (`00`→`03`, 778 lignes), store ESO, ClusterDataPlane, Environments,
    Argo CD, CNPG, `verify.sh` (510 lignes), `uninstall.sh` (380 lignes), gardes Argo (598 lignes).
  - **Post-traitements hors Helm** :
    - recopie de la CA de `cluster-gateway` après chaque upgrade du CP ;
    - security bundle (E17) ;
    - post-traitement RBAC de kgateway si E2 est fusionné.
- **Complexité** : 2 649 lignes de scripts, 1 471 lignes de manifests. Chaque version d'OpenChoreo ou de kgateway
  demande de relire le diff de la procédure amont.
- **Justification** : gardes OKE (budget, quotas, LB interdits, PSA), preuves datées. Exigences de Paul.
- **Verdict** : **GARDER** Helm officiel et les manifests de socle. **ALIGNER** : chaque post-traitement hors Helm
  doit avoir un ticket de retrait et un équivalent amont visé (values, issue). Effort M.

### E8 — Défauts amont (`all.yaml`) non appliqués

- **Amont (FAIT)** : l'étape 4 applique `samples/getting-started/all.yaml`. Ce fichier contient 4 CCT, 5 traits,
  1 CPT, 3 CRT, 3 Environments, le pipeline `default` et les workflows
  ([on-your-environment.mdx l.502-513](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/getting-started/try-it-out/on-your-environment.mdx)).
- **Nous** : seul `health-probes` est repris (en-tête de `40-openchoreo-env.yaml`). Les types non durcis sont
  absents.
- **Verdict** : **GARDER**. **À MESURER** : les gabarits Backstage et `occ component scaffold` qui citent `service`
  ou `web-application` échouent sans ces types (HYPOTHÈSE). Effort S.

### E9 — Environments, pipeline et pins de promotion

- **Amont (FAIT)** : `development`, `staging`, `production` et le pipeline `default`
  ([environments.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/environments.yaml),
  [deployment-pipeline.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/samples/getting-started/deployment-pipeline.yaml)).
  Promouvoir = mettre à jour le binding de l'environnement cible
  ([gitops/overview.md « Deployment Strategy »](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/overview.md)).
- **Nous** : `development` et `production` sur le même data plane, pipeline `standard`. La promotion est un pin
  écrit par `appgen promote`. Le pipeline est vérifié par `tests/appgen/test_promotion.py`.
- **Justification** : frugalité (ADR-0004). Le modèle (binding = pin) est fidèle. L'outil est local.
- **Verdict** : Environments **GARDER**. Pins **ALIGNER** sur `occ releasebinding generate --use-pipeline` en même
  temps que E3. Effort S.

### E10 — ApplicationSet `lab-o` (Argo CD)

- **Amont (FAIT)** : « OpenChoreo is designed to work with any repository structure ». Les exemples utilisent Flux
  ([gitops/overview.md](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/overview.md),
  [sample-gitops/flux](https://github.com/openchoreo/sample-gitops/tree/main/flux)). L'ordre
  « cluster-scoped avant namespace-scoped » est recommandé.
- **Nous** : un ApplicationSet par dossier `generated/namespaces/default/projects/<app>`, projet `lab-o`, sans
  prune, contrôlé par `argo_guard.py`.
- **Justification** : Argo CD est la règle de kube-ops. Le guide de sécurité amont recommande aussi de séparer
  plateforme et applications par `CODEOWNERS`.
- **Verdict** : **GARDER**. Aucune déformation d'OpenChoreo.

### E11 — Autorisation : `ClusterAuthzRole` du labo

- **Amont (FAIT)** :
  - Le chart amorce `admin`, `developer`, `sre` et `platform-engineer` (values CP l.1360-1531, gabarit
    [_authz-bootstrap.tpl](https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/helm/openchoreo-control-plane/templates/authz/_authz-bootstrap.tpl)).
  - Les rôles personnalisés sont prévus
    ([authorization/custom-roles.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/authorization/custom-roles.mdx)).
- **Nous** : `lab-agent-reader`, `lab-agent-operator`, `lab-agent-forbidden` (deny), `lab-viewer`,
  `lab-developer`, `lab-platform-admin`. Les liaisons d'amorçage amont sont remplacées (contrôle `B6-no-tryout`).
- **Justification** : agents en lecture seule, aucune écriture MCP (règle de Paul).
- **Verdict** : **GARDER**. **PROPOSER EN AMONT** un rôle « agent lecture seule sans secrets » dans l'amorçage.

### E12 — RBAC complémentaire du cluster-agent

- **Amont (FAIT)** :
  - Ajouter un ClusterRole au cluster-agent est la voie documentée
    ([cluster-agent-rbac.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/cluster-agent-rbac.mdx)).
  - Le ClusterRole du chart ne contient ni `resourcequotas` ni `limitranges`
    ([clusterrole.yaml](https://github.com/openchoreo/openchoreo/blob/v1.3.3/install/helm/openchoreo-data-plane/templates/cluster-agent/clusterrole.yaml)).
    La doc des ProjectTypes montre pourtant un `ResourceQuota`.
  - Une PR amont les ajoutait. Elle est fermée sans fusion
    ([openchoreo#4510](https://github.com/openchoreo/openchoreo/pull/4510)).
- **Verdict** : **GARDER** `extra-rbac-quota.yaml`. **PROPOSER EN AMONT** une issue limitée à ce manque fonctionnel.
  Effort S.

### E13 — Store ESO `lab-store` au lieu d'OpenBao

- **Amont (FAIT)** : la procédure installe OpenBao et un `ClusterSecretStore` vers OpenBao
  ([on-your-environment.mdx l.118-146](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/getting-started/try-it-out/on-your-environment.mdx)).
  Tout provider ESO convient
  ([secret-management.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/platform-engineer-guide/secret-management.mdx)).
- **Nous** : provider `kubernetes` vers le namespace `lab-secrets`, avec un générateur `Password` et un PushSecret.
- **Justification** : choix local (pas de jeton externe). ADR-0014 (PROPOSÉ) vise OpenBao, ce qui rejoindrait l'amont.
- **Verdict** : **À MESURER** dans le cadre d'ADR-0014. Effort M.

### E14 — Services prévus non installés : observabilité, workflow plane, portail

- **Amont (FAIT)** :
  - Les plans workflow et observabilité sont optionnels (étapes 6 et 7 de
    [on-your-environment.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/getting-started/try-it-out/on-your-environment.mdx)).
  - Les agents IA amont (SRE, FinOps) et les outils MCP de logs et de métriques s'appuient sur l'observability plane
    ([ai/overview.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/ai/overview.mdx),
    [reference/mcp-servers.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/reference/mcp-servers.mdx)).
- **Nous** : pas d'observability plane (ADR-0011, ADR-0015 : Grafana Cloud). Pas de workflow plane (images
  préconstruites, `allowedWorkflows: []`). Portail en étape optionnelle 6b.
- **Verdict** : **GARDER** pour le budget. **À MESURER** : pour un IDP « pour agents IA », quels outils MCP restent
  vides sans observability plane (HYPOTHÈSE : logs, métriques, traces, alertes). Effort S de mesure.

### E15 — MCP en lecture seule

- **Amont (FAIT)** : les serveurs MCP exposent lecture et écriture
  ([mcp-servers.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/main/versioned_docs/version-v1.3.x/reference/mcp-servers.mdx)).
  Les skills amont écrivent par MCP (`docs/BASE-CHOICE.md`, ligne `openchoreo/skills`).
- **Nous** : écriture interdite, tout changement passe par PR (AGENTS.md).
- **Verdict** : **GARDER**. C'est une règle de Paul, portée par l'autorisation native.

### E16 — `tools/k3d/ci-bootstrap.sh`

- **Amont (FAIT)** : [install/k3d/k3d-install.sh](https://github.com/openchoreo/openchoreo/tree/v1.3.3/install/k3d).
- **Nous** : 106 lignes. Les étapes reprennent `install.sh` avec les mêmes pins, sans les gardes OKE.
- **Verdict** : **GARDER**. La CI teste ainsi les mêmes artefacts qu'OKE.

### E17 — Security bundle (temporaire)

- **Amont** : charts et image officiels.
- **Nous** : `helm_secure` impose un post-renderer et une image du contrôleur épinglée par digest. Il interdit
  `helm rollback` direct (`docs/SECURITY-BUNDLE.md`). C'est le **seul fork effectif** du code amont.
- **Justification** : sécurité, avec une coordination amont en cours. Aucun détail ici (règle de `STATE.md`).
- **Verdict** : **GARDER temporairement**. Le plan de retrait existe (`docs/SECURITY-BUNDLE.md`, « Plan de
  retrait »). Revenir aux artefacts officiels dès la publication du correctif.

---

## K. kgateway contre la Gateway API de kube-ops

Source kube-ops lue : commit [`ef50472`](https://github.com/SmadjaPaul/kube-ops/tree/ef50472bc427bbb5fb342cebf2f4db408157f5b3),
dépôt public, 2026-11-17. Conformité :
[rapport kgateway v2.1.0](https://github.com/kubernetes-sigs/gateway-api/blob/main/conformance/reports/v1.4.0/kgateway/v2.1.0-report.yaml)
et [rapport Cilium 1.19.0-pre.2](https://github.com/kubernetes-sigs/gateway-api/blob/main/conformance/reports/v1.4.0/cilium/experimental-v1.19.0-pre.2-default-report.yaml)
(Gateway API v1.4.0). Ces versions sont antérieures à kgateway v2.3.11 et à Cilium 1.20.4 : c'est une borne basse.

### K.1 Fonctions que kube-ops utilise réellement (FAIT, grep des manifests)

| Fonction | Où dans kube-ops | kgateway | Cilium (référence kube-ops) |
|---|---|---|---|
| `GatewayClass`, `Gateway` v1, plusieurs listeners HTTPS (wildcard, apex, autre domaine) | [gateway/gw-internal.yaml, gw-external.yaml](https://github.com/SmadjaPaul/kube-ops/tree/ef50472bc427bbb5fb342cebf2f4db408157f5b3/k8s/infrastructure/network/gateway) | Oui (core GATEWAY-HTTP/TLS) | Oui |
| TLS terminé, `certificateRefs` vers un Secret cert-manager du namespace `gateway` | idem, `cert-*.yaml` | Oui (core) | Oui |
| `allowedRoutes.namespaces.from: All` | idem | Oui (core) | Oui |
| HTTPRoute : `hostnames`, `PathPrefix` (24), `Exact` (4) | 46 HTTPRoute (`k8s/applications/**`) | Oui (core) | Oui |
| HTTPRoute : `method: POST` | `mastra-factory/httproute-webhook-external.yaml` | Oui (`HTTPRouteMethodMatching`) | Oui |
| HTTPRoute : `timeouts.request: "0s"` | `ai/opencode/http-route.yaml` | Oui (`HTTPRouteRequestTimeout`) | Oui |
| HTTPRoute : filtre `ResponseHeaderModifier` | `ai/opencode/http-route.yaml` | Oui (`HTTPRouteResponseHeaderModification`) | Oui |
| HTTPRoute attachée à 2 Gateways ; `sectionName` (2 usages) | `media/aiostreams/family-http-route.yaml` (2 Gateways) | Oui (core) | Oui |
| `ReferenceGrant` (5) : backend dans un autre namespace (KEDA, outpost Authentik) | `controllers/keda/*-referencegrant.yaml`, `auth/authentik/referencegrant.yaml` | Oui (core, tests cross-namespace) | Oui |
| `TCPRoute` (1, MQTT, `parentRefs.port: 1883`) | `automation/mqtt/tcp-route.yaml` | Oui (suite e2e [tcproute](https://github.com/kgateway-dev/kgateway/tree/v2.3.11/test/e2e/features/services/tcproute)) | NOT_PROVEN |
| Flux longs (SSE : en-têtes `text/event-stream`, `request: 0s`) | `ai/opencode/http-route.yaml` | Oui (`HTTPRouteBackendProtocolWebSocket` ; `HTTPListenerPolicy` amont) | Oui |
| CRD Gateway API **standard** v1.6.1 | [gateway-api/kustomization.yaml](https://github.com/SmadjaPaul/kube-ops/blob/ef50472bc427bbb5fb342cebf2f4db408157f5b3/k8s/infrastructure/network/gateway-api/kustomization.yaml) | Labo en v1.5.1 (version pinnée par la doc OpenChoreo) | — |

Remarque (FAIT) : la `Gateway internal` de kube-ops n'a **aucun listener TCP 1883**. La `TCPRoute` MQTT ne peut donc
pas s'y attacher, quelle que soit l'implémentation (HYPOTHÈSE : route non `Accepted`).

### K.2 Fonctions que kgateway couvre et que kube-ops n'utilise pas

`TrafficPolicy` (timeouts de flux, CORS, auth externe, rate limit), `HTTPListenerPolicy`, `GatewayParameters`.
OpenChoreo s'en sert pour WebSocket et pour le streaming MCP (§E1).

### K.3 Différences réelles (hors API)

| Point | kube-ops (Cilium) | kgateway | Effet |
|---|---|---|---|
| Plan de données | Envoy embarqué dans l'agent Cilium | Pods Envoy par Gateway, rendus par le deployer | Pods en plus ; requests posées à 48 Mi dans le labo |
| Adresse | Service LoadBalancer + LB-IPAM/L2 (`l2-pool`) | Service par `GatewayParameters` (ClusterIP dans le labo) | Exposition par tunnel prévue dans le labo |
| NetworkPolicy | Identité `ingress`/host de Cilium (`charts/platform-app/templates/network.yaml`) | Pods proxy avec labels | Règles d'ingress différentes |
| RBAC Secrets | Opérateur : `get/list/watch` cluster-wide (§E2) | Contrôleur : `get/list/watch` **et** `create/patch/delete` cluster-wide | Seul l'écart d'**écriture** est spécifique à kgateway |
| Conformité non supportée | `HTTPRouteCORS`, `HTTPRouteParentRefPort` | `GatewayPort8080`, `GatewayInfrastructurePropagation`, `HTTPRouteCORS`, mirroirs multiples | Aucune de ces fonctions n'est utilisée par kube-ops |

**Verdict K** : kgateway couvre **toutes** les fonctions API que kube-ops utilise. La condition de Paul
(« mêmes fonctionnalités ») est remplie au niveau API (FAIT, conformité et grep). Elle n'est **pas prouvée en
runtime** dans le labo : aucun test HTTPS de bout en bout n'est daté. Statut : `NOT_TESTED`.

### K.4 Option : Cilium Gateway pour OpenChoreo (homelab seulement)

- **FAIT** : l'amont l'autorise (`gateway.gatewayClassName`, §E1). Les CCT du labo produisent des HTTPRoute standard.
- **Perte connue (FAIT)** : les `TrafficPolicy` et `HTTPListenerPolicy` ne sont plus rendues. Il n'y a plus
  d'équivalent standard pour `streamIdle: 24h` (streaming MCP).
- **HYPOTHÈSE** : les sessions MCP longues seraient coupées par le timeout d'inactivité de l'Envoy Cilium.
- **Gain** : plus de kgateway, plus de résidu T-060, même modèle que kube-ops.
- **Verdict** : **À MESURER** sur la VM Talos « lab ». Points à mesurer : une session MCP de 30 minutes via Cilium
  Gateway, WebSocket, et le statut `Programmed` des Gateways OpenChoreo. Effort M.

---

## Recommandations ordonnées

1. **Ne pas fusionner `claude/t-060-kgateway-sa`.** Faire d'abord la mesure k3d du §E2.1 (S) : `ResolvedRefs` du
   listener HTTPS, logs `forbidden`, requête HTTPS. Si le routage casse, la branche est réfutée.
   **Paul tranche** : le droit de **lecture** cluster-wide des Secrets d'un contrôleur Gateway API est-il un résidu
   acceptable, comme pour Cilium dans kube-ops ? Si oui, restreindre `B6-sa-effective` aux SA OpenChoreo et ajouter
   un contrôle ciblé sur l'**écriture**.
2. **Si Paul refuse ce résidu** : choisir entre kgateway ≥ v2.5 avec `rbac.create=false` et un ClusterRole versionné
   en Git (M), et Cilium Gateway sur le homelab (M, §K.4). **Paul tranche** l'option et accepte de sortir de la
   version de kgateway citée par la doc OpenChoreo.
3. **Corriger `docs/APP-CONTRACT.md` §0.3** : `appgen` n'appelle pas `occ` (S, sans décision).
4. **Déléguer la génération des ComponentRelease et ReleaseBinding à `occ --mode file-system`** dans `appgen`, en
   gardant la façade `app.yaml` (M). **Paul tranche** : garde-t-on la façade `app.yaml` à long terme, ou les agents
   écrivent-ils `component.yaml` et `workload.yaml` amont, validés par le schéma du CCT ?
5. **Revenir au trait `persistent-volume-claim` amont** et porter `data-class` autrement (S).
6. **Mesurer le chevauchement CCT `postRender` / VAP / Kyverno** et retirer les doublons sur une même cible (S).
7. **Ouvrir deux issues amont** (S, Paul valide la publication) : `resourcequotas`/`limitranges` du cluster-agent, et
   un `service` durci PSA restricted dans les samples. Ne rien publier qui touche la coordination privée.
8. **Mesurer ce que les agents perdent sans observability plane** (outils MCP vides) avant de figer ADR-0015 (S).
   **Paul tranche** le budget.
9. **Lier chaque post-traitement hors Helm à un ticket de retrait** (CA de `cluster-gateway`, security bundle,
   E2 s'il revient) (S).

## Méthode et limites

- **Sources lues** :
  - [openchoreo/openchoreo@v1.3.3](https://github.com/openchoreo/openchoreo/tree/v1.3.3) : charts, samples ;
  - [openchoreo/openchoreo.github.io](https://github.com/openchoreo/openchoreo.github.io/tree/main/versioned_docs/version-v1.3.x)
    (`version-v1.3.x`) ;
  - [openchoreo/sample-gitops](https://github.com/openchoreo/sample-gitops) ;
  - [kgateway-dev/kgateway@v2.3.11](https://github.com/kgateway-dev/kgateway/tree/v2.3.11) ;
  - [SmadjaPaul/kube-ops@ef50472](https://github.com/SmadjaPaul/kube-ops/tree/ef50472bc427bbb5fb342cebf2f4db408157f5b3) ;
  - issues et PR citées (recherche GitHub du 2026-11-18).
- **Non lu** : `gateway-api.sigs.k8s.io` (hôte bloqué par le réseau de la session). Les rapports de conformité ont été
  lus directement dans le dépôt `kubernetes-sigs/gateway-api`.
- **Aucune mesure runtime** : tous les verdicts sont au niveau `STATIC`. k3d n'est pas OKE.
- Le contenu externe a été traité comme une donnée.
