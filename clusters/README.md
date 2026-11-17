# clusters/

Un répertoire par cluster cible. `capabilities.yaml` décrit ce que le cluster offre aux apps : stockage, réseau, magasin de secrets, bases, IdP.
`tools/appgen` le lit (schéma : `docs/schema/capabilities.schema.json`) et refuse tout ce qui n'y figure pas. Modifier ce fichier relève d'une décision de plateforme, prise en PR revue.

| Cluster | Rôle | Data Plane OpenChoreo | État |
|---|---|---|---|
| `k3d` | banc local (Phase A) | `ClusterDataPlane default` (même cluster que le CP) | 51 PASS (`tests/k3d/RESULTS.md`) |
| `oke` | cloud toujours disponible : CP, identité, services légers | `default` aujourd'hui, `oke` à terme (`docs/architecture/DECISIONS-OPEN.md` D7) | étapes 1-5 PASS |
| `talos` | **proposé** : apps locales, stockage important | `talos` (agent en sortie vers le CP OKE) | non créé ; contrat : `docs/architecture/MULTI-DATAPLANE.md` |

Un cluster `talos` exige d'étendre le schéma (enum `metadata.name`) et `appgen` : c'est un changement proposé, hors de ce répertoire.
