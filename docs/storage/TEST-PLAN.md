# Plan de test du stockage (préparé, NON exécuté)

Statut : scripts écrits le 2026-11-17, **aucun n'a été lancé**. Seul contrôle fait : `bash -n` et `shellcheck -S warning` (analyse statique, sans exécution) : 0 erreur. Tous les résultats sont donc **NOT_TESTED** à ce jour. Contexte : [`STORAGE-RECOMMENDATION.md`](STORAGE-RECOMMENDATION.md).

## 1. Où et comment (environnement jetable uniquement)

| Élément | Choix | Pourquoi |
|---|---|---|
| Machine | **VM Linux jetable** (Lima ou Multipass sur le Mac, ou VM Proxmox de test vide), Ubuntu 24.04, 4 vCPU, 8 Gio, 30 Go | LVM, loop devices, `dm_thin_pool` et open-iscsi (Longhorn) ne sont pas fiables dans les conteneurs k3d sur macOS |
| Cluster | k3s mono-nœud (comme OKE et Talos : un seul nœud) | même topologie que la cible |
| Disques | loopback : `st-fast` 4 Gio (VG), `st-bulk` 8 Gio (VG, thin), `/mnt/st-hostpath` XFS 4 Gio monté `prjquota` | tailles petites pour saturer vite |
| Jamais | OKE `oracle-a1`, Talos `homeops`, le k3d du labo qui porte OpenChoreo | données réelles |

Mise en place : `tests/storage/00-setup-vm.sh` (dans la VM) puis `01-install-engines.sh` par moteur (une VM neuve par moteur pour T-09, sinon les empreintes se mélangent).

## 2. Garde-fous des scripts

Chaque script commence par un en-tête **DANGER** et appelle `guard` (`tests/storage/lib.sh`), qui sort en code 2 avant toute écriture si :
1. `STORAGE_TEST_ALLOWED_CONTEXTS` est vide ou ne contient pas le contexte courant ;
2. `KUBECONFIG` n'est pas explicite, est multiple, est sous `~/.kube/` ou `~/.cache/oke-access/`, ou contient `oke|oracle|talos|homeops` ;
3. le contexte, le cluster ou l'URL du serveur contient un motif de production (`oke`, `oracle`, `oci`, `homeops`, `tatouine`, `talos`, `prod`, `10.0.20.*`, `10.0.2.*`…) ;
4. le ConfigMap `default/storage-test-disposable` (posé par `00-setup-vm.sh`) manque ou désigne un autre contexte ;
5. le cluster a plus d'un nœud, ou `ENGINE` est inconnu.

`00-setup-vm.sh` refuse de son côté : hors `sudo`, `STORAGE_TEST_VM_CONFIRM` ≠ hostname, Proxmox (`/etc/pve`), Talos, instance Oracle (DMI), kubelet déjà présent, VM déjà préparée. Les étapes qui touchent le nœud (redémarrage, renommage, remplissage du disque racine) demandent chacune une variable `STORAGE_TEST_ALLOW_*=yes`, sinon NOT_TESTED. Namespaces de test : préfixe `st-`, PSA `restricted` ; `drop_ns` refuse tout autre préfixe.

Sortie : une ligne `PASS|FAIL|NOT_TESTED` par résultat, cumul daté dans `tests/storage/evidence/results.log`, preuves brutes dans `evidence/<id>.txt` (aucun secret ; MinIO du banc a des identifiants factices). `evidence/` n'est pas à committer (à ajouter au `.gitignore` par le coordinateur).

## 3. Tests

| ID | Script | Ce qui est prouvé | PASS si | Résultat attendu (hypothèse) |
|---|---|---|---|---|
| T-00a/b/c | `t00-privileges.sh` | privilèges réels du moteur ; effet de la VAP `baseline-pod-hardening` exportée d'OKE ; exception `storage-system` | inventaire écrit ; refus sous VAP OKE hors `kube-system` ; Bound avec l'exception | OpenEBS : refus puis OK ; local-path k3s : exempté (`kube-system`) |
| T-01 | `t01-t02-size-isolation.sh` | taille par PVC (256Mi/512Mi/1Gi) | ENOSPC avant taille + 64 Mio et `df` ≈ taille | LVM, Longhorn : PASS ; Hostpath+XFS quota : PASS à prouver ; local-path : **FAIL attendu** |
| T-02 | idem | épuisement d'un PVC sans toucher les autres | témoins sha256 intacts, B et C inscriptibles | local-path : B/C impactés si le FS partagé se remplit |
| T-03a/b | `t03-persistence-restart.sh` | persistance après recréation du pod / redémarrage du nœud (+ réattachement des disques) | 200 fichiers OK (sha256) | PASS partout (b NOT_TESTED sans autorisation) |
| T-04a/b | `t04-pool-full.sh` | support plein : refus à la création ou à l'écriture ; pool thin plein | PVC en trop `Pending`, témoin intact ; LV voisin lisible | LVM thick : PASS ; local-path/Longhorn sur-alloué/thin : FAIL documenté |
| T-05a/b/c | `t05-delete-recreate.sh` | `Delete` libère le support ; `Retain` relie un nouveau PVC ; rapport d'orphelins | PV + support absents ; sha256 identique ; PV `Released` listé | PASS ; c'est la base du rapport hebdo d'orphelins |
| T-06 | `t06-t07-node-change-reattach.sh` | changement de nom du nœud, procédure de reliaison §6 | sha256 identique après procédure | à prouver, surtout `ownerNodeID` OpenEBS [NV] |
| T-07 | idem | réattachement sans formatage (PV statique) | sha256 et identité du FS identiques | PASS attendu |
| T-08a/b/c | `t08-backup-restore.sh` | Velero FSB/Kopia vers MinIO ; restauration après suppression du namespace ; local-path `hostPath` non sauvegardé | Completed + 300/300 sha256 ; pour hostPath, 0 PodVolumeBackup | PASS ; T-08c confirme la doc Velero |
| T-09 | `t09-footprint.sh` | pods, requests, CPU/RAM au repos et en charge, octets disque pour 512 Mio écrits en fsync | ≤ 2 pods, ≤ 100m, ≤ 128 Mi (budget OKE) | OpenEBS LVM/local-path : PASS ; Longhorn : FAIL (chiffre de référence) |

Non couverts ici (à faire sur l'environnement réel, plus tard) : restauration CNPG Barman depuis R2 hors Oracle (déjà exigée par D-2026-11-14-03, test séparé), comportement du LVM natif de Talos 1.14 (`LVMVolumeGroupConfig`) : à faire sur une **VM Talos 1.14 jetable** créée exprès, pas sur VM101 ; modules `dm_snapshot`/`dm_thin_pool` sur Talos.

## 4. Exécution type (pour plus tard)

```bash
# Dans la VM jetable :
STORAGE_TEST_VM_CONFIRM="$(hostname)" sudo -E tests/storage/00-setup-vm.sh
export KUBECONFIG=/root/storage-test.kubeconfig STORAGE_TEST_ALLOWED_CONTEXTS=storage-test
ENGINE=openebs-lvm OPENEBS_LVM_CHART_VERSION=<épinglée> WITH_VELERO=1 VELERO_VERSION=<…> \
  VELERO_AWS_PLUGIN_VERSION=<…> MINIO_IMAGE=<image@sha256:…> sudo -E tests/storage/01-install-engines.sh
ENGINE=openebs-lvm sudo -E tests/storage/run-all.sh
```

Aucune version n'est fixée par défaut : les versions de charts, de k3s et de Velero sont à épingler au moment du test (celle de k3s citée dans `00-setup-vm.sh` est [NV]).

## 5. Critères de décision

- Talos : OpenEBS LVM n'est retenu que si T-01, T-02, T-04a, T-05, T-07, T-08 sont PASS et T-06 PASS ou procédure corrigée ; T-09 doit montrer l'écart avec Longhorn (CPU réservé, pods).
- OKE : rien n'est installé tant qu'aucun volume n'est autorisé ; T-00 sert à chiffrer l'exception VAP le jour où il le serait.
- Un FAIL attendu (local-path T-01) reste un FAIL : il justifie `sizeEnforced: false` dans les capabilities.
