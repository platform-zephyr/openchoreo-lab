---
name: diagnose-app
description: Diagnostiquer en lecture seule une application du labo OpenChoreo qui ne se déploie pas ou ne répond pas (Argo OutOfSync/Degraded, ReleaseBinding non Ready, pods en erreur, ExternalSecret en échec, base non joignable). Parcourt l'échelle Git → Argo CD → OpenChoreo → cellule → pod et rend UNE cause prouvée, sans rien modifier. Utilisé seul ou par fix-app.
license: Apache-2.0 (échelle de vérification adaptée de openchoreo/skills@cefd81b, voir l'en-tête)
---

<!--
Adapted from openchoreo/skills@cefd81bc16b79bd2de0f6284e6fa06d6c15825b7:
skills/openchoreo-developer-gitops/references/recipes/verify-and-debug.md (Apache-2.0).
Modifications : Flux remplacé par Argo CD ; lecture seule stricte (aucun reconcile, apply ni exec) ;
kubectl en lecture plutôt qu'occ (pas de login interactif) ; échelle appliquée aux objets générés
par tools/appgen ; sections release lines (v1.4+) et workflow runs retirées ; traduction en français.
-->

# diagnose-app

Lecture seule. Charger `platform-guardrails` (périmètre §3, aucune valeur secrète). Raccourci : `golden-paths/_checks/run-all.sh <app> <env>` donne la photo ; ce skill explique les FAIL.

```bash
export KUBECONFIG=<kubeconfig du labo>; K="kubectl --context ${KUBE_CONTEXT:?}"
```

## Échelle (s'arrêter au premier niveau rouge : les niveaux suivants ne sont pas fiables)

1. **Git** : ce qui *doit* tourner.
   `git fetch origin && git log --oneline -5 origin/main -- apps/<app> generated/namespaces/default/projects/<app>` ;
   `python3 tools/appgen/appgen.py check`. Une PR non mergée est la cause la plus fréquente.
2. **Argo CD** : la révision est-elle appliquée ?
   `$K get applications.argoproj.io -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REV:.status.sync.revision` ;
   détail : `$K get applications.argoproj.io lab-o-<app> -n argocd -o jsonpath='{.status.operationState.message}{"\n"}{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'`.
   Ordre des waves : `lab-crds` (−1), `lab-platform` (0), ApplicationSet `lab-o` (1, une Application `lab-o-<app>` par app). Un amont bloqué bloque l'aval.
3. **OpenChoreo** : le contrôleur a-t-il rendu ?
   `$K get components.openchoreo.dev,workloads.openchoreo.dev,componentreleases.openchoreo.dev,releasebindings.openchoreo.dev,projectreleasebindings.openchoreo.dev -n default | grep <app>` ;
   `$K get releasebindings.openchoreo.dev <app>-<env> -n default -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'`.
   Conditions dans l'ordre : `ReleaseSynced` → `ResourcesReady` → `Ready`. `ResourceSyncFailed` = rendu refusé (CEL, preRender, postRender, ressource manquante) : le message dit laquelle. B : `resourcereleasebindings.openchoreo.dev <app>-db-<env>` (pin présent ?), et `$K get job,externalsecrets -n lab-pg | grep <app>`.
   Contrôleur : `$K logs -n openchoreo-control-plane deploy/openchoreo-controller-manager --tail=200 | grep -i <app>`.
4. **Cellule** : la plateforme a-t-elle posé le cadre ?
   `NS=$($K get ns -l openchoreo.dev/project=<app>,openchoreo.dev/environment=<env> -o jsonpath='{.items[0].metadata.name}')` ;
   `$K get deploy,rs,pods,svc,pvc,networkpolicies,resourcequota,externalsecrets -n $NS` ;
   `$K get events -n $NS --field-selector type=Warning --sort-by=.lastTimestamp | tail -20`.
   Le motif de refus est presque toujours dans les events : `violates PodSecurity`, `exceeded quota`, `FailedMount`, `SecretSyncedError`.
5. **Pod** : l'app elle-même.
   `$K describe pod -n $NS -l openchoreo.dev/component=<app> | sed -n '/State:/,/Ready:/p;/Events:/,$p'` ;
   `$K logs -n $NS -l openchoreo.dev/component=<app> --tail=80 | grep -iE 'error|fatal|denied|refused|timeout|read-only'`.
   Ne jamais coller de logs bruts dans une PR : extraire la ligne utile et masquer tout ce qui ressemble à un identifiant.

## Ready ≠ fonctionne

`Ready=True` = réconcilié et conteneur démarré. Aucune probe n'est rendue aujourd'hui (SCHEMA-GAPS G2). Confirmer par la santé HTTP (W8 de `check-workload.sh`) et par les redémarrages (W4).

## Sortie attendue (dans la conversation ou la PR)

```text
Niveau rouge : <1..5>  Objet : <kind/nom>  Preuve : "<message de condition ou d'event, sans secret>"
Cause : <une phrase>   Correctif Git : <champ de app.yaml | PR plateforme | MANDAT> ; classe : <AUTONOME|REVUE|MANDAT>
```

Utiliser la table de causes de `golden-paths/DEPLOY-AND-FIX-FLOW.md` §2. Si deux causes restent possibles, citer la preuve qui manque, sans deviner.
