# Chemin « upstream-natif » pour les tâches M1-M4 du banc A/B

Date : 2026-11-18 · Ticket : T-060 (recherche demandée par Paul) · Statut : `STATIC` (doc, code amont et dépôt lus ;
aucun cluster touché, aucun `occ` exécuté). Suite de [OPENCHOREO-FIDELITE-ECARTS.md](OPENCHOREO-FIDELITE-ECARTS.md)
(§E3, §E5, §E9).

## Conclusion d'abord

1. **Le chemin natif est praticable pour M1-M4 avec les seules primitives amont 1.3.x.** Un agent écrit Project,
   ProjectReleaseBinding, Component, Workload, Resource, ResourceReleaseBinding et SecretReference à la main. Il produit
   ComponentRelease et ReleaseBinding avec `occ … --mode file-system`. Promotion et retour arrière = changer
   `releaseName` d'un ReleaseBinding (FAIT, doc et code). Aucune de nos extensions plateforme ne doit être forkée pour
   cela.
2. **Il n'est pas plus praticable aujourd'hui que le chemin `app.yaml`, pour une raison commune :** `it-tools` et
   `vikunja` ne sont portés dans **aucun** des deux chemins (FAIT, `apps/it-tools/NOTES.md`,
   `apps/vikunja/NOTES.md`). Le chemin natif lève un bloquant de `vikunja` (variables de base discrètes), pas les
   autres (port 80 et répertoires nginx inscriptibles d'`it-tools` ; classe de sauvegarde de `vikunja`).
3. **Le chemin natif coûte plus de lignes écrites par l'agent** : environ 4 à 7 fichiers et 75 à 140 lignes par app,
   contre 1 fichier de 30 à 40 lignes (ESTIMATION, comptage sur `ntfy` et `miniflux`). Le critère S2 du banc (O ≤ 0,6 × K)
   devient défavorable si l'on compte ces lignes ; il dépend de la règle de comptage des sorties d'`occ`.
4. **On perd des refus avant fusion.** `occ` ne valide ni les paramètres du type ni les règles CEL : seul le contrôleur
   le fait, après la synchro (FAIT). Les refus d'`appgen validate` (digest, préfixe de secret, egress, classe de
   donnée, quota dérivé) passent à l'admission (Kyverno/VAP sur les kinds `openchoreo.dev`) ou en CI (`kyverno apply`).
   Les politiques sur les objets rendus (`dp-*`) ne changent pas.
5. **Constat indépendant du choix** : `app.yaml` exige `runtime.healthPath`, mais `appgen` ne rend **aucune sonde**
   (FAIT, grep). La panne « probe fausse » de M4 (tirage du rang 2) n'aurait donc aucun effet dans le bras O actuel.
6. **Effort de bascule : 9 tickets (≈ 3 S, 6 M).** On supprime environ 4 900 lignes (`tools/appgen`, `tests/appgen`,
   `app.schema.json`) et on réécrit 6 skills, 3 golden paths et le contrat.

Légende : **FAIT** = doc ou code lus (lien). **HYPOTHÈSE** = déduction non mesurée. **ESTIMATION** = comptage par
analogie. Effort : S ≤ 1 j, M 2 à 5 j.

## Tableau de synthèse

| Tâche | Objets écrits à la main (chemin natif) | Commandes `occ` amont (file-system) | PR | Fichiers / lignes à la main, natif (ESTIMATION) | Chemin `app.yaml` + appgen | Bloquant commun |
|---|---|---|---|---|---|---|
| M1 `it-tools` stateless privé, production | Project, ProjectReleaseBinding `production`, Component (+ trait `health-probes`), Workload | `componentrelease generate` ; `releasebinding generate --target-env production --use-pipeline standard --component-release <nom>` | 1 | 4 fichiers, ≈ 75 l. (+ 2 fichiers produits par `occ`, ≈ 470 l.) | 1 fichier, ≈ 30 l. (+ 6 fichiers rendus) | Port 80 et nginx inscriptible : extension du CCT (les deux chemins) |
| M2 `vikunja` + PostgreSQL | M1 + Resource `cnpg-lab-db`, ResourceReleaseBinding, 0 à 1 SecretReference ; Workload avec `dependencies.resources[].envBindings` discrets | idem M1 ; **aucune** commande pour épingler `resourceRelease` | 2 (pin de la ResourceRelease) | 6 à 7 fichiers, ≈ 130 l. | 1 fichier, ≈ 40 l. + extension du schéma (variables discrètes) ; 2 PR (`pin-resource`) | Classe de sauvegarde (décision de Paul, les deux chemins) |
| M3 `ntfy` : variable, hors prod, prod, annulation | Workload (1 ligne) ; ProjectReleaseBinding `development` si absent | PR 1 : `componentrelease generate` + `releasebinding generate --target-env development --use-pipeline standard` ; PR 2 : `… --target-env production --use-pipeline standard` ; PR 3 : `… --component-release <ancienne>` ou `git revert` de la PR 2 | 3 | PR 1 : 1 à 2 fichiers, ≈ 15 l. ; PR 2 et 3 : 1 ligne | PR 1 : 2 lignes dans `app.yaml` ; PR 2 : `appgen promote` ; PR 3 : 1 ligne | Aucun |
| M4 panne injectée sur `it-tools` | Workload ou Component (1 ligne) | `componentrelease generate` + `releasebinding generate … --component-release <nouvelle>` | 1 | 1 fichier, 1 ligne (+ 2 produits par `occ`) | 1 ligne dans `app.yaml` | « probe fausse » sans effet dans le chemin `app.yaml` actuel |

Livraison Argo CD, identique dans les deux chemins : ApplicationSet `lab-o`, une Application `lab-o-<app>` par dossier
de projet, projet `lab-o`, destination `default`, sans prune (FAIT, `platform/install/argocd/apps/lab-apps.yaml`).
Seul le chemin du générateur change (`generated/…` → dossier écrit par l'agent).

---

## 1. Ce que l'amont fournit (FAIT)

Sources : [openchoreo@v1.3.3](https://github.com/openchoreo/openchoreo/tree/v1.3.3) ; doc
[`version-v1.3.x`](https://github.com/openchoreo/openchoreo.github.io/tree/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x)
(commit `147f573`) ; [sample-gitops@9c057d8](https://github.com/openchoreo/sample-gitops/tree/9c057d8c0771cdcc9251704dd319d3125530d498)
(branche `main`, non versionnée par OpenChoreo : compatibilité avec 1.3.3 = HYPOTHÈSE).

### 1.1 Objets écrits dans Git

- Le dépôt GitOps contient Project, Component, Workload, ComponentRelease, ReleaseBinding, ProjectReleaseBinding,
  Resource et ResourceReleaseBinding. Promouvoir = mettre à jour le binding de l'environnement cible ; revenir en
  arrière = pointer le binding sur une release plus ancienne
  ([gitops/overview.md l.368-379](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/overview.md)).
- Exemple complet `doclet` : Project 16 l., Component 35 l., Workload 31 l., Resource 13 l.,
  ResourceReleaseBinding 13 l., ProjectReleaseBinding 12 l.
  ([sample-gitops/namespaces/default/projects/doclet](https://github.com/openchoreo/sample-gitops/tree/9c057d8c0771cdcc9251704dd319d3125530d498/namespaces/default/projects/doclet)).
  Le Workload y lie une Resource par `envBindings` à clés libres (`host`, `port`, `username`, `password`, `database`).
- `Workload.spec.dependencies.resources[].envBindings` est un `map[string]string`
  ([workload_types.go l.236-252](https://github.com/openchoreo/openchoreo/blob/v1.3.3/api/v1alpha1/workload_types.go)).
- `ReleaseBinding.spec` porte `releaseName`, `componentTypeEnvironmentConfigs`, `traitEnvironmentConfigs`,
  `workloadOverrides` (variables d'environnement par environnement) et `state`
  ([releasebinding_types.go l.158-197](https://github.com/openchoreo/openchoreo/blob/v1.3.3/api/v1alpha1/releasebinding_types.go) ;
  [environment-overrides.md](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/developer-guide/deploying-applications/environment-overrides.md)).
- `Component.spec.autoDeploy` vaut `false` par défaut
  ([component_types.go l.50-53](https://github.com/openchoreo/openchoreo/blob/v1.3.3/api/v1alpha1/component_types.go)).

### 1.2 Commandes `occ` utilisables sans cluster

| Commande | Mode | Rôle | Source |
|---|---|---|---|
| `occ workload create --mode file-system` | file-system ou API | Écrit `workload.yaml` depuis une image ou un descripteur | [cli-reference.md l.3249-3287](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/reference/cli-reference.md) |
| `occ componentrelease generate` | **file-system seulement** | Snapshot immuable Component + Workload + type + traits | idem l.1708-1748 ; [build-and-release-workflows.mdx l.73-85](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/automations/build-and-release-workflows.mdx) |
| `occ releasebinding generate --target-env E --use-pipeline P` | **file-system seulement** | Crée ou met à jour le binding ; `--component-release` explicite possible | idem l.2453-2505 ; [bulk-promote.mdx l.39-71](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/platform-engineer-guide/gitops/automations/bulk-promote.mdx) |
| `occ component scaffold`, `occ project scaffold` | **API, connexion exigée** | Gabarit depuis le schéma du type | `PreRunE: auth.RequireLogin()` ([component/cmd.go l.137](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/component/cmd.go), [project/cmd.go l.143-190](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/project/cmd.go)) |
| `occ component deploy`, `occ project deploy`, `occ resource promote` | **API, écriture** | Écrivent le cluster | [project/cmd.go l.102-139](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/project/cmd.go) ; [resource/cmd.go l.106-131](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/cmd/resource/cmd.go) ; la doc précise « update the API directly; commit binding changes when using GitOps » (overview.md l.383) |

Conséquences (FAIT) :

- Nos règles interdisent l'écriture par API ou MCP (AGENTS.md). Les commandes `deploy` et `promote` sont donc exclues.
- Les deux `scaffold` exigent une connexion au control plane. Les agents cloud n'en ont pas (STATE.md, « Accès et
  exécution »). L'agent écrit donc Project et Component sans gabarit, d'après le CCT et le CPT lus dans `platform/`.
- Aucune commande `generate` n'existe pour ProjectReleaseBinding, Resource ou ResourceReleaseBinding : les
  sous-commandes sont `list`, `get`, `delete` (et `promote` en API)
  ([internal/occ/cmd/](https://github.com/openchoreo/openchoreo/tree/v1.3.3/internal/occ/cmd)).
- `occ` s'installe depuis la release du tag (`occ_<tag>_<os>_<arch>.tar.gz`)
  ([cli-installation.mdx](https://github.com/openchoreo/openchoreo.github.io/blob/147f5730ed8727a9918abb30a5f9d1107be14a2c/versioned_docs/version-v1.3.x/getting-started/cli-installation.mdx)).

### 1.3 Comportement d'`occ` en file-system (code lu)

- **Nom de release** : `<composant>-<AAAAMMJJ>-<n>`, `n` incrémenté d'après les fichiers présents
  ([generator/namer.go l.16-31](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/generator/namer.go)).
  Le nom n'est **pas** un hash, contrairement à `appgen` (`<n>-<sha256[:10]>`).
- **Pas de doublon** : la release n'est pas écrite si sa spec égale la dernière release
  ([output/writer.go l.33-73](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/output/writer.go) ;
  comparaison par le hash du contrôleur, [output/hash.go](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/output/hash.go)).
- **Choix de la release du binding**
  ([generator/release_binding.go l.155-264](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/generator/release_binding.go)) :
  1. `--component-release` explicite : vérifiée puis utilisée ;
  2. environnement racine du pipeline : la release dont la spec égale l'état courant du composant ;
  3. autre environnement : la release du binding de l'environnement **précédent** ; erreur s'il n'existe pas.
  En mise à jour, seul `releaseName` change ; les autres champs du fichier sont conservés (l.107-117).
- **Validations** : `occ` vérifie seulement `allowedTraits` et l'unicité des instances de traits
  ([generator/component_release.go l.98-101](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/generator/component_release.go)).
  Le webhook du Component délègue la validation du schéma au contrôleur
  ([webhook/component/webhook.go l.83](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/webhook/component/webhook.go)).
  Une erreur de paramètre ou de règle CEL n'apparaît donc qu'**après la synchro**, comme condition non `Ready`.
- **Index** : `occ` indexe Component, Workload, (Cluster)ComponentType, (Cluster)Trait, ComponentRelease,
  ReleaseBinding et DeploymentPipeline sous `--root-dir`
  ([fsmode/index.go l.93-160](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/occ/fsmode/index.go)).
  Le CCT `service-restricted` et le pipeline `standard` doivent donc être lisibles sous `--root-dir`.

### 1.4 Épinglage des releases de Resource et de Project

- `ResourceReleaseBinding.spec.resourceRelease` est « advanced manually (e.g. via `occ resource promote` or
  `kubectl edit`) » ; vide, le binding reste en attente
  ([resourcereleasebinding_types.go l.29-34](https://github.com/openchoreo/openchoreo/blob/v1.3.3/api/v1alpha1/resourcereleasebinding_types.go) ;
  [resourcereleasebinding/controller.go l.113-117](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/controller/resourcereleasebinding/controller.go)).
- Le nom de la ResourceRelease est déterministe : `<resource>-<hash(type, paramètres, adresses locales)>`
  ([resource/controller.go l.93-104](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/controller/resource/controller.go),
  [controller_hash.go](https://github.com/openchoreo/openchoreo/blob/v1.3.3/internal/controller/resource/controller_hash.go)).
  Aucun outil amont ne le calcule hors ligne. Le sample `doclet` omet ce champ.
- `ProjectReleaseBinding.spec.projectRelease` : initialisé une fois par le contrôleur, puis épinglé par Git
  (APP-CONTRACT §5, prouvé sur k3d, T-PIN-STALE). Pas de générateur `occ`.

---

## 2. Chemin natif, tâche par tâche

Hypothèses de cadre (HYPOTHÈSE) :

- Racine GitOps écrite par l'agent : `gitops/namespaces/default/projects/<app>/` (même disposition que `generated/`
  et sample-gitops). `occ` est lancé avec `--root-dir` sur la racine du dépôt, pour lire `platform/`.
- `occ` v1.3.3 épinglé par sha256 dans `platform/install/versions.env`, exécuté par l'agent et rejoué en CI
  (`--dry-run`, aucune dérive).
- Le pipeline `standard` a `development` pour racine et `production` ensuite
  (`platform/install/manifests/40-openchoreo-env.yaml`).

### M1 — `it-tools` stateless privé en production

1. Écrire `project.yaml` (CPT `cell-restricted`, paramètres `egress: none`, quota par défaut) et
   `project-bindings/it-tools-production.yaml`.
2. Écrire `component.yaml` (`componentType: {kind: ClusterComponentType, name: deployment/service-restricted}`, trait
   `health-probes` autorisé par le CCT) et `workload.yaml` (image `…@sha256:`, endpoint `internal`). Ou :
   `occ workload create --mode file-system --image …`.
3. `occ componentrelease generate --mode file-system --project it-tools --component it-tools`.
4. `occ releasebinding generate --mode file-system --project it-tools --component it-tools --target-env production
   --use-pipeline standard --component-release <nom imprimé à l'étape 3>` (production n'est pas racine, §1.3).
5. Une PR ; Argo `lab-o-it-tools` synchronise ; Notifications publie le check run.

Bloquant commun (FAIT, `apps/it-tools/NOTES.md`) : l'image écoute sur 80 (nginx) et écrit dans 3 répertoires. Le CCT
ne monte que `/tmp` en `emptyDir` (`platform/component-types/service-restricted.yaml` l.138-139) et impose un uid ≥ 1000.
Les deux chemins exigent une extension du CCT, ou une autre image. Natif : la PR plateforme touche le CCT seul ; chemin
`app.yaml` : CCT + schéma + `appgen` + tests.

### M2 — `vikunja` avec PostgreSQL

1. Comme M1, plus `resources/vikunja-db.yaml` (CRT `cnpg-lab-db`, `database`, `dataClass`) et
   `resource-bindings/vikunja-db-production.yaml` (`retainPolicy: Retain`).
2. Workload : `dependencies.resources: [{ref: vikunja-db, envBindings: {host: VIKUNJA_DATABASE_HOST, port: …,
   database: …, username: …, password: …}}]`. Le CRT expose déjà ces sorties
   (`platform/resource-types/cnpg-lab-db.yaml` l.43-59). Ce point lève le bloquant n°1 de `apps/vikunja/NOTES.md`
   **sans** extension de schéma (FAIT).
3. PR 2 : épingler `resourceRelease`. Il faut lire `Resource.status.latestRelease.name` dans le cluster (§1.4). Même
   contrainte que `appgen pin-resource` (APP-CONTRACT §4.3). Les agents n'ont pas cet accès : HYPOTHÈSE, le bras O
   dépend alors du statut publié ou du coordinateur, dans les deux chemins.

Bloquant commun (FAIT, `apps/vikunja/NOTES.md` n°2) : classe de sauvegarde. Décision de Paul, indépendante du chemin.

### M3 — `ntfy` : changer une variable, valider, promouvoir, annuler

Variante « release » (modèle amont de promotion) :

1. PR 1 : modifier `NTFY_BASE_URL` dans `workload.yaml`. Ajouter `project-bindings/ntfy-development.yaml` si
   `development` n'existe pas (aujourd'hui `ntfy` est en `production` seule, `apps/ntfy/app.yaml`).
   `occ componentrelease generate` crée `ntfy-<date>-<n>` ; `occ releasebinding generate --target-env development
   --use-pipeline standard` crée le binding de développement sur cette release (racine : release égale à l'état
   courant). Le binding de production n'est pas touché.
2. PR 2 : `occ releasebinding generate --target-env production --use-pipeline standard` recopie la release de
   `development` (§1.3). Diff : 1 ligne.
3. PR 3 : `--component-release <ancienne>` sur `production`, ou `git revert` de la PR 2. Le revert est sûr : la PR 2
   ne touche que le binding, les fichiers de release restent (HYPOTHÈSE forte). Avec `appgen`, un `git revert` du
   commit qui a créé la release est refusé (`appgen check --base`, APP-CONTRACT §6).

Variante « surcharge » : `workloadOverrides.container.env` dans chaque ReleaseBinding, sans nouvelle release (FAIT,
§1.1). Plus courte, mais la sémantique de fusion des variables n'est pas lue dans le code (HYPOTHÈSE). La variante
« release » est celle que la doc amont décrit pour la promotion.

### M4 — diagnostiquer et corriger une panne injectée

- Injection (HYPOTHÈSE de harnais) : digest faux ou port faux dans `workload.yaml`, chemin de sonde faux dans le trait
  `health-probes` du `component.yaml`, puis `occ componentrelease generate` et binding.
- Diagnostic : le statut publié par Argo CD Notifications et les conditions des bindings. `occ component logs` et les
  outils MCP de logs dépendent de l'observability plane, absent du labo (FIDELITE-ECARTS §E14). Pas de différence
  entre les deux variantes du bras O.
- Correctif : 1 ligne, nouvelle release, binding avec `--component-release`.

**Constat (FAIT)** : le schéma exige `runtime.healthPath` (`docs/schema/app.schema.json` l.85, l.158-162), mais
`tools/appgen` ne rend aucune instance du trait `health-probes` et le CCT ne pose aucune sonde (grep `health`/`probe`
dans `tools/appgen/appgenlib/render*.py`, `generated/**/component.yaml`, `service-restricted.yaml`). Le rang 2 de
`tests/bench-ab/draw.yaml` tire `probe_fausse` : dans le bras O actuel, cette panne ne casserait rien (HYPOTHÈSE forte).

---

## 3. Questions de Paul

### (a) Extensions du labo compatibles sans fork

| Extension | Compatible avec le chemin natif | Détail |
|---|---|---|
| CCT `service-restricted` | **Oui** | Point d'extension amont (FIDELITE-ECARTS §E4). `occ` le lit sous `--root-dir` (§1.3). Ses `preRenderValidations` (digest, exposition authentifiée) et `postRenderValidations` restent actives, au rendu. |
| CPT `cell-restricted` | **Oui** | L'agent écrit les paramètres du Project (`egress`, `database`, `allowIdp`, `dataClass`, `quota`). Le défaut du quota est 300m / 512Mi. |
| CRT `cnpg-lab-db` | **Oui** | Sorties discrètes et `url` utilisables par `envBindings`. Épinglage manuel inchangé (§1.4). |
| Trait `persistent-volume-claim` forké (`dataClass`) | Oui techniquement, **non** au sens de Paul | C'est le fork à retirer (FIDELITE-ECARTS §E5). Natif : trait amont + label porté par le namespace (CPT) ou par une mutation Kyverno. |
| Trait `health-probes` | **Oui** | Identique à l'amont ; le natif permet enfin de l'utiliser. |
| Authz `lab-*` | **Oui** | Aucune écriture par API ; inchangé. |
| VAP (2) et Kyverno (12) | **Oui** | Elles visent les objets rendus et les namespaces, pas la façon d'écrire Git. |
| ApplicationSet `lab-o` | **Oui, à adapter** | Changer le chemin du générateur. La règle O5 d'`argo_guard.py` lit `apps/<app>/app.yaml` pour exclure les apps non OKE stateless (l.331-356) : à réécrire (lecture des Project et Resource, ou exclusion explicite). |
| `contract-guard` (T-070) | **À adapter** | Il n'admet des objets Kubernetes que dans `apps/`, `generated/`, `platform/`… ; la compatibilité du schéma `app.yaml` devient sans objet. |
| Argo `Prune=false` / `Delete=false` | **À reprendre** | Annotations aujourd'hui émises par `appgen` ; l'agent doit les écrire, ou une CI les exige. `automated.prune: false` et `preserveResourcesOnDeletion` de `lab-o` couvrent une partie (HYPOTHÈSE). |

### (b) Ce qu'on perd et ce qui se reprend nativement

| Garde-fou du contrat `app.yaml` | Où il vit aujourd'hui | Natif : repris par | Statut |
|---|---|---|---|
| Image par digest | `appgen validate` + CCT `preRenderValidations` + VAP + Kyverno K-03 | CCT (déjà) + VAP (déjà) ; refus en CI : `kyverno apply` sur `Workload` | Repris, mais le CCT refuse après la synchro |
| `autoDeploy: false` | CI `appgen check` | Défaut du CRD (§1.1) ; Kyverno sur `Component` | Repris |
| Pas de kind cluster-scoped, destination `default` | CI + AppProject `lab-o` | AppProject (déjà) | Repris |
| Exposition publique authentifiée | `appgen validate` + CCT | CCT (déjà) | Repris |
| Préfixe `<NAME>_` des clés de secret, pas de valeur en clair | `appgen validate` | Kyverno/CEL sur `SecretReference` et `Workload.env` | À écrire |
| Egress (FQDN, CIDR, IMDS refusé, Cilium requis) | `appgen validate` + CPT | CPT (rendu) + Kyverno sur `Project.spec.parameters` | À écrire ; la liste E3 d'`appgen` n'existe pas dans le CPT (`egress: none | public-internet`) |
| Classe de donnée obligatoire si base ou volume ; `irreplaceable` refusée | `appgen validate` (T-025) | CRT (`dataClass` requis, déjà) ; Kyverno sur `Resource` et `Component.traits` ; T-069 (VAP de suppression) | Partiel |
| Classe de sauvegarde, capabilities du cluster | `appgen validate` + `clusters/*/capabilities.yaml` | Aucun équivalent amont ; Kyverno ou CI | **Perdu** sans travail |
| Sondes (`healthPath`) | Exigé par le schéma, **jamais rendu** | Trait `health-probes` (amont) ; rendre obligatoire = paramètre et sonde dans le CCT | **Gain** natif |
| Quota de cellule dérivé (somme des requests + surplus RollingUpdate) | `render_native.py` l.48, `model.py` l.162 | Défaut du CPT ; l'agent calcule à la main ; ou CEL du CPT sur la taille | **Perdu** (calcul) |
| `RollingUpdate → Recreate` refusé, PVC ⇒ 1 réplica | `appgen` (A4) + CCT `preRenderValidations` | CCT (déjà, Recreate ⇒ replicas ≤ 1) ; A4 = erreur 422 de l'API à la synchro | Partiel |
| Releases en ajout seul, `releaseName` vers un fichier existant | `appgen check` + job CI `release-history` | Job CI conservé (indépendant d'appgen) ; `occ` vérifie l'existence | Repris |
| Un seul binding par (composant, environnement) | `appgen check` | `occ` met à jour le binding existant ; CI à garder | Repris |
| Refus avant fusion des erreurs de paramètres | Schéma JSON d'`app.yaml` | Aucun : validation par le contrôleur après synchro (§1.3) ; kubeconform contre les CRD ne voit pas `parameters` (`PreserveUnknownFields`) | **Perdu**, sauf outil CI dédié |
| Catalogue Backstage (`catalog-info.yaml`) | `appgen` | Le portail lit les objets OpenChoreo (HYPOTHÈSE) | À mesurer |

Synthèse : les garde-fous **de sécurité** (PSA, digest, exposition, kinds, réseau) sont déjà portés par le CCT, le CPT,
les VAP, Kyverno et l'AppProject. Ce qu'on perd, ce sont surtout les **refus précoces** (avant fusion) et les
**calculs** (quota, capabilities). Kyverno `ValidatingPolicy` en CEL peut viser les kinds `openchoreo.dev` à
l'admission et tourner hors cluster en CI (`kyverno apply`), comme les suites de `tests/kyverno/` (HYPOTHÈSE à
prouver sur un kind `openchoreo.dev`).

### (c) Un agent peut-il écrire ces objets seul ?

Oui, raisonnablement (HYPOTHÈSE argumentée) :

- La doc v1.3.x, sample-gitops et les CRD (`config/crd/bases`, déjà téléchargées par la CI pour kubeconform,
  `.github/workflows/ci.yaml` l.98-101) suffisent pour la forme.
- Les schémas de paramètres du CCT et du CPT sont dans `platform/`, lisibles par l'agent.
- `occ` en file-system tourne sans cluster ; la CI peut le rejouer en `--dry-run` et refuser une dérive.

Risques de dérive (HYPOTHÈSE, sauf mention) :

1. **Erreurs tardives** : un paramètre faux passe la CI et casse après la synchro (FAIT, §1.3). Le check run devient
   `failure` ; la boucle coûte des tours d'agent.
2. **Noms de release en conflit** : deux PR du même jour sur le même composant produisent le même
   `<composant>-<date>-<n>` (FAIT pour le nommage, namer.go ; conflit HYPOTHÈSE). `appgen` nomme par hash et n'a pas
   ce cas. Parade : rebase et regénération en CI.
3. **Objets oubliés** : ProjectReleaseBinding absent (pas de cellule), annotations Argo absentes, `owner` incohérent.
   Parade : une liste de contrôle CI par projet.
4. **Édition manuelle d'une release** : `occ` ne la détecte pas ; le job `release-history` doit la refuser.
5. **Écart de version d'`occ`** : le code prévoit l'erreur « generated by an older occ version »
   (release_binding.go l.222-238) ; épingler `occ` à la version du control plane.
6. **Épinglages manuels** (ResourceRelease, ProjectRelease) : lecture du cluster obligatoire, comme aujourd'hui.

### (d) Impact sur le banc

- Le bras O devient « primitives amont + plateforme du labo (CCT, CPT, CRT, VAP, Kyverno, authz, `lab-o`) ». Le bras K
  ne change pas. L'hypothèse H reste la même : elle compare l'exploitation par OpenChoreo au chemin kube-ops.
- **S2 (effort écrit)** : le gabarit compte « hors `generated/` »
  (`tests/bench-ab/thresholds.template.yaml` l.17). Il faut une règle : les sorties d'`occ` (`releases/`,
  `release-bindings/`) sont-elles exclues comme `generated/` ? Si oui, M1 natif ≈ 4 fichiers / 75 l. contre 2 fichiers /
  40 l. côté K (`k8s/apps-generated/idp-e2e/` de kube-ops `ef50472`) : S2 échoue probablement sur M1 et M2 (ESTIMATION).
  M2 côté K (`k8s/applications/catalog/vikunja/`, 11 fichiers, 333 l.) reste plus lourd.
- **S3 (tours, coût)** : plus de fichiers à écrire et des erreurs tardives : HYPOTHÈSE défavorable. À mesurer.
- **S6 (pièges)** : P1 (privilégié) reste contenu par le CCT et la VAP ; P2 (`kube-system`) par l'AppProject `lab-o` ;
  P3 (suppression de base) par `Prune=false`, `retainPolicy: Retain` et Kyverno `lab-protect-persistent-data`, à
  condition que l'agent ne retire pas les annotations (HYPOTHÈSE, NOT_TESTED dans les deux variantes).

| Fichier du banc (sur `main`) | Change ? | Pourquoi |
|---|---|---|
| `tools/bench-ab/graders.py` | Non | Graders sur check run et observations, indépendants du chemin |
| `tools/bench-ab/verdict.py`, `tests/bench-ab/thresholds.schema.json` | Non | Agrégation par bras |
| `tools/bench-ab/draw.py`, `tests/bench-ab/draw.yaml` | Non (code) ; **oui** (validité) | `probe_fausse` doit avoir un effet dans le bras O (§2, M4) |
| `tests/bench-ab/tasks/M*.O.yaml`, `traps/P*.O.yaml` | Non (consignes orientées résultat) | Le `repo: bras-o` désigne un SHA figé ; seul le SHA change |
| `tests/bench-ab/thresholds.template.yaml` | **Oui** | Commentaire et règle de S2 : périmètre des fichiers comptés (sorties `occ`) |
| `tests/bench-ab/test_bench_ab.py` | Peut-être | Seulement si la règle S2 devient du code (filtre de chemins) |
| Collecte `files_written` / `lines_written` (`bench-run.v1`) | **Oui** | Filtre de chemins `generated/` → `gitops/**/releases/`, `**/release-bindings/` |
| Harnais d'injection de M4 (T-486) | **Oui** | Chemins de fichiers différents ; sonde par le trait |

### (e) Effort de bascule et suppressions

| # | Ticket | Effort |
|---|---|---|
| 1 | Épingler `occ` v1.3.3 (sha256) ; job CI : `componentrelease` et `releasebinding generate --dry-run` sans dérive, kubeconform contre les CRD | S |
| 2 | Déplacer `generated/namespaces/…` vers `gitops/namespaces/…` (sans en-tête « généré ») ; adapter `lab-o`, `argo_guard.py` (O3, O5), `contract-guard`, `release-history` | M |
| 3 | Migrer les 10 apps : garder les releases nommées par hash (fichiers valides), couper une release `occ` par app, vérifier que les bindings restent sur la même spec | M |
| 4 | Refus précoces en Kyverno `ValidatingPolicy` sur les kinds `openchoreo.dev` (digest, `autoDeploy`, secrets, egress, classe de donnée, annotations Argo) + `kyverno apply` en CI | M |
| 5 | CCT : sondes (paramètre et rendu) ; extension `emptyDir` pour `it-tools` | S |
| 6 | Trait PVC amont, label `data-class` par le CPT ou Kyverno (FIDELITE-ECARTS §E5) | S |
| 7 | Réécrire les skills `add-app`, `fix-app`, `diagnose-app`, `promote-or-rollback`, `migrate-to-openchoreo`, `openchoreo-developer-gitops` (475 l. au total) et les golden paths A, B, C | M |
| 8 | Contrat court « objets natifs » à la place de `docs/APP-CONTRACT.md` ; amender ADR-0001, ADR-0005, ADR-0013 | M |
| 9 | Banc : règle S2, collecte, harnais de M4 (avant le gel de T-486) | S |

Suppressible après la bascule (FAIT pour les tailles) : `tools/appgen/` (2 179 l.), `tests/appgen/` (2 276 l.),
`docs/schema/app.schema.json` (405 l.), `apps/*/app.yaml` (10 fichiers), la partie schéma de `contract-guard`,
`clusters/*/capabilities.yaml` et `capabilities.schema.json` si plus aucun lecteur (à vérifier), les scripts
`tests/golden-path-*/make-*-pr.sh` à réécrire. À garder : CCT, CPT, CRT, traits, VAP, Kyverno, authz, `lab-o`,
`release-history`.

---

## 4. Décisions à trancher par Paul

1. **Façade ou primitives** : garder `app.yaml` (ADR-0001) avec `appgen` délégant les releases à `occ`
   (FIDELITE-ECARTS reco 4), ou passer aux objets natifs écrits par l'agent (ce document) ? Le natif retire
   ≈ 4 900 lignes et le fork de format ; il ajoute des lignes par app et retarde certains refus après la fusion.
2. **Banc** : mesurer le bras O sur le chemin final avant le gel (T-486) ? Si oui, les tickets 1 à 3 et 9 passent
   avant la passe 0 ; la date de porte 1 (2026-11-25) glisse d'environ une semaine (ESTIMATION).
3. **Règle de S2** : les fichiers produits par `occ` comptent-ils dans l'effort écrit ? À fixer avant le commit de
   `thresholds.yaml`.
4. **Refus précoces** : accepter que les erreurs de paramètres n'apparaissent qu'après la synchro, ou financer le
   ticket 4 (Kyverno sur les kinds `openchoreo.dev` + `kyverno apply` en CI) ?
5. **Garde-fous calculés** : abandonner le quota dérivé et les capabilities par cluster, ou les reporter dans le CPT
   (CEL) et Kyverno ?
6. **Sondes** : corriger tout de suite le rendu de `healthPath` dans `appgen` (indépendant du choix), sinon M4
   `probe_fausse` est invalide dans le bras O actuel.
7. **Apps du banc** : `it-tools` (port 80, nginx) et `vikunja` (classe de sauvegarde) exigent des décisions avant
   toute mesure, quel que soit le chemin.

## Méthode et limites

- Lu : code `openchoreo@v1.3.3` (`internal/occ/`, `api/v1alpha1/`, `internal/controller/`, `internal/webhook/`,
  `samples/getting-started/`) ; doc `version-v1.3.x` au commit `147f573` ; `sample-gitops@9c057d8` ; kube-ops `ef50472`
  (copie locale, apps du banc) ; dans ce dépôt : `apps/`, `generated/`, `platform/`, `tools/appgen/`, `tools/bench-ab/`,
  `tests/bench-ab/`, `docs/APP-CONTRACT.md`, ADR-0025, `docs/research/POC-OPENCHOREO-STRATEGY.md` §2.
- Non fait : aucune exécution d'`occ` ; aucun rendu ; aucune mesure. Les comptes de lignes du chemin natif sont des
  ESTIMATIONS faites à partir des objets que `appgen` produit pour `ntfy` et `miniflux`, moins les en-têtes.
- Le contenu externe a été traité comme une donnée. Aucun secret, aucune IP.
