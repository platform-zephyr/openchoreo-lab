# Choix de la base de code

Date : 2026-11-17, mise à jour avec les corrections de Paul du même jour. Cible : OpenChoreo **v1.3.3**.

- **Phase 0 sur k3d** (Mac arm64) : types durcis, tests de refus, et un Argo CD qui synchronise les CRD et les objets depuis ce dépôt.
- **OKE ensuite, seulement si le gate est franchi** : Cilium et baseline kube-ops #1620 en place, refus IMDS prouvé, accès opérateur ouvert.
- Pilote : whoami, Miniflux et AIOStreams.
- Sur OKE, ni Authentik ni pg-shared. L'OIDC passe par ThunderID, et PostgreSQL par un CNPG **éphémère** dans le namespace d'essai `lab-pg`.

Niveaux de preuve : [D] doc lue, [C] code ou fichier lu, [S] supposé.

## Décision

**Base = OpenChoreo v1.3.3 (types et samples) + disposition de dépôt de `openchoreo/sample-gitops` + contrat `platform.smadja.dev/v1` de kube-ops (code de Paul), étendu en `v2alpha1`.**

- **Rien n'est forké.** On écrit 3 objets custom OpenChoreo (1 CCT, 1 CPT, 1 CRT CNPG `lab-pg`) ; voir `APP-CONTRACT.md` §7.
- Le parcours Helm GitOps reprend le motif « `config` + `values` par app + ApplicationSet » de VizzleTF/homelab. Dans le pilote, ce parcours est **illustratif et désactivé**.
- koorikla/platform ne sert que d'**inspiration** : aucune licence, donc aucune copie.

Pourquoi : kube-ops contient déjà le contrat le plus proche du besoin. On y trouve un `app.yaml` avec un schéma strict, un digest obligatoire, une table de tailles et un préfixe de secrets. On y trouve aussi le gabarit `app-database.example.tmpl` (rôle, `Database`, Job `REVOKE CONNECT`) et la garde d'isolation (kube-ops `ef50472`) [C]. Repartir d'un dépôt tiers jetterait ce travail et ses tests. Le gabarit pg-shared sert ici de **modèle** au CRT `lab-pg`, sans viser pg-shared.

**Point à trancher par Paul.** `maturity-mandate/DECISION.md` §4 limite OpenChoreo au homelab, et l'empreinte par défaut (+650m de requests) dépasse le reliquat CPU d'OKE (seuil de 70 %). Le gate OKE doit donc inclure une empreinte mesurée sur k3d (≤ 250m). Voir `APP-CONTRACT.md` §10.

## Référence par référence

| Dépôt (commit lu) | Licence vérifiée | Ce qu'on reprend | Type de reprise | Ce qu'on rejette, et pourquoi |
|---|---|---|---|---|
| **openchoreo/sample-gitops** (`9c057d8`) | Apache-2.0 (`LICENSE`) [C] | Arborescence `namespaces/<ns>/{platform,projects/<p>/components/<c>/{component,workload}.yaml,releases/,release-bindings/}` comme **sortie du générateur**. Squelettes `platform/infra/environments/*.yaml` et `deployment-pipelines/standard.yaml` (adaptés : `production` seul, `development` en option). Convention `releases/<c>-<date>-<n>.yaml` produite par `occ` [C]. | **Copie avec attribution** (NOTICE) des 2 squelettes ; la structure est reprise par imitation. | `flux/` : Argo CD est déjà la règle (D-2026-11-15-01). `cluster-workflow-templates/argo/*` : pas de workflow plane, images préconstruites. Types **namespacés** `component-types/*` : remplacés par des types `Cluster*` durcis. `bindings/development/postgres.yaml` : `retainPolicy: Delete` détruit les données. |
| **openchoreo/skills** (`cefd81b`, métadonnées `version: 1.3.0`) | Apache-2.0 [C] | Utilisés **comme compétences d'agent**, sans copie dans ce dépôt. Utiles : `openchoreo-platform-engineer-gitops` (écrire CCT/CPT/CRT par Git), `openchoreo-developer-gitops` (`occ` en mode file-system), `migrate-to-openchoreo` (décider natif ou Helm pour une app), `openchoreo-setup` (phase k3d). | Outil, épinglé au commit | `openchoreo-developer` et `openchoreo-platform-engineer` passent par MCP **en écriture**. Cela crée des objets hors Git (E-revue T5). Ils restent en lecture seule. Les sections « v1.4+ » (release lines) ne s'appliquent pas. Les scripts `fetch-page.sh` et `preview.sh` ne sont pas exécutés. |
| **VizzleTF/homelab** (HEAD du 17/11) | MIT, © 2024-2026 VizzleTF [C] | Motif du parcours Helm : `argocd/apps/<app>/config.yaml` (chart, repoURL, version) + `values.yaml`, consommés par un ApplicationSet git-files multi-source (`$values`). Gardes `preserveResourcesOnDeletion` et `Delete=false` sur l'AppSet. Commentaire `# renovate:` sur les versions. | **Inspiration.** Si le bloc `sources`/`templatePatch` de `argocd/appsets/apps-appset.yaml` est copié, l'attribution MIT est **obligatoire** dans NOTICE. | `homelab-common` en entier (1194 lignes, OpenBao, VolSync, Wazuh). L'exemple Immich (`argocd/apps/immich`) : Immich est retiré du pilote (A1 12 Go / 200 Go), à reconsidérer sur un futur data plane homelab. |
| **onedr0p/home-ops** (HEAD du 17/11) | WTFPL v2 [C] | Conventions : `.renovaterc.json5` (automerge par type de mise à jour, `minimumReleaseAge`), composants Kustomize réutilisables pour la sauvegarde (`kubernetes/components/kopiur/backup`), `CODEOWNERS`. | Inspiration. Aucune obligation ; attribution de courtoisie. | Flux, Rook-Ceph et kopiur : hors socle (pas de Ceph ni de Longhorn sur OKE). |
| **koorikla/platform** (HEAD du 17/11) | **Aucune** : ni fichier `LICENSE`, ni licence déclarée [C] | **Idées seulement, réécrites :** (1) un contrat de secret de connexion PG **à clés fixes**, quel que soit le backend ; (2) refus à l'admission des objets CNPG bruts hors des namespaces plateforme ; (3) binding `development` laissé au contrôleur, promotion = une ligne `releaseName` dans Git, rollback = `git revert` ; (4) côté Argo, `ServerSideApply` pour les grosses CRD, retry avec backoff sur chaque Application générée ; (5) VAP qui protège les PVC de la suppression. | **Inspiration, aucune copie** | CAPI, Istio ambient, Harbor, OpenBao, Argo CD central en mode push, Crossplane (XR `PostgreSQL`), plan de build en cluster, agents IA d'OpenChoreo. |
| **kube-ops** (`ef50472`, dépôt de Paul) | Propriétaire : Paul [C] | `values.schema.json` de `platform-app` (motif de digest, `owner`, table `small`/`medium`, préfixe de secret). ApplicationSet `apps-generated` (projet fixe, `preserveResourcesOnDeletion`). Gabarit `app-database.example.tmpl` et Job d'isolation `REVOKE CONNECT` (modèle kube-ops#1593), transposés au CNPG `lab-pg`. Baseline Cilium #1620 : prérequis du gate OKE. | Réutilisation interne : copie, sans attribution. | pg-shared et Authentik : hors labo (migration en pause). Egress par FQDN : reporté, `public-internet` suffit au pilote. |
| **OpenChoreo v1.3.3** (`VERSION`) | Apache-2.0 [C] | `samples/getting-started/component-types/service.yaml` et `cluster-project-types/default.yaml` copiés puis durcis. `cluster-resource-types/postgres.yaml` ne sert que de modèle de syntaxe pour les `outputs` et le générateur ESO `Password`. Le ClusterTrait `persistent-volume-claim` est utilisé **tel quel** (AIOStreams). | **Copie avec attribution** (NOTICE). Le diff contre l'upstream est versionné. | `postgres.yaml` tel quel : StatefulSet par Resource, pas de securityContext, `retainPolicy: Delete` (E-revue K2). Le CRT vise plutôt le CNPG `lab-pg`. |

## NOTICE à créer (à la racine) dès la première copie

```text
openchoreo-lab
Copyright 2026 Paul Smadja

This product includes software adapted from:

- OpenChoreo (https://github.com/openchoreo/openchoreo), v1.3.3
  Apache License 2.0. Files adapted: samples/getting-started/component-types/service.yaml,
  samples/getting-started/cluster-project-types/default.yaml.
- openchoreo/sample-gitops (https://github.com/openchoreo/sample-gitops), commit 9c057d8
  Apache License 2.0. Repository layout; platform/infra/environments/*.yaml and
  platform/infra/deployment-pipelines/standard.yaml adapted.
- [only if copied] VizzleTF/homelab (https://github.com/VizzleTF/homelab)
  MIT License, Copyright (c) 2024-2026 VizzleTF. ApplicationSet template adapted from
  argocd/appsets/apps-appset.yaml. (Full MIT text in LICENSES/MIT-VizzleTF.txt.)

Conventions inspired by onedr0p/home-ops (WTFPL). No code from koorikla/platform
(no license) is included.
```

Chaque fichier adapté porte en en-tête `# Adapted from <dépôt>@<commit>:<chemin> (Apache-2.0)` et la liste de ses modifications. Le texte Apache-2.0 va dans `LICENSES/Apache-2.0.txt`. Le choix de licence du dépôt lui-même reste ouvert : Apache-2.0 serait cohérent avec l'upstream.
