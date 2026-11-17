# Checklist C : HTTP + SQLite sur PVC

Script : `CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo golden-paths/_checks/run-all.sh <app> production --evidence evidence/runtime`
(enchaîne `check-gitops.sh`, `check-workload.sh` et `check-pvc.sh`)

## Avant la PR

- [ ] Les contrôles locaux de la checklist A.
- [ ] Le chemin des données de l'app est sous `storage.mountPath`, et rien d'autre n'est écrit hors de `/tmp` (rootfs en lecture seule).
- [ ] `update.strategy: Recreate` et `replicas` absent ou égal à 1.
- [ ] `cluster: oke` : classe protégée « dépense » (50 Gi facturés sur 200 Go). PR sans merge autonome.

## Après merge (lecture seule)

| ID | Preuve attendue |
|---|---|
| G1 à W8 | Comme pour l'archétype A |
| V1 | Quota de cellule `persistentvolumeclaims = 1`. **Le défaut du CPT est 0 : sans paramètre de quota, le PVC est refusé** (SCHEMA-GAPS G4) |
| V2 | Exactement 1 PVC, `Bound`, classe `local-path` (k3d) ou `oci-bv` (OKE), `ReadWriteOnce` |
| V3 | Stratégie `Recreate`, `replicas ≤ 1`, volume monté sur `mountPath`, `fsGroup` posé |
| V4 | NOT_TESTED ici. Persistance après redémarrage : test actif dans `tests/k3d` |

## Rollback

`git revert` de la PR : le PVC est **conservé**, et l'ancienne version de l'app relit des données éventuellement migrées. Si le format a changé, on vide les données (classe protégée « données », accord de Paul).
