# Profils de stockage : contrat et correspondance par cluster

Statut : **PROPOSÉ**. Rien n'est modifié dans `docs/schema/capabilities.schema.json`, `clusters/*/capabilities.yaml`, `tools/appgen` ni `APP-CONTRACT.md` : ce document décrit l'extension minimale à faire dans une PR plateforme séparée (classe REVUE). Justification : [`STORAGE-RECOMMENDATION.md`](STORAGE-RECOMMENDATION.md).

## 1. Contrat (ce que voit l'app)

L'app déclare un **profil logique**, jamais une StorageClass ni un moteur. La correspondance vit dans `clusters/<cluster>/capabilities.yaml`. Profil absent du cluster = refus par `appgen` (comme aujourd'hui pour `rwx-shared`).

| Profil | Promesse faite à l'app | Ne promet pas | Usage | Interdit |
|---|---|---|---|---|
| `ephemeral` | répertoire inscriptible, vidé à chaque redémarrage du pod ; taille bornée par `sizeLimit` (expulsion par le kubelet au dépassement [P K8s ephemeral storage]) | persistance | caches, `/tmp`, index régénérables, SQLite de cache | `backup.class` ≠ `none` |
| `fast-rwo` | volume RWO, persistant aux redémarrages, **taille appliquée** sur les clusters qui l'affichent `sizeEnforced: true`, support rapide (NVMe ou block volume) | survie à la perte du nœud (sauf sauvegarde) ; RWX | petits états applicatifs, SQLite d'app, config | > `maxSize` du cluster |
| `bulk-rwo` | volume RWO pour **gros fichiers consolidés** (médias, archives, bibliothèques) ; débit séquentiel | latence faible, fsync fréquents | médias, bibliothèques, exports | bases de données, WAL, journaux, TSDB, files d'attente (règle CI) |
| `database` | une base PostgreSQL fournie par la plateforme (CNPG), sauvegarde Barman si le cluster l'admet | un PVC monté dans l'app | toutes les bases | PVC brut pour une base ; MySQL/Mongo hors exception listée |
| `shared-rwx` | (réservé) | — | seulement si une app éligible l'exige, aucune aujourd'hui | absent de tous les clusters |

Règles transverses :
- Un volume RWO ⇒ `replicas: 1` et `update.strategy: Recreate` (déjà imposé par APP-CONTRACT).
- `backup.class: irreplaceable` exige un profil dont le cluster déclare un mécanisme hors site prouvé (`backup: [velero]` ou `database` avec `cnpg`).
- Jamais `database` ni WAL sur `bulk-rwo`, même si `bulk` a de la place (reprise de kube-ops `db-storage-golden-path.md`).
- `block-rwo` (nom actuel) reste un **alias** de `fast-rwo` pendant la transition ; `appgen` émet un avertissement.

## 2. Extension minimale du schéma (proposée, non appliquée)

Aujourd'hui `spec.storageClasses` est `{block-rwo|rwx-shared: "<StorageClass>"}`. Extension compatible : accepter les nouveaux noms et, en plus de la chaîne, un objet descriptif.

```jsonc
// docs/schema/capabilities.schema.json — spec.properties.storageClasses (proposition)
"storageClasses": {
  "type": "object", "minProperties": 1,
  "propertyNames": { "enum": ["block-rwo", "rwx-shared", "fast-rwo", "bulk-rwo", "ephemeral", "shared-rwx"] },
  "additionalProperties": {
    "oneOf": [
      { "type": "string", "pattern": "^[a-z][a-z0-9.-]*$" },
      { "type": "object", "additionalProperties": false, "required": ["kind"],
        "properties": {
          "kind": { "enum": ["pvc", "emptyDir"] },
          "storageClass": { "type": "string", "pattern": "^[a-z][a-z0-9.-]*$" },
          "maxSize": { "type": "string", "pattern": "^[0-9]+(Mi|Gi|Ti)$" },
          "minBillableSize": { "type": "string", "pattern": "^[0-9]+(Mi|Gi|Ti)$", "description": "Taille facturée minimale (OKE : 50Gi)." },
          "sizeEnforced": { "type": "boolean", "description": "true seulement si un test T-01/T-02 PASS daté le prouve." },
          "survivesNodeReplacement": { "type": "boolean" },
          "backup": { "type": "array", "items": { "enum": ["none", "velero"] } },
          "reclaimPolicy": { "enum": ["Delete", "Retain"] }
        },
        "if": { "properties": { "kind": { "const": "pvc" } } }, "then": { "required": ["kind", "storageClass"] } }
    ]
  }
}
```

Le profil `database` n'entre pas ici : il est déjà porté par `spec.databaseInstances`. `appgen` lit `maxSize` (refus au-delà), `sizeEnforced` (avertissement si `false` et taille demandée), `minBillableSize` (message « arrondi à 50 Gi facturés »).

## 3. Correspondance par cluster (exemples de `capabilities.yaml`)

### k3d (labo, aujourd'hui)

```yaml
storageClasses:
  ephemeral: {kind: emptyDir, maxSize: 2Gi}
  fast-rwo:  {kind: pvc, storageClass: local-path, maxSize: 5Gi, sizeEnforced: false,
              survivesNodeReplacement: false, backup: [none], reclaimPolicy: Delete}
  block-rwo: local-path          # alias transitoire
# bulk-rwo, shared-rwx : absents (refusés)
```

### OKE, maintenant (0 € d'OCI, aucun volume nouveau)

```yaml
storageClasses:
  ephemeral: {kind: emptyDir, maxSize: 2Gi}
# fast-rwo, bulk-rwo, block-rwo : ABSENTS. Le dernier quota (50 Go) n'est pas autorisé et sert
# de marge au remplacement du nœud (STORAGE-RECOMMENDATION §5). Une app à PVC attend ou passe
# en ephemeral + database.
databaseInstances:
  lab-pg: {resourceType: cnpg-lab-db, namespace: lab-pg, cluster: lab-pg, backup: none}
```

Changement par rapport au fichier actuel : `block-rwo: oci-bv` est **retiré** (il promettait un volume que le quota et la règle « aucun nouveau volume » n'autorisent pas). Effet : AIOStreams (SQLite sur PVC) est refusé sur OKE au lieu d'échouer au runtime ou de consommer le dernier quota. `emptyDir` sur OKE consomme le disque de démarrage (≈ 28,4 Go allouables [A]) : la somme des `maxSize` doit rester petite ; ResourceQuota `limits.ephemeral-storage` par cellule recommandé.

### OKE, si Paul autorise un volume (option V1)

```yaml
storageClasses:
  ephemeral: {kind: emptyDir, maxSize: 2Gi}
  # aucun fast-rwo : le seul volume va à la base mutualisée
databaseInstances:
  lab-pg:    {resourceType: cnpg-lab-db, namespace: lab-pg, cluster: lab-pg, backup: none}
  pg-shared: {resourceType: cnpg-shared-db, namespace: <ns>, cluster: pg-shared, backup: cnpg}
  # pg-shared : 1 PVC oci-bv 50Gi, admis seulement après restauration hors Oracle prouvée (D-2026-11-14-03)
```

### Talos homelab (cible, après migration Longhorn → OpenEBS LVM)

```yaml
storageClasses:
  ephemeral: {kind: emptyDir, maxSize: 10Gi}
  fast-rwo:  {kind: pvc, storageClass: lvm-fast, maxSize: 50Gi, sizeEnforced: true,
              survivesNodeReplacement: true, backup: [velero], reclaimPolicy: Delete}
  bulk-rwo:  {kind: pvc, storageClass: lvm-bulk, maxSize: 4Ti, sizeEnforced: true,
              survivesNodeReplacement: true, backup: [velero], reclaimPolicy: Retain}
databaseInstances:   # CNPG sur lvm-fast (données + walStorage), Barman → R2
  ...
```

`sizeEnforced: true` et `survivesNodeReplacement: true` ne s'écrivent qu'après T-01/T-02 et T-06/T-07 PASS datés.

StorageClasses Talos correspondantes (à créer dans kube-ops, pas ici) :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: lvm-fast}
provisioner: local.csi.openebs.io
parameters: {storage: lvm, volgroup: vg-fast, fsType: ext4, thinProvision: "no"}
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: lvm-bulk}
provisioner: local.csi.openebs.io
parameters: {storage: lvm, volgroup: vg-bulk, fsType: xfs, thinProvision: "no"}
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Le nom du provisionneur `local.csi.openebs.io` et `xfs` pour `bulk` sont à confirmer à l'installation [NV] ; `ext4` est la valeur par défaut documentée [P].

Config machine Talos 1.14 correspondante (VG seulement, jamais les LV des PVC) :

```yaml
apiVersion: v1alpha1
kind: LVMVolumeGroupConfig
name: vg-fast
# sélection du disque par identifiant stable (serial virtio), syntaxe exacte à reprendre de la doc 1.14 [NV]
```

Sur Talos, le VG `fast` demande un **nouveau** disque virtio sur `nvme-vm` : le disque `virtio0` actuel appartient à Longhorn (`UserVolumeConfig/k8s-fast`). La migration se fait donc à côté de Longhorn, sans toucher à ses disques.

## 4. Migration d'un PVC Longhorn vers un profil (Talos)

1. App classée (base → `database`, petits états → `fast-rwo`, gros fichiers → `bulk-rwo`).
2. Sauvegarde fraîche (Velero/Kopia ou Barman) **et** restauration testée dans un namespace jetable, checksums comparés.
3. Scale 0, copie (restauration Velero vers la nouvelle classe, ou Job `rsync` entre les deux PVC), checksums, bascule du PVC dans Git, scale 1.
4. L'ancien volume Longhorn reste 14 jours en `Retain`, puis suppression par mandat (même forme que D-2026-11-16-05).
5. Retrait de Longhorn : PR séparée quand plus aucun PV `driver.longhorn.io` n'existe.
