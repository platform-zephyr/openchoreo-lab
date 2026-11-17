# platform/ — objets custom minimaux (OpenChoreo v1.3.3)

**Prouvé sur k3d seulement** (2026-11-17, 51 PASS / 0 FAIL / 1 NOT_TESTED : `tests/k3d/RESULTS.md`). Rien n'est prouvé sur OKE.

Objets custom OpenChoreo : 3 (1 CCT, 1 CPT, 1 CRT), conformément à la cible d'E-revue (≤ 3). Ils s'ajoutent à 2 VAP natives, 1 ClusterRole additionnel et au socle CNPG. Aucune CRD custom, aucun type par défaut modifié.

## Contenu

| Fichier | Rôle |
|---|---|
| `component-types/service-restricted.yaml` | CCT `deployment/service-restricted`, copie durcie de `service`. PSA restricted (uid ≥ 1000, seccomp, drop ALL, pas d'escalade, rootfs RO paramétrable, `/tmp` en emptyDir, `automountServiceAccountToken: false`). Paramètre `strategy`, tailles `small`/`medium`. **preRender** : digest obligatoire, exposition `external` interdite si `publicAuth: none`, Recreate ⇒ replicas ≤ 1. **postRender** (après les traits) : securityContext intact, un seul conteneur dont l'image a un digest, pas de host*/hostPath, PVC ⇒ Recreate et replicas ≤ 1, Service ClusterIP seulement, 18 kinds refusés (RBAC, cluster-scoped, NetworkPolicy, DaemonSet…). `allowedTraits` : `persistent-volume-claim` et `health-probes` (upstream). |
| `project-types/cell-restricted.yaml` | CPT : Namespace `dp-*` avec labels PSA restricted posés en **constantes**, NetworkPolicy default-deny ingress+egress, DNS, trafic intra-cellule, egress optionnel (`database` → lab-pg:5432, `allowIdp`, `public-internet` sur 80/443 hors RFC1918, CGNAT et 169.254/16), ResourceQuota (LB=0, NodePort=0, PVC paramétrable) et LimitRange. |
| `resource-types/cnpg-lab-db.yaml` | CRT : base et rôle `<database>_<env>` sur `lab-pg`. Générateur ESO `Password`, ExternalSecret `refreshInterval: "0"`, PushSecret vers `${dataplane.secretStore}`, Job `psql` idempotent (REVOKE CONNECT FROM PUBLIC vérifié), ExternalSecret dans la cellule (`password`, `uri`). `retainPolicy: Retain`. |
| `data/cnpg-operator-values.yaml` | Values de l'opérateur CNPG (chart 0.29.1, image épinglée par digest). La commande `helm` épinglée est en en-tête. **Pas sur OKE avant le gate.** |
| `data/lab-pg-namespace.yaml` | Namespace `lab-pg` en PSA restricted, avec ses NetworkPolicy : default-deny, intra, DNS, opérateur :8000, clients `pg-client=true` :5432, apiserver. Le CIDR de l'apiserver est un overlay propre au cluster (k3d : 172.18.0.0/16). |
| `data/lab-pg-cluster.yaml` | CNPG `Cluster` `lab-pg` : 1 instance, 1 Gi, image épinglée par digest, superuser généré par l'opérateur, `REVOKE CONNECT` sur `postgres` et `app`, `hostnossl reject`, aucune sauvegarde. |
| `policies/vap-cell-pod-hardening.yaml` | VAP-2 : pods de `dp-*` et `lab-pg` (sélection par nom). Digest obligatoire. Refus de privileged, hostPath et host*. |
| `policies/vap-cluster-agent-scope.yaml` | VAP-1, pour le SA `cluster-agent-dataplane` et les SA `dp-*`. Aucun objet cluster-scoped, sauf un Namespace `dp-*` pour l'agent. Dans `lab-pg`, l'agent n'écrit que des ExternalSecret, PushSecret, Password et Job. Aucune écriture hors `dp-*` et `lab-pg`, sauf les Events. |
| `cluster-agent/extra-rbac-quota.yaml` | **Requis.** Le ClusterRole du chart DP n'a ni `resourcequotas` ni `limitranges`. Sans ce fichier, le PRB échoue (preuve dans RESULTS). |
| `cluster-agent/reduced-clusterrole.yaml` | **Proposition non appliquée** : `clusterAgent.rbac.create=false` (seule clé du chart) et un ClusterRole à portée réduite (détail dans le commentaire du fichier). |

## Ordre d'application

1. Opérateur CNPG (helm, voir l'en-tête des values), puis `cluster-agent/extra-rbac-quota.yaml` et `policies/`.
2. `data/lab-pg-namespace.yaml`, puis `data/lab-pg-cluster.yaml` (attendre `Ready`).
3. `component-types/`, `project-types/`, `resource-types/`.
4. Apps : Project (`cell-restricted`) et PRB, Resource puis RRB **épinglée à la main**, Component et Workload.

Dépendances : ESO avec un `ClusterSecretStore` **inscriptible** (PushSecret) nommé comme `ClusterDataPlane.spec.secretStoreRef`. OpenBao convient sur k3d ; Doppler sur OKE reste [S]. Il faut aussi un CNI qui applique les NetworkPolicy (k3d : kube-router de k3s, prouvé ; OKE flannel : non).

## Prouvé / non prouvé (k3d)

- **Prouvé** :
  - PSA de bout en bout : 5 pods rendus tournent ; les pods non conformes, privileged, hostPath et hostNetwork sont refusés.
  - Constante PSA : un `namespaceLabels: privileged` ne l'écrase pas.
  - preRender et postRender (digest, auth publique, capabilities, ClusterRoleBinding, LoadBalancer, PVC/RollingUpdate), `allowedTraits`, quota (LB, 2ᵉ PVC).
  - VAP-1 et VAP-2, y compris la compatibilité avec le cluster-agent (tous les rendus réussissent avec les VAP actives).
  - Default-deny et egress appliqués par kube-router.
  - Isolation SQL par REVOKE CONNECT, TLS obligatoire.
  - Secrets générés sans geste humain.
- **Non prouvé** :
  - IMDS (aucun IMDS sur k3d).
  - RBAC réduit (le basculer aurait modifié l'installation DP partagée).
  - Job immuable après une modification du CRT (§10.5).
  - Doppler en PushSecret, routage Gateway et OIDC.
  - Tout ce qui concerne OKE.
