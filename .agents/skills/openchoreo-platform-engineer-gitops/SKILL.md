---
name: openchoreo-platform-engineer-gitops
description: Modifier un objet plateforme OpenChoreo v1.3.3 du labo (ClusterComponentType, ClusterProjectType, ClusterResourceType, ClusterTrait, Environment, DeploymentPipeline, authz, VAP) uniquement par Git sous platform/, synchronisé par Argo CD (lab-platform). À utiliser pour « ajoute un type de composant », « durcis la CCT », « corrige le quota du CPT », « ajoute un CronJob à la plateforme ». Toujours en classe REVUE ; jamais d'occ/kubectl apply.
license: Apache-2.0 (adapté de openchoreo/skills@cefd81b, voir l'en-tête)
---

<!--
Adapted from openchoreo/skills@cefd81bc16b79bd2de0f6284e6fa06d6c15825b7:
skills/openchoreo-platform-engineer-gitops/SKILL.md, references/recipes/author-componenttype.md,
references/recipes/verify-and-recover-drift.md (Apache-2.0).
Modifications : Flux remplacé par Argo CD (applications lab-crds / lab-platform / ApplicationSet lab-o, sync waves,
ServerSideApply) ; arborescence platform/ du dépôt au lieu de platform-shared/ ; « copier et durcir, ne
jamais éditer un défaut » ; postRenderValidations et allowedTraits obligatoires ; aucune écriture
occ/kubectl/MCP, même au bootstrap ; scripts fetch-page.sh / extract-resources.sh non utilisés ;
sections Flux, workflows CI, release lines (v1.4+) et plans retirées ; classe d'autonomie REVUE ;
traduction en français.
-->

# OpenChoreo, côté plateforme, par GitOps (labo)

Git est la source de vérité ; Argo CD (`lab-platform`, wave 0) applique `platform/`. Ce skill ne couvre pas les apps : pour elles, `add-app`, `fix-app` ou `openchoreo-developer-gitops`. Charger `platform-guardrails` : **toute PR de ce skill est REVUE** (label `needs-paul`, pas de merge par l'agent).

## Où vivent les objets

| Objet | Chemin | Note |
|---|---|---|
| ClusterComponentType | `platform/component-types/<nom>.yaml` | `service-restricted` aujourd'hui |
| ClusterProjectType | `platform/project-types/<nom>.yaml` | `cell-restricted` (PSA, NP, quota, LimitRange) |
| ClusterResourceType | `platform/resource-types/<nom>.yaml` | `cnpg-lab-db` (vise `lab-pg`) |
| VAP natives | `platform/policies/` | `cluster-agent-scope`, `digest-only` |
| Données (CNPG `lab-pg`) | `platform/data/` | `Prune=false,Delete=false` sur le Cluster |
| RBAC du cluster-agent | `platform/cluster-agent/` | ClusterRole réduite (E-revue rang 5) |

Après toute modification d'un type, `tools/appgen` relit `platform/` : lancer `python3 tools/appgen/appgen.py render && … check`. Les ComponentRelease embarquent le spec du type, donc **chaque app change de release** : la PR plateforme contient aussi `generated/`.

## Règles d'écriture (non négociables)

1. **Copier et durcir, jamais éditer un défaut.** Partir du sample v1.3.3 (`samples/getting-started/...`), le renommer (`*-restricted`), mettre en tête `# Adapted from openchoreo@v1.3.3:<chemin> (Apache-2.0)` et la liste des écarts, puis signaler le fichier au coordinateur pour `NOTICE`.
2. **CCT** : `allowedWorkflows: []` ; `allowedTraits` explicite ; `preRenderValidations` (digest, endpoint, auth publique) ; `postRenderValidations` qui re-vérifient le securityContext après les traits et refusent les kinds RBAC et les Services non ClusterIP ; `workloadType` immuable après création (nouveau type = nouveau nom).
3. **CPT** : labels PSA posés en **second argument** d'`oc_merge` (la constante gagne) ; `default-deny` ingress et egress + DNS ; quota avec `services.loadbalancers: "0"`. Les NP par composant d'OpenChoreo s'additionnent.
4. **CRT** : `retainPolicy: Retain` ; aucun secret superuser hors `lab-pg` ; noms de clés de store fixes (`<NOM>_PG_PASSWORD`).
5. **Jamais de nom d'environnement en dur** dans un type ou un trait : la différence entre environnements passe par `environmentConfigs`.
6. **Pas de wildcard RBAC** ; ne jamais supprimer les rôles internes (`rca-agent`, `workload-publisher`, …).
7. **Aucune écriture hors Git**, bootstrap compris : `occ apply`, `kubectl apply` et MCP en écriture sont INTERDITS. Un objet absent de Git est un orphelin à signaler.

## Étapes

```bash
git switch -c platform/<sujet> origin/main
# éditer platform/... ; YAML valide :
find platform -name '*.yaml' -exec python3 -c 'import yaml,sys;[list(yaml.safe_load_all(open(f))) for f in sys.argv[1:]]' {} +
python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py render && python3 tools/appgen/appgen.py check
git add platform generated && git commit -m "platform: <sujet>"
git push -u origin HEAD && gh pr create --title "platform: <sujet>" --label needs-paul --body-file /tmp/pr-platform.md
gh pr checks --watch --fail-fast
```

Corps de PR : objet modifié, écarts avec l'upstream, apps impactées (nouvelle release), test de refus à rejouer (APP-CONTRACT §8), rollback (`git revert` ; un `workloadType` changé n'est pas réversible).

## Vérification après le merge de Paul (lecture seule)

```bash
K="kubectl --context $KUBE_CONTEXT"
$K get applications.argoproj.io lab-platform -n argocd -o jsonpath='{.status.sync.revision} {.status.sync.status} {.status.health.status}{"\n"}'
$K get clustercomponenttypes.openchoreo.dev,clusterprojecttypes.openchoreo.dev,clusterresourcetypes.openchoreo.dev,validatingadmissionpolicies
for a in $(ls apps | grep -v '^_'); do CLUSTER_LABEL=k3d golden-paths/_checks/run-all.sh "$a" production; done
```

Échecs fréquents : `allowedTraits` qui référence un `Trait` namespacé depuis une CCT (il faut `ClusterTrait`) ; champ de schéma requis sans `default` ; contexte CEL hors de portée (`${trait.*}` dans une CCT) ; Job du CRT immuable après modification (suffixer le nom `-v2`).

## Dérive

Git a raison par défaut : Argo `selfHeal` corrige. Si le cluster a raison (Git en retard), la correction est une PR, jamais une écriture cluster.
