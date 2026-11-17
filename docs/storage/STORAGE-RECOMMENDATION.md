# Stockage OKE et Talos : recommandation

Statut : **PROPOSÉ** (étude, rien n'est installé ni exécuté). Date : 2026-11-17. Flux 3.
Entrées : [`OKE-AUDIT-2026-11-17.md`](OKE-AUDIT-2026-11-17.md) (faits mesurés OKE), kube-ops et homelab-infra `origin/main` (lecture seule), sources primaires web.
Suites : [`STORAGE-PROFILES.md`](STORAGE-PROFILES.md) (contrat), [`TEST-PLAN.md`](TEST-PLAN.md) (+ `tests/storage/*.sh`, **non exécutés**), [`OPENBAO-DOPPLER-ESO.md`](OPENBAO-DOPPLER-ESO.md).

Légende des preuves : **[P]** source primaire (doc officielle, manifeste amont) ; **[D]** dépôt de Paul (`origin/main`, chemin cité) ; **[A]** audit OKE du 17/11 ; **[NV]** NON VÉRIFIÉ (aucune source primaire trouvée dans cette passe) ; **[T]** à prouver par `tests/storage` (ID du test).

## 1. Conclusion

| Environnement | Recommandation | Utilisable | Dépense OCI |
|---|---|---|---|
| **OKE, maintenant** | **Aucun moteur de stockage ajouté.** Profils exposés : `ephemeral` (emptyDir avec `sizeLimit`) et `database` (CNPG `lab-pg`, donc `backup.class` ≤ `regenerable`). `fast-rwo`/`bulk-rwo` **absents** des capabilities OKE : appgen refuse, l'app attend ou passe en `ephemeral`. | oui, sans rien installer | 0 € |
| OKE, si Paul autorise **un** volume | **Option V1** (préférée) : un seul PVC `oci-bv` de 50 Go pour un CNPG mutualisé (`pg-shared`), qui porte toutes les bases. Applique D-2026-11-11-17 (« PostgreSQL mutualisé plutôt qu'une base par application, à cause de la taille minimale des block volumes ») sans nouveau moteur. Les petits fichiers d'app vont en base ou sur R2, pas sur PVC. | après restauration hors Oracle prouvée (D-2026-11-14-03) | 0 € dans le quota, mais **consomme la marge de remplacement du nœud** (§5) |
| **Talos/Proxmox** | **Remplacer Longhorn V1, app par app, par OpenEBS LocalPV‑LVM en volumes épais (thick)** : un VG `fast` sur NVMe, un VG `bulk` sur le zvol HDD, déclarés par Talos 1.14 `LVMVolumeGroupConfig`. Placement imposé par profil (aucune base sur `bulk`). Sauvegarde hors cluster par CNPG Barman (bases) et Velero/Kopia (fichiers) vers R2, déjà en place. Longhorn reste jusqu'à la migration du dernier volume (D-2026-11-11-05, D-2026-11-11-06). | après T-01…T-09 sur VM jetable, puis montée Talos 1.13.10 → 1.14 | n/a |
| k3d (labo) | `local-path` (déjà là), profil `fast-rwo` = `local-path`, sans garantie de taille. | oui | n/a |

**Ce qui ne retarde pas OpenChoreo** : le golden path `whoami` (stateless) et Miniflux + `lab-pg` (profil `database`, CNPG) fonctionnent sur OKE sans aucun nouveau volume ni moteur. AIOStreams (SQLite sur PVC) reste bloqué sur OKE tant qu'aucun volume n'est autorisé ; sur k3d il passe avec `local-path`.

**Pourquoi pas `local-path`/OpenEBS Hostpath sur OKE maintenant** : ils écriraient sur le disque de démarrage (allocatable ≈ 28,4 Go partagés avec images et journaux [A]) ; `local-path` n'applique aucune taille (« No support for the volume capacity limit currently » [P local-path README]) ; les quotas OpenEBS Hostpath exigent un système de fichiers monté avec project quota, ce que la racine d'un nœud OKE géré n'offre pas sans changer l'image [NV] ; les données disparaissent au remplacement du nœud **et** au remplacement du boot volume [P OKE BVR] ; le helper pod monte un `hostPath`, refusé partout sauf `kube-system` et `cloudflared` par la VAP `baseline-pod-hardening` (Deny) [D `tests/vap/fixtures/baseline-oke-export.json`] ; Velero ne sauvegarde pas les volumes `hostPath` (le type par défaut de `local-path`) [P Velero FSB]. Un remplissage fait passer le nœud en DiskPressure et expulse aussi les pods système. Le gain (quelques Go persistants non sauvegardés) ne vaut pas ce risque.

## 2. Gain d'exploitation sur Talos, par incident constaté

Le changement de moteur ne règle pas tout : la moitié des incidents vient de la politique (Retain, placement), pas de Longhorn. Le tableau sépare les deux.

| Incident (source) | Cause | Ce que change OpenEBS LVM thick | Ce qui doit changer quel que soit le moteur |
|---|---|---|---|
| 99 volumes détachés, dont 87 PV `Released` sans PVC, `atlantis-apps-data` faulted (kube-ops `longhorn/values.yaml`, relevé du 12/11) [D] | `reclaimPolicy: Retain` sur les deux classes sans nettoyage ; états Longhorn (detached/faulted/salvage) | Un PV = un LV. États possibles : présent ou absent (`lvs`). Plus d'état « detached » ni « faulted » propre au moteur ; plus de cycle attach/backup/detach | `Delete` pour `ephemeral`, `fast-rwo` régénérable ; `Retain` seulement pour `database`/irremplaçable + rapport hebdo des PV `Released` (T-05) |
| CPU d'instance-manager : `guaranteedInstanceManagerCPU` 10 % ≈ 1 195 m réservés, p95 14 j = 2,5 CPU (PLT-281) [D] | Moteur V1 en espace utilisateur (engine + replica par volume) | **Supprimé** : le chemin de données est le device-mapper du noyau ; reste un contrôleur et un DaemonSet sans requests par défaut [P manifeste lvm-operator] | — |
| Sur-réservation `fast` : ~959 Gio programmés pour ~548 Gio (kube-ops#971), `storageOverProvisioningPercentage: 180` [D] | Volumes fins Longhorn sur disque fin | LV épais : la taille est réservée à la création ; un PVC qui ne tient pas reste `Pending` au lieu de remplir le disque plus tard (T-04) | Budget par profil (`maxSize`) dans les capabilities |
| Bases sur HDD (Fleet MySQL 84 % des écritures `bulk`, Matrix, Hindsight…) (`db-storage-golden-path.md`) [D] | Choix de classe app par app, tier `fast` saturé | Rien en soi | Profil `database` → classe `fast` uniquement ; garde-fou CI qui refuse `bulk` pour CNPG/MySQL/WAL |
| Écritures NVMe ~1,09 To/j (`proxmox-write-reduction-recommendations.md`) [D] | Surtout ZFS `logbias`, runners, etcd ; Longhorn `fast` ne pèse que ~21 Go/j (jauge Longhorn) [D] | **Gain faible** : une couche ext4 + moteur en moins par volume ; à mesurer (T-09) [Hyp] | Lots A1–A7 de PLT-344 |
| Migrations/restaurations complexes (drills Velero, Longhorn backups R2 + Hetzner) [D] | Deux mécanismes de sauvegarde superposés | Un seul chemin : Velero/Kopia (fichiers), Barman (bases) ; plus de BackupVolume Longhorn | Drill de restauration par profil (T-08) |

Gain démontrable attendu, à confirmer par T-09 : −1,2 CPU réservé, −8 pods environ [NV : décompte exact des pods Longhorn à relever], plus aucun état de volume propre au moteur, taille par PVC garantie, aucune sur-réservation.

## 3. Matrice comparative

| Critère | OCI CSI `oci-bv` | Rancher local-path | OpenEBS LocalPV Hostpath | OpenEBS LocalPV‑LVM | Longhorn V1 (actuel) | TopoLVM |
|---|---|---|---|---|---|---|
| Taille par PVC réellement appliquée | oui, volume dédié ; **50 Go minimum**, arrondi au-dessus [P OKE] | **non** [P README] ; répertoires partagés | seulement avec quota XFS/ext4 projet sur un FS monté avec project quota [P README « quota enforcement » ; détails NV] | oui : un LV par PVC (taille du LV) [P] | oui (volume bloc virtuel), mais réservation fine sur-allouable (180 %) [D] | oui : un LV par PVC [P] |
| Thin / risque d'épuisement | non (volume plein) | n/a (FS partagé : le premier qui remplit bloque tous) | idem si pas de quota | `thinProvision: "no"` par défaut ; `yes` exige `dm_thin_pool` [P] ; épuisement du pool = I/O bloquées pour tous les LV fins [NV pour la politique OpenEBS] | sur-allocation configurée 180 % [D] | thin + ratio de sur-allocation par device-class [NV] |
| Privilèges | géré par OKE dans `kube-system` [A] | provisionneur + helper pod `hostPath` [NV pour le détail du helper ; T-00] | helper `hostPath` [NV] | nœud **`privileged: true`**, `hostPath` `/dev` et `/var/lib/kubelet` (Bidirectional) ; pas de hostNetwork ; manifeste amont en `kube-system` [P lvm-operator.yaml] | privilégié, iSCSI, hostPath [P/D] | nœud privilégié (lvmd) [NV] |
| RBAC notable | — | PV, PVC, nodes, pods (helper) [NV] | idem [NV] | snapshotter : **`secrets: get, list` cluster-wide** ; création de CRD [P] | large | [NV] |
| Pods au repos (1 nœud) | 0 ajouté (déjà là) | 1 (+ helper éphémère) | 1 (+ helper) | 2 (contrôleur 5 conteneurs + DaemonSet) [P] | ~10 [NV, à compter T-09] | 3–4 [NV] |
| Requests CPU/RAM par défaut | — | [NV] | [NV] | aucune définie [P] | instance-manager 10–12 % CPU [P/D] | [NV] |
| Snapshots | oui (CSI, CRD à installer) [P OKE] | non | non | oui (LVM, local) ; « Restore from snapshot of thick volume is not supported » [P] | oui | oui si thin [P] |
| Expansion | oui, en ligne, jamais en réduction [P OKE] | sans objet (pas de taille) | via quota [P README, détails NV] | oui ; « Resize of volumes with snapshot is not supported » [P] | oui | oui [P] |
| Suppression / orphelins | `Delete` par défaut ; volumes AVAILABLE non attachés constatés (2 × 50 Go) [A] | répertoire supprimé par helper si `Delete` | idem | LV supprimé si `Delete` ; LV orphelin visible par `lvs` | 99 détachés [D] | idem LVM |
| Mono-nœud | oui | oui | oui | oui | 1 réplica, sans valeur ajoutée | oui |
| Remplacement du nœud | volume réattaché par OCID (statique) [P OKE, section statique NV] ; zone AD-1 fixe [A] | **données perdues** (disque de boot) | idem | données conservées **si le disque du VG survit** (Talos : disque virtio Proxmox) ; PV liés au nom du nœud → procédure §6 | données sur `/var/mnt/k8s-*`, survivent si le disque survit | idem LVM |
| Réattacher un disque existant sans formater | oui (PV statique) | oui (répertoire) | oui | oui (VG importé, LV existants ; CR `LVMVolume` à recréer [NV]) | complexe (métadonnées Longhorn) | oui [NV] |
| Sauvegarde hors cluster (R2) | Velero CSI snapshot = sauvegarde OCI (reste chez Oracle) ; **hors Oracle : Velero FSB/Kopia** | Velero FSB **seulement si `volumeType: local`** (hostPath non supporté [P Velero]) | idem | Velero FSB/Kopia ; data mover CSI possible [NV] | Longhorn backup R2 [D] + Velero | idem LVM |
| Bases (CNPG) | Barman Cloud → R2, indépendant du moteur | idem | idem | idem | idem | idem |
| Coût OCI | 50 Go du quota par PVC | 0 (disque de boot) | 0 | 0 sur Talos ; sur OKE exige un volume | interdit sur OKE (capabilities) | 0 sur Talos |

**TopoLVM** : son seul avantage concret sur OpenEBS LVM serait un plafond de sur-allocation des pools thin et le scheduling par capacité. Sur un nœud unique, le scheduling ne sert à rien ; la recommandation est en **thick**, donc sans pool à protéger. TopoLVM n'est **pas retenu** [avantage thin : NV].

## 4. Talos 1.14 : `LVMVolumeGroupConfig` / `LVMLogicalVolumeConfig`

| Question | Réponse | Preuve |
|---|---|---|
| Les types existent-ils ? | **Oui**, documents multi-docs `v1alpha1` | [P] [LVM Talos v1.14](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/storage-and-disk-management/lvm) ; [référence LVMLogicalVolumeConfig](https://docs.siderolabs.com/talos/v1.14/reference/configuration/storage/lvmlogicalvolumeconfig) |
| Depuis quelle version ? | **1.14.0** : « What's New in Talos 1.14.0 » annonce « declarative software RAID and LVM provisioning » et les deux nouveaux documents | [P] [What's new 1.14](https://docs.siderolabs.com/talos/v1.14/getting-started/what's-new-in-talos) ; date de sortie GA : [NV] |
| Ce qu'ils font | VG : sélectionne des volumes Talos ou des disques entiers, crée PV LVM + VG, les **agrandit** déclarativement. LV : nom, `type` `linear`/`raid0`/`raid1`/`raid10`, `provisioning.minSize/maxSize` (taille ou % du VG) | [P] |
| Thin ? | **Non** : aucun type thin-pool/thin dans `LVMLogicalVolumeConfig` | [P] |
| Formatage/montage ? | **Non** : « Talos does not format or mount the logical volume through the LVM configuration itself » ; un LV peut porter un `UserVolume` | [P] |
| Destruction | retirer un VG détruit tous ses LV ; retirer les documents de la config d'abord, sinon Talos les recrée ; `talosctl wipe pv` pour les étiquettes | [P] |

**Ce que le LVM natif facilite** : le VG devient déclaratif dans la config machine (GitOps OpenTofu), reproductible après réinstallation, sans Job privilégié qui ferait `pvcreate`/`vgcreate` (OpenEBS ne crée pas le VG : « LocalPV-LVM will not provision the VG for the user » [P quickstart]). Il permet aussi un LV statique de taille fixe pour un gros `UserVolume` (ex. `media`).

**Ce qu'il ne résout PAS** : aucun provisionnement de PV à la demande (pas de CSI), pas de quotas par PVC, pas de snapshots, pas de pools thin, pas d'expansion pilotée par un PVC. Il faut toujours un CSI (OpenEBS LVM) au-dessus du VG. Point de vigilance : Talos ne doit déclarer **que le VG** ; s'il déclarait aussi les LV des PVC, il les « réconcilierait » contre le CSI.

**Version de Paul** : **Talos 1.13.10**, Kubernetes 1.36.3 (`homelab-infra/terraform/proxmox/main.tf`, `talos_version = "1.13.10"`, et `mise.lock`) [D]. **Une montée en 1.14 est nécessaire** pour le VG déclaratif. Sans montée, il reste possible de créer le VG par Job privilégié (impératif, hors config machine) : non recommandé.

Prérequis non vérifiés sur Talos : modules `dm_snapshot` (et `dm_thin_pool` si thin) disponibles dans le noyau Talos 1.14 [NV] ; le support thin de lvm2 Talos a été corrigé fin 2023 (siderolabs/pkgs#833, fermé) [P], sans version Talos citée. Les volumes épais n'en dépendent pas.

## 5. Coûts et quota OCI (OKE)

| Poste | Go | Source |
|---|---|---|
| Quota Always Free Block Volume (boot + block, région d'origine) | 200 | [P Always Free] « These amounts apply to both boot volumes and block volumes combined » |
| Boot volume du nœud actuel | 50 | [A] |
| 2 volumes `csi-…` AVAILABLE non attachés (drills pg-shared/hindsight-db, 15/11) | 100 | [A] — **ne jamais les supposer libres** |
| **Reste** | **50** | = un seul PVC `oci-bv` (50 Go minimum) |
| Sauvegardes de volumes gratuites | 5 au total | [P Always Free] |

Risques de coût et de reprise :

1. **Marge de remplacement du nœud.** Le cyclage « terminate and replace » ajoute un nœud (maxSurge 1 si rien n'est précisé) [P OKE node cycling], donc un nouveau boot volume de 50 Go avant la suppression de l'ancien. Avec 150 Go alloués, cette marge est exactement les 50 Go restants. **Si ces 50 Go sont pris par un PVC, le remplacement par surge échoue sur quota** (ou est facturé au-delà du gratuit : le dépassement en PAYG n'est pas chiffré par la page [NV]). Parades : remplacement du boot volume (BVR, garde l'instance, l'OCID et l'IP donc le nom du nœud [P]) ou `maxSurge 0 / maxUnavailable 1` (coupure).
2. **Libérer du quota** : supprimer les 2 volumes AVAILABLE rendrait 100 Go. C'est une suppression de données de drill : décision de Paul, après vérification qu'aucune restauration n'en dépend (D-2026-11-14-03, D-2026-11-11-05). Hors de cette étude.
3. Agrandir le boot volume consomme aussi le quota et n'est pas un « nouveau volume » mais reste une dépense de quota : même décision.

## 6. Reprise après remplacement du nœud et changement d'identité

| Moteur | Remplacement OKE terminate/replace | BVR OKE | Talos : réinstallation de la VM, disques data conservés | Talos : nouveau nom de nœud |
|---|---|---|---|---|
| `oci-bv` | volume détaché puis réattaché au nouveau nœud par le CSI ; même AD obligatoire | sans effet | n/a | n/a |
| local-path / Hostpath | **perte** (disque de boot) | **perte** | données sur `/var/mnt/...` conservées si le chemin est sur un disque data | PV en `nodeAffinity: kubernetes.io/hostname` → pods `Pending` ; parade : `nodeAffinityKey` sur un label stable [P README local-path] |
| OpenEBS LVM | n/a sur OKE sans volume | n/a | VG réimporté par Talos (si `LVMVolumeGroupConfig` sélectionne le même disque par identifiant stable [P]) | PV et CR `LVMVolume` liés au nom du nœud [NV pour la clé exacte] → procédure ci-dessous |
| Longhorn | n/a | n/a | disques réenregistrés via `Node` CR `homeops-01` [D] | CR `Node` à renommer, volumes à réassigner [NV] |

**Procédure documentée (à prouver par T-06)** pour un PV local lié à l'ancien nom de nœud :
1. Garder le nom du nœud stable : sur Talos, `machine.network.hostname` fixe (VM101 = `homeops-01`) [D] ; sur OKE, le nom dérive de l'IP privée, conservée par BVR [P].
2. Si le nom change malgré tout : scaler l'app à 0 ; pour chaque PV (`Retain` obligatoire avant l'opération), exporter le PV, le supprimer, le recréer avec le même `volumeHandle`/chemin et la nouvelle `nodeAffinity` (champ immuable) [NV : une KEP rend ce champ mutable, version non vérifiée], `claimRef` vers le PVC existant ; pour OpenEBS LVM, mettre à jour `spec.ownerNodeID` du CR `LVMVolume` [NV].
3. Vérifier par checksum (T-06/T-08) avant de rescaler.
4. En dernier recours : restauration depuis R2 (T-08), qui est le vrai filet.

## 7. Sauvegarde hors cluster par moteur

| Moteur | Bases (CNPG) | Fichiers | Remarque |
|---|---|---|---|
| tous | Barman Cloud (plugin CNPG) → R2 ; restauration hors Oracle = condition D-2026-11-14-03 | — | indépendant du moteur |
| `oci-bv` | idem | Velero FSB/Kopia → R2 | les snapshots CSI OCI restent chez Oracle : ne comptent pas comme hors site |
| local-path | idem | Velero FSB **si** `volumeType: local` | « hostPath volumes are not supported » [P Velero] |
| OpenEBS Hostpath | idem | Velero FSB [NV : type de PV créé] | — |
| OpenEBS LVM | idem | Velero FSB/Kopia (PV CSI) ; data mover CSI possible [NV] | snapshots LVM locaux = confort, pas une sauvegarde |
| Longhorn | idem | backup Longhorn R2 + Velero | double mécanisme actuel |

Le node-agent Velero a besoin d'un `hostPath` `/var/lib/kubelet/pods` et parfois du mode privilégié [P Velero] : même exception VAP que le moteur.

## 8. PSA et VAP : exception nommée

La VAP `baseline-pod-hardening` (Deny) refuse `privileged`, `hostNetwork`, `hostPID`, `hostIPC` et tout `hostPath` dans **tous** les namespaces sauf `kube-system` et `cloudflared` [D fixture]. Sa source Git n'a pas été trouvée dans kube-ops ni homelab-infra `origin/main` (export du cluster) [à localiser].

- OpenEBS LVM (nœud privilégié + hostPath), local-path/Hostpath (helper hostPath), Velero node-agent : **tous refusés hors exception**.
- Exception proposée (décision plateforme, PR revue) : namespace dédié **`storage-system`** avec `pod-security.kubernetes.io/enforce: privileged`, ajouté à la liste `NotIn` du binding, `ResourceQuota` et NetworkPolicy deny-all sauf API server. Préférable à `kube-system` (sur OKE, namespace géré par Oracle ; y mêler un composant tiers brouille les responsabilités).
- Les namespaces d'apps restent `restricted` : les pods applicatifs ne montent qu'un PVC, ce que PSA restricted accepte.
- Sur OKE maintenant : **aucune exception nécessaire** (rien n'est installé).

## 9. Décisions existantes : respectées ou touchées

| Décision / document | Effet |
|---|---|
| D-2026-11-11-05 (aucun mécanisme retiré avant preuve du successeur) | respecté : Longhorn reste jusqu'au dernier volume migré et restauré |
| D-2026-11-11-06 (retrait de contrôleur sur preuve) | respecté : retrait de Longhorn = PR séparée, après T-01…T-09 et drill |
| D-2026-11-11-17 (CNPG mutualisé sur OKE à cause du minimum de 50 Go) | appliqué par l'option V1 |
| D-2026-11-14-03 / D-2026-11-15-11 (aucune donnée persistante sur OKE sans restauration hors Oracle) | respecté : OKE maintenant = rien de persistant hors `regenerable` |
| capabilities OKE « jamais Longhorn sur OKE » [D openchoreo-lab] | respecté |
| kube-ops `db-storage-golden-path.md` (PROPOSÉ : bases sur `fast`, garde-fou CI) | repris dans le profil `database` |
| kube-ops `longhorn/values.yaml` (« V1 is intentional ») | **remis en cause** sur Talos : la recommandation est de sortir de Longhorn, pas de passer en V2 |
| `proxmox-csi` déjà déployé, classe sur `tank-vm` (HDD) avec `ssd: true`, aucun PV [D] | non retenu comme moteur principal : un disque Proxmox par PVC, nombre de disques par VM limité (exemple amont : 16 allouables [P README, NV comme limite réelle]) alors qu'il existe ~84 volumes ; demande un jeton Proxmox en écriture. Utile au plus pour 1–2 gros volumes `bulk` |

## 10. Prouvé / non vérifié / à tester

**Prouvé [P/D/A]** : minimum 50 Go et expansion `oci-bv` ; quota 200 Go boot + block ; 150 Go alloués, 50 restants ; local-path sans limite de taille et `hostPath` par défaut ; `nodeAffinityKey` local-path ; Velero refuse `hostPath` ; OpenEBS LVM : VG à créer par l'admin, nœud privilégié + hostPath, pas de requests, snapshotter lit les Secrets, limites de snapshot/resize ; Talos 1.14 : LVM déclaratif sans thin ni format ; Paul en Talos 1.13.10 ; VAP Deny hostPath/privileged hors `kube-system`/`cloudflared` ; incidents Longhorn chiffrés (kube-ops).

**[NV]** : date GA de Talos 1.14 ; modules `dm_snapshot`/`dm_thin_pool` dans le noyau Talos 1.14 ; détail des privilèges du helper local-path et OpenEBS Hostpath ; quotas OpenEBS Hostpath (mise en œuvre, montage `prjquota` sur Talos `UserVolumeConfig` et sur OKE) ; clé de topologie et procédure `ownerNodeID` d'OpenEBS LVM ; mutabilité de `nodeAffinity` des PV ; nombre de pods/requests Longhorn sur ce nœud ; avantage thin de TopoLVM ; facturation PAYG au-delà de 200 Go ; maintien de l'attachement d'un block volume après BVR ; réattachement statique OCI (section non relue).

**À tester [T]** : voir [`TEST-PLAN.md`](TEST-PLAN.md) (T-00 privilèges, T-01 tailles, T-02 épuisement isolé, T-03 redémarrage, T-04 disque/VG plein, T-05 suppression/recréation/orphelins, T-06 changement de nœud, T-07 réattachement sans formatage, T-08 sauvegarde/restauration R2 avec checksums, T-09 empreinte vs Longhorn).

## Sources

- OKE PVC Block Volume : https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengcreatingpersistentvolumeclaim_topic-Provisioning_PVCs_on_BV.htm
- Always Free : https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- OKE node cycling : https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengupgradingimageworkernode_topic-Performing_an_InPlace_Worker_Node_Update_By_Cycling_an_Existing_Node_Pool.htm ; BVR : https://docs.oracle.com/iaas/Content/ContEng/Tasks/replace-boot-volume-worker-node-top.htm
- local-path-provisioner : https://github.com/rancher/local-path-provisioner
- OpenEBS Dynamic LocalPV (Hostpath) : https://github.com/openebs/dynamic-localpv-provisioner
- OpenEBS LocalPV‑LVM : https://github.com/openebs/lvm-localpv (README, `docs/quickstart.md`, `docs/storageclasses.md`, `deploy/lvm-operator.yaml`)
- TopoLVM : https://github.com/topolvm/topolvm
- Talos 1.14 LVM : https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/storage-and-disk-management/lvm ; thin lvm2 : https://github.com/siderolabs/pkgs/issues/833
- Velero FSB : https://velero.io/docs/main/file-system-backup/
- Longhorn best practices : https://longhorn.io/docs/1.10.0/best-practices/
- Proxmox CSI : https://github.com/sergelogvinov/proxmox-csi-plugin
- Kubernetes ephemeral storage : https://kubernetes.io/docs/concepts/storage/ephemeral-storage/
