# Résultats Phase A — **k3d** (pas OKE)

- **Date** : 2026-11-17, de 16:59 à 17:05 UTC (3 exécutions de `tests/k3d/run.sh`, la dernière et l'avant-dernière toutes vertes).
- **Environnement** :
  - cluster `k3d-openchoreo`, Kubernetes v1.36.1+k3s1, 1 nœud arm64 (colima) ;
  - OpenChoreo **v1.3.3** (charts CP et DP 1.3.3), ESO 2.0.1, OpenBao 2.5.1 en mode dev ;
  - CNPG 1.30.1 (chart 0.29.1) ;
  - CNI flannel, avec le contrôleur NetworkPolicy **kube-router** intégré à k3s : les NP sont **appliquées**, ingress et egress. Le trafic refusé reçoit un REJECT (« Connection refused »).
- **Bilan** : **51 PASS, 0 FAIL, 1 NOT_TESTED**.
- **Preuves** : brutes, datées, sans secret, dans `tests/k3d/evidence/<id>.txt` (vérifié : aucune URI ni aucun mot de passe en clair).

## Tableau

| ID | Test (APP-CONTRACT §8) | Résultat | Preuve, cause |
|---|---|---|---|
| T01a | Constante PSA du CPT (PRB tente `enforce: privileged`) | PASS | label `restricted` présent |
| T01b | Pod conforme admis | PASS | dry-run serveur |
| T01c | Pod sans securityContext | PASS | `violates PodSecurity "restricted:latest"` |
| T01d-f | Pod privileged, hostPath, hostNetwork dans la cellule | PASS | refus PSA |
| T01g | 5 pods `service-restricted` Running sous restricted (uid 65532, rootfs RO, /tmp emptyDir) | PASS | |
| T02 | Trait qui retire `capabilities` | PASS | RB `RenderingFailed` : « securityContext restricted altéré » |
| T03a | Trait qui rend une ClusterRoleBinding | PASS | « kind interdit : ClusterRoleBinding » |
| T03b | Trait hors `allowedTraits` | PASS | Component `not in the allowed list` |
| T03c-e | cluster-agent : CRB, ClusterRole, Namespace non `dp-*` | PASS | refus VAP-1 |
| T03f, T03i | cluster-agent : Namespace `dp-*`, Job dans lab-pg | PASS | admis (témoins) |
| T03g-h | cluster-agent : écriture dans kube-system, Secret dans lab-pg | PASS | refus VAP-1 |
| T03j | SA applicatif : create ClusterRole | PASS | refus RBAC (avant VAP) |
| T04a | Workload `:latest` | PASS | preRender « image épinglée par digest obligatoire » |
| T04b | Pod direct sans digest | PASS | refus VAP-2 |
| T04c-e | `dp-*` sans PSA : privileged, hostPath, hostNetwork | PASS | refus de la VAP-2 seule |
| T04f | Témoin hors portée (`t-vap-control`) | PASS | pod privileged admis : c'est bien la VAP qui refuse |
| T05 | Endpoint `external` avec `publicAuth: none` | PASS | preRender |
| T06a | Trait qui passe le Service en LoadBalancer | PASS | postRender « ClusterIP seulement » |
| T06b | PVC + RollingUpdate | PASS | postRender « strategy Recreate » |
| T06c | PVC + Recreate (trait upstream) | PASS | PVC `Bound` |
| T06d-e | Service LB manuel, 2ᵉ PVC | PASS | `exceeded quota: cell-quota` |
| T07a | NP default-deny et allow-dns-and-cell présentes | PASS | |
| T07b-d | Intra-cellule ouvert, A→B bloqué, DNS résolu | PASS | |
| T08a-b | Cellule A (`none`) → 1.1.1.1:443 bloqué ; cellule B (`public-internet`) → ouvert | PASS | |
| T08c-e | B → example.com:443 ouvert, B → 10.43.0.1:443 bloqué, témoin lab-pg → apiserver ouvert | PASS | |
| T08f | IMDS 169.254.169.254 | **NOT_TESTED** | aucun IMDS sur k3d : un refus n'y prouve rien (test 15, OKE) |
| T09a | Rôle alpha → base `alpha_development` via `DATABASE_URL` injectée, TLS | PASS | |
| T09-* | Rôle alpha → `beta_development`, `postgres`, `app` | PASS | `permission denied for database` |
| T09b | Connexion sans TLS | PASS | `pg_hba ... no encryption` |
| T10 | Cellule sans `pg-client` → lab-pg:5432 | PASS | bloqué |
| T11a-b | Superuser absent de la cellule ; `can-i get secrets -n lab-pg` | PASS | `NotFound` ; `no` |
| T12a-d | Mot de passe généré (32 caractères), PushSecret `Synced`, secret de cellule (`password`, `uri`), Job : REVOKE vérifié | PASS | aucune valeur affichée |

Hors banc, non testé :

- RBAC réduit du cluster-agent (`reduced-clusterrole.yaml`) : le basculer modifiait l'installation DP partagée.
- Job immuable après une modification du CRT (§10.5).
- Tests 12 à 15 de §8 : CI, MCP, OIDC, IMDS sur OKE.

## Corrections faites pendant les essais (≤ 2 itérations par problème)

1. CNPG : `postInitSQL` s'exécute avant la création de `app`. Il faut `postInitApplicationSQL`.
2. CCT : la CEL de §7.1 (`toVolumes() + [{...}]`) est **rejetée par le webhook** (type check). Correctif : envelopper le littéral dans `dyn([...])`.
3. CCT : `allowedTraits` n'accepte que `ClusterTrait` (CRD v1.3.3). Les traits de test sont donc cluster-scoped.
4. VAP-1 : `request.namespace` est absent pour un objet cluster-scoped. Le premier essai refusait par **erreur CEL** (fail-closed) au lieu de la règle. Correctif : `has()`.
5. CPT : le cluster-agent n'a **pas** le droit `resourcequotas`. Erreur : `cannot patch resource "resourcequotas"`. Correctif : ajout de `platform/cluster-agent/extra-rbac-quota.yaml` (forme recommandée par `cluster-agent-rbac.mdx`).
6. Opérateur CNPG : image épinglée par digest. Sans cela, l'init container des pods lab-pg (tag seul) serait refusé par VAP-2.

## Empreinte (kubectl top au repos, k3d, 3ᵉ exécution)

| Namespace | CPU usage | RAM usage | Requests CPU / RAM |
|---|---|---|---|
| openchoreo-control-plane (dont backstage 256 Mi, kgateway 85 Mi) | 23–51m | 447 Mi | 750m / 896 Mi |
| openchoreo-data-plane | 6–12m | 33 Mi | 100m / 192 Mi |
| cert-manager + external-secrets | 9m | 288 Mi | 0 / 0 |
| thunder + openbao | 31m | 43 Mi | 100m / 50 Mi |
| cnpg-system + lab-pg | 11m | 84 Mi | 70m / 192 Mi |
| Nœud entier (kube-system, cellules de test compris) | 242–490m | 2,5 Gi | — |

Lecture :

- **CP + DP OpenChoreo : 850m de requests**, contre l'objectif de 250m (APP-CONTRACT §10.1). Backstage et event-forwarder sont encore actifs : il faut des values réduites avant tout gate OKE.
- L'usage réel de CP + DP reste faible : environ 30 à 60m et 480 Mi.
