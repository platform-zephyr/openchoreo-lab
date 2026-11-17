---
name: openchoreo-developer-gitops
description: Correspondance entre les objets applicatifs OpenChoreo v1.3.3 (Project, Component, Workload, ComponentRelease, ReleaseBinding, Resource, ResourceReleaseBinding, SecretReference) et le contrat app.yaml du labo, avec leurs invariants (immuabilité, autoDeploy=false, pin des ResourceRelease). À charger pour comprendre ou expliquer ce que tools/appgen génère, lire un objet OpenChoreo dans le cluster, ou décider si un besoin applicatif tient dans le contrat. Ne génère jamais ces objets à la main.
license: Apache-2.0 (adapté de openchoreo/skills@cefd81b, voir l'en-tête)
---

<!--
Adapted from openchoreo/skills@cefd81bc16b79bd2de0f6284e6fa06d6c15825b7:
skills/openchoreo-developer-gitops/SKILL.md (section « Stable guardrails ») et
references/recipes/use-a-resource.md (Apache-2.0).
Modifications : les objets ne sont plus écrits par l'agent (ni à la main, ni via occ file-mode) mais
générés par tools/appgen depuis apps/<nom>/app.yaml ; Argo CD au lieu de Flux ; pas de build depuis la
source, de workflow, de release line (v1.4+), ni d'occ apply ou promote ; table de correspondance
avec le contrat v2alpha1 ajoutée ; traduction en français.
-->

# OpenChoreo, côté app, par GitOps (labo)

Dans ce dépôt, le développeur ou l'agent n'écrit **qu'un** fichier : `apps/<nom>/app.yaml`. `tools/appgen` produit les objets OpenChoreo sous `generated/`. Les gestes concrets sont dans `add-app`, `fix-app` et `promote-or-rollback`. Ce skill donne le modèle, pour lire le cluster et ne pas le casser.

## Correspondance contrat → objets (namespace `default`)

| `app.yaml` | Objet généré | Remarque |
|---|---|---|
| `metadata.name` | Project `<n>`, Component `<n>`, Workload `<n>-workload` | `Workload.spec.owner` est **immuable** : renommer une app = nouvelle app |
| `network.*`, `database` | `Project.spec.parameters {egress, database, allowIdp}` sur `ClusterProjectType/cell-restricted` | la cellule `dp-default-<n>-<env>-<hash>` est créée par le ProjectReleaseBinding |
| `environments[]` | ProjectReleaseBinding et ReleaseBinding `<n>-<env>` | `spec.projectRelease` est initialisé par le contrôleur, absent de Git (`ignoreDifferences`) |
| `source.image`, `runtime.*`, `secrets[]` | Workload (`container`, endpoint `http`, `env[].valueFrom.secretKeyRef`) | un endpoint `external` si `exposure.mode: public` |
| `exposure.auth`, `update.strategy`, `runtime.runAsUser` | `Component.spec.parameters` de `service-restricted` | `autoDeploy: false` toujours |
| (contenu figé) | ComponentRelease `<n>-<hash10>` | **immuable**, jamais éditée ; Argo `Prune=false,Delete=false` |
| `runtime.size`, `replicas` | `ReleaseBinding.spec.componentTypeEnvironmentConfigs` | `releaseName` = la release ci-dessus |
| `storage` | trait `persistent-volume-claim` (+ `traitEnvironmentConfigs.data.storageClass`) | `Recreate` |
| `database` | Resource `<n>-db` (`cnpg-lab-db`) + ResourceReleaseBinding `<n>-db-<env>` (`Retain`) + `dependencies.resources[].envBindings.url` | pin manuel, voir ci-dessous |
| `secrets[]` | SecretReference `<n>-secrets` (ESO) | référence seulement |

## Invariants à ne jamais violer

- **`autoDeploy: false`.** Avec `true`, le contrôleur réécrit `releaseName` et se dispute avec Argo en boucle.
- **ComponentRelease immuable.** Pour changer, on régénère (nouveau hash). Revenir en arrière = re-rendre l'ancien contenu (`git revert`).
- **ResourceRelease jamais dans Git.** Le contrôleur la coupe à chaque changement de Resource ou de CRT. On l'épingle par une 2ᵉ PR : `appgen pin-resource <n> <env> <release>`. Jamais `occ resource promote` : il patche le binding hors Git.
- **Un seul binding par (composant, environnement)** (issue upstream #5371) ; la CI le vérifie.
- **Workload `env`** : exactement l'un de `value` ou `valueFrom`. Toute valeur secrète passe par `secrets[]`.
- **`visibility: external`** seulement pour une exposition publique (classe REVUE).

## Lire l'état (lecture seule)

```bash
K="kubectl --context $KUBE_CONTEXT -n default"
$K get projects.openchoreo.dev,components.openchoreo.dev,workloads.openchoreo.dev,componentreleases.openchoreo.dev,releasebindings.openchoreo.dev,projectreleasebindings.openchoreo.dev,resources.openchoreo.dev,resourcereleasebindings.openchoreo.dev | grep -E '(^NAME|/<n>)'
$K get releasebindings.openchoreo.dev <n>-<env> -o jsonpath='{.spec.releaseName}{"\n"}{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
```

`occ` (CLI OpenChoreo) peut servir en **lecture** si une session est déjà ouverte (`occ component get <n> -n default`). `occ login` est interactif : ne pas l'ouvrir pour l'agent, et aucune commande `occ` d'écriture.

## Quand le contrat ne suffit pas

Ne pas écrire d'objet OpenChoreo à la main dans `generated/`, ni ailleurs. Ajouter l'écart à `golden-paths/SCHEMA-GAPS.md` via une PR (REVUE), ou passer par `openchoreo-platform-engineer-gitops`.
