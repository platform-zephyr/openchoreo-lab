# Checklist E : chart Helm tiers (parcours désactivé dans le pilote)

Script : `CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/check-helm.sh <app> production`. Il répond `BLOCKED H0` tant que l'ApplicationSet `lab-helm` n'existe pas.

## Avant la PR

- [ ] Chart **officiel** de l'éditeur. Version exacte, et digest si `oci://`.
- [ ] `helm template` local avec `values.yaml`. Inventaire de **tous** les kinds rendus (méthode du skill `migrate-to-openchoreo`). Aucun `CustomResourceDefinition`, `ClusterRole(Binding)`, webhook, `DaemonSet`, `hostPath`, `privileged`, ni Service `LoadBalancer`/`NodePort` ; sinon archétype F.
- [ ] Toutes les images rendues sont épinglées par digest, ou épinglables via les values.
- [ ] Tant que le parcours n'est pas activé : fichier sous `apps/_examples/<nom>/`, jamais sous `apps/<nom>/`.

## Après activation et merge (lecture seule)

| ID | Preuve attendue |
|---|---|
| H1 | Application Argo `<app>-<env>` en `Synced/Healthy` ; `targetRevision` = `chart.version` |
| H2 | Namespace en PSA `restricted` ; NetworkPolicies présentes (default-deny) |
| H3 | Services en ClusterIP ; images par digest |
| H4 | Pods `Ready` |

## Rollback

`git revert` (version du chart et values). Si le chart est stateful : `prune: false` dans Argo, et le rollback d'une version majeure est une classe protégée « données ».
