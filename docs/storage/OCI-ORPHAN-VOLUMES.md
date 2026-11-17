# Volumes OCI non attachés — identification et proposition (aucune action)

Relevé en LECTURE SEULE le 2026-11-17 (OCI CLI : `bv volume get`, `compute volume-attachment list`, `bv backup list`). **Rien n'a été supprimé, réaffecté, attaché ni formaté.**

## Ce qui est établi (preuve OCI)
| | Volume A | Volume B |
|---|---|---|
| Nom | `csi-69b1aca8-b557-4547-b93b-37d0a2a681d0` | `csi-142706cc-8609-442a-be33-e7c82245b66b` |
| Taille / état | 50 Go, AVAILABLE, VPU 10, AD-1 | 50 Go, AVAILABLE, VPU 10, AD-1 |
| Créé | 2026-11-15 21:27:38Z | 2026-11-15 21:45:44Z |
| Créé par (balise Oracle `CreatedBy`) | cluster OKE `…ww66nmx6…chuigjmq` (ancien `oracle-a1`, endpoint 10.0.2.3, **DELETED**) | idem |
| Attachement | 1 historique, **DETACHED** (créé 21:27:49Z) | 1 historique, **DETACHED** (créé 21:47:47Z) |
| Sauvegardes OCI | aucune | aucune |
| Balises libres (PVC/namespace) | aucune | aucune |

Les deux volumes ont donc été provisionnés par le CSI de l'ANCIEN cluster, à 18 minutes d'intervalle, puis détachés quand le nœud a été remplacé. Le nom `csi-<uuid>` correspond à un PV `pvc-<uuid>` de cet ancien cluster, mais **aucun UUID n'apparaît dans les dépôts kube-ops/homelab-infra ni dans les notes de mission** (recherche faite).

## Ce qui n'est PAS établi
- **Quel volume est `pg-shared` et lequel est `hindsight-db`.** Les documents (kube-ops `docs/architecture/oke-target-architecture.md:18,174`, notes OKE-EXEC) parlent de « 2 restes du drill (`pg-shared`, `hindsight-db`) » : c'est une déduction par date/nombre, pas une preuve par volume.
- **Leur contenu** (données de drill restaurées depuis R2 ? seules copies ?). Il n'est lisible qu'en attachant le volume : ce n'est pas fait.
- Si la restauration hors Oracle a un jour été prouvée (D-2026-11-14-03 : « NOT_TESTED »).
Conclusion : **identification NON certaine ⇒ aucune récupération de quota autorisée par ce document.**

## Comment les identifier avec certitude (à exécuter seulement sur décision de Paul, par ordre de risque croissant)
1. **Journal d'audit OCI** (lecture seule) : événements `CreateVolume`/`AttachVolume` de l'ancien cluster le 2026-11-15 ~21:27 et ~21:45 (`oci audit event list`), corrélés avec les heures de création des PVC `pg-shared-1` et `hindsight-db-1` dans les preuves du drill (kube-ops/homelab-infra `docs/`, runs ARC du 15/11).
2. **Corrélation avec les sauvegardes R2** : dernier `completed` des archives CNPG `pg-shared` et `hindsight-db` et leur taille, pour savoir si les données du volume existent ailleurs.
3. **Inspection directe (dernier recours)** : attachement **en lecture seule** à une instance jetable (ou au nœud via un PV statique `readOnly`), `blkid` + liste de fichiers, détachement. Modifie l'état d'attachement OCI : accord explicite de Paul requis, jamais de formatage.

## Proposition de récupération du quota (décision de Paul, volume par volume, rien d'automatique)
| Option | Effet | Préconditions | Risque |
|---|---|---|---|
| **A. Garder (défaut)** | quota 150/200, aucun gain | aucune | aucun coût OCI direct ; 100 Go inutilisés |
| **B. Sauvegarder puis supprimer** | +50 Go par volume supprimé | identification certaine (ci-dessus) ; sauvegarde de volume OCI de chaque volume (le palier Always Free en inclut 5) ; confirmation qu'une copie hors Oracle existe ; accord écrit de Paul par volume | perte de données si l'identification est fausse ; la sauvegarde permet la restauration |
| **C. Réutiliser** comme PV statique | 0 Go de quota net, données conservées | contenu identifié, décision de formatage | écrasement possible : **déconseillé** |

Règles quel que soit le choix : **conserver 50 Go de marge pour le remplacement du worker** (le remplacement crée un nouveau volume de démarrage de 50 Go avant de supprimer l'ancien) ; ne jamais supprimer les volumes sans accord écrit ; ne jamais les supposer libres.
