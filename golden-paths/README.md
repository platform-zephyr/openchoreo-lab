# Golden paths : catalogue

Un golden path = un archétype d'app. Il fournit un `app.yaml` minimal (contrat `platform.smadja.dev/v2alpha1`), ce que la plateforme impose sans rien demander, les preuves runtime attendues et la façon de revenir en arrière. Il n'y a qu'**un** chemin d'écriture : `apps/<nom>/app.yaml` → `tools/appgen` → PR → CI → merge → Argo CD → OpenChoreo. Le parcours complet est dans [`DEPLOY-AND-FIX-FLOW.md`](DEPLOY-AND-FIX-FLOW.md) ; les skills d'agent sont dans [`../.agents/`](../.agents/README.md).

| | Archétype | État 2026-11-17 | Exemple réel | Template | Vérifications |
|---|---|---|---|---|---|
| A | HTTP sans état | disponible | `apps/whoami` | [`A-stateless-http/app.yaml`](A-stateless-http/app.yaml) | [`CHECKLIST`](A-stateless-http/CHECKLIST.md) |
| B | HTTP + PostgreSQL (`lab-pg`) | disponible, 2 PR | `apps/miniflux` | [`B-http-postgres/app.yaml`](B-http-postgres/app.yaml) | [`CHECKLIST`](B-http-postgres/CHECKLIST.md) |
| C | HTTP + SQLite sur PVC | disponible (voir G4) | `apps/aiostreams` | [`C-http-sqlite-pvc/app.yaml`](C-http-sqlite-pvc/app.yaml) | [`CHECKLIST`](C-http-sqlite-pvc/CHECKLIST.md) |
| D | Worker / CronJob | **non disponible** (G1) | — | [`D-worker-cronjob/app.proposed.yaml`](D-worker-cronjob/app.proposed.yaml) | [`CHECKLIST`](D-worker-cronjob/CHECKLIST.md) |
| E | Chart Helm tiers | **illustratif, désactivé** | `apps/_examples/podinfo-helm` | [`E-helm-chart/`](E-helm-chart/app.yaml) | [`CHECKLIST`](E-helm-chart/CHECKLIST.md) |
| F | Non éligible | refus motivé | — | — | [`F-non-eligible/README.md`](F-non-eligible/README.md) |

Tous les résultats runtime sont étiquetés `k3d` ou `oke`. Un PASS sur k3d n'est pas une preuve OKE. Le gate OKE est franchi (pilote `whoami` PASS sur OKE le 2026-11-17, `STATE.md`) : `cluster: oke` est accepté ; une dépense sur OKE (PVC `oci-bv`) reste protégée.

## Choisir l'archétype (règle APP-CONTRACT §3, dans cet ordre)

```text
1. Un signal F (CRD, RBAC cluster, webhook, DaemonSet, privileged/hostPath, port<1024 imposé, uid 0 imposé,
   plusieurs conteneurs obligatoires, base non PostgreSQL, pas d'arm64, donnée irreplaceable) -> F
2. Pas d'endpoint HTTP (worker, tâche planifiée)                                               -> D (BLOCKED)
3. Seulement un chart officiel, ou plusieurs workloads couplés livrés par l'éditeur en chart     -> E (désactivé)
4. Une base PostgreSQL                                                                          -> B
5. Un fichier ou un SQLite local (un seul volume RWO, 1 réplique)                               -> C
6. Sinon                                                                                        -> A
```

B et C sont exclusifs dans le labo : une app qui a besoin des deux relève de F, ou d'une évolution de plateforme.

## Ce que la plateforme impose, sans rien demander à l'app (A, B, C)

| Domaine | Imposé | Par quoi |
|---|---|---|
| Sécurité du pod | non-root (uid ≥ 1000), seccomp `RuntimeDefault`, `drop ALL`, pas d'escalade, rootfs RO + `/tmp` emptyDir, pas de jeton SA, image par digest | CCT `service-restricted` (pre- et postRender) + PSA `restricted` + VAP `digest-only` |
| Cellule | namespace `dp-default-<app>-<env>-<hash>` en PSA `restricted` (constante non surchargeable), quota (LB = 0, NodePort = 0), LimitRange | CPT `cell-restricted` |
| Réseau | `default-deny` ingress et egress, DNS et même cellule autorisés. `egress: public-internet` = 80/443 hors RFC1918, CGNAT et 169.254/16. `allowIdp` = namespace de l'IdP. Base : `lab-pg:5432` seulement | CPT, + NP par composant d'OpenChoreo |
| Secrets | uniquement des références (`SecretReference` → ESO), clé préfixée `<NOM>_` ; jamais de valeur dans Git, dans une PR ou dans une sortie | schéma + `appgen validate` |
| Base (B) | base et rôle dédiés, `REVOKE CONNECT FROM PUBLIC`, URL injectée par `secretKeyRef`, `retainPolicy: Retain`, superuser confiné à `lab-pg` | CRT `cnpg-lab-db` |
| Volume (C) | 1 PVC RWO, `Recreate`, `replicas ≤ 1`, `local-path` (k3d) ou `oci-bv` (OKE, 50 Gi facturés) | ClusterTrait `persistent-volume-claim` + schéma |
| Sauvegarde | `none` ou `regenerable` seulement ; `irreplaceable` refusé par la CI ; `lab-pg` sans sauvegarde (éphémère) | `appgen validate` |
| Exposition | `private` par défaut ; `public` exige `host` et `auth ≠ none`, jamais de LoadBalancer | schéma + CCT + quota |
| Livraison | `autoDeploy: false`, release immuable au nom déterministe, `Prune=false` sur ComponentRelease, Component et Resource | `appgen` + Argo |
| Observabilité | déclarée dans le contrat, **pas encore rendue** (G5) ; pas d'observability plane OpenChoreo (budget) | — |

## Fiches par archétype

### A : HTTP sans état

- **Quand** : une image, un port HTTP, aucun état local, aucune base.
- **Minimal** :

  ```yaml
  apiVersion: platform.smadja.dev/v2alpha1
  kind: App
  metadata: {name: echo, owner: user:default/paul, description: Echo HTTP}
  spec:
    source: {image: "traefik/whoami:v1.10.3@sha256:43a68d10b9dfcfc3ffbfe4dd42100dc9aeaf29b3a5636c856337a5940f1b4f1c"}
    cluster: k3d
    environments: [production]
    profile: stateless
    runtime: {port: 8080, args: ["--port", "8080"], healthPath: /health, size: small}
    exposure: {mode: private, auth: none}
    network: {egress: none}
    backup: {class: none}
    observability: {metrics: {enabled: false}}
  ```

- **Généré** : Project (`cell-restricted`), ProjectReleaseBinding, Component (`autoDeploy: false`), Workload, ComponentRelease, ReleaseBinding, `catalog-info.yaml`.
- **Preuves** : G1 à G6 et W1 à W8 (`_checks/run-all.sh`).
- **Rollback** : `git revert` du merge → l'ancienne release (toujours présente) est rebindée.
- **Autonomie** : réversible. L'agent ouvre la PR, la merge si les checks requis sont verts, vérifie, et revert sur FAIL.

### B : HTTP + PostgreSQL

- **Quand** : l'app accepte une URL PostgreSQL et n'exige pas de superuser.
- **Minimal** : A + `profile: stateful` + `database: {engine: postgres, instance: lab-pg, envVar: DATABASE_URL}` + `backup: {class: regenerable}`.
- **Généré** : A + Resource `cnpg-lab-db` + ResourceReleaseBinding (`Retain`). Dans `lab-pg` : ExternalSecret du rôle et Job d'init. Dans la cellule : ExternalSecret de l'URL. NP `egress-lab-pg` ; label `pg-client`.
- **Prérequis hors Git** : clé `<NOM>_PG_PASSWORD` dans le store (MANDAT, tant que G9 n'est pas traité).
- **Preuves** : A + P1 à P6 ; P7 (isolation SQL) dans `tests/k3d`.
- **Rollback** : code par `git revert`. **Migration de schéma non réversible** : recréer la base = classe protégée « données ».
- **Autonomie** : la première création est réversible (base vide, labo). Supprimer ou recréer une base, ou changer `instance`, est protégé.

### C : HTTP + SQLite sur PVC

- **Quand** : l'état tient dans un répertoire, une seule réplique suffit.
- **Minimal** : A + `profile: stateful` + `storage: {profile: block-rwo, mountPath: /data, size: 1Gi}` + `update: {strategy: Recreate}` + `backup: {class: regenerable}`.
- **Généré** : A + trait PVC (`local-path` ou `oci-bv`), stratégie `Recreate`.
- **Preuves** : A + V1 à V3. **V1 échoue aujourd'hui** : quota `pvcs=0` (G4).
- **Rollback** : `git revert` ; le PVC est conservé. Vider les données = classe protégée.
- **Autonomie** : réversible sur k3d. `cluster: oke` = dépense, donc protégé.

### D : worker / CronJob

Non disponible (G1). L'agent répond BLOCKED et propose une PR plateforme ; il ne contourne pas.

### E : chart Helm tiers

- **Quand** : l'éditeur fournit un chart officiel et l'app n'entre pas dans A, B ou C (plusieurs workloads couplés, par exemple), sans signal F.
- **Minimal** : `source.chart {repo, name, version, digest}` + `values.yaml` durci ([`E-helm-chart/values.yaml`](E-helm-chart/values.yaml)). Ni `runtime` ni `database`.
- **Généré** : `generated/helm/<nom>/config.yaml`, consommé par l'ApplicationSet `lab-helm` (**absent** : parcours désactivé). Garde-fous à rendre (G7).
- **Preuves** : H1 à H4 (`_checks/check-helm.sh`).
- **Rollback** : `git revert` (version et values).
- **Autonomie** : activer le parcours = PR plateforme protégée.

### F : non éligible

Verdict motivé, aucune action. Voir [`F-non-eligible/README.md`](F-non-eligible/README.md).

## Vérifications runtime (`_checks/`)

Scripts **en lecture seule** : `kubectl get/describe/auth can-i` à travers un wrapper qui refuse tout autre verbe et toute lecture de Secret autre que `-o name`. Ils sont utilisables sur k3d et sur OKE (même code, `CLUSTER_LABEL=oke`).

```bash
export KUBECONFIG=<kubeconfig dédié au labo>      # jamais celui de Paul
CLUSTER_LABEL=k3d KUBE_CONTEXT=k3d-openchoreo \
  golden-paths/_checks/run-all.sh <app> production --evidence evidence/runtime
# code retour : 0 PASS, 1 FAIL, 3 PARTIAL (BLOCKED/NOT_TESTED sans FAIL)
```

| Script | Couvre |
|---|---|
| `run-all.sh` | détecte l'archétype depuis `app.yaml`, enchaîne les scripts, écrit l'evidence |
| `check-gitops.sh` | G1 à G6 : dérive appgen, Argo (sync, révision), autoDeploy, releaseName Git = cluster, conditions, orphelins |
| `check-workload.sh` | W1 à W11 : PSA, NP, quota, Deployment, securityContext, digest, exposition, santé, ExternalSecret |
| `check-postgres.sh` | P1 à P8 : lab-pg, pin RRB, Job d'init, ESO, label pg-client, URL par référence |
| `check-pvc.sh` | V1 à V4 : quota PVC, Bound, classe, Recreate, montage, fsGroup |
| `check-cronjob.sh` | D1 à D3 (prêt pour G1) |
| `check-helm.sh` | H1 à H4 |

### Sortie JSON stable (`app-status.v1`, ADR-0011)

```bash
CLUSTER_LABEL=k3d golden-paths/_checks/run-all.sh <app> production --format json   # JSON seul sur stdout
GP_NO_CLUSTER=1 CLUSTER_LABEL=k3d golden-paths/_checks/run-all.sh <app> --format json  # NOT_TESTED, niveau STATIC, code 3
```

Schéma : [`docs/schema/app-status-v1.schema.json`](../docs/schema/app-status-v1.schema.json) (+ exemples). `PASS` exige le niveau `RUNTIME` et zéro FAIL/BLOCKED/NOT_TESTED ; sans cluster joignable le verdict est `NOT_TESTED`. Chaque échec porte une `cause` typée (`check_failed` à corriger, `prerequisite_missing` ou `cluster_unreachable` réessayable). Tests : `python3 -m unittest discover -s tests/checks -v`.

Les tests **actifs** (pod privilégié refusé, egress coupé, refus SQL inter-bases) écrivent dans le cluster : ils vivent dans `tests/k3d/` (APP-CONTRACT §8), pas ici.

Écarts contrat ↔ golden paths : [`SCHEMA-GAPS.md`](SCHEMA-GAPS.md).
