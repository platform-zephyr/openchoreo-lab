# Exigences de déploiement de kube-ops (base des ADR OpenChoreo)

Date : 2026-11-18. Lecture seule sur un clone local de kube-ops @ `ef50472` (clone superficiel). Complète `docs/KUBE-OPS-APP-MAP.md` (35 apps), non refait ici. Références `chemin:ligne` relatives à kube-ops. **[S]** = supposé ou non vérifiable dans ce clone. Aucun secret lu.

## 0. Conclusions

1. Le niveau d'exigence est **élevé sur la sécurité et les données**, **faible sur l'uniformité** : 33 apps, ~33 formes de manifests Kustomize écrits à la main. Un seul chemin neuf et mince existe (chart `platform-app`, profil stateless seul).
2. kube-ops a **déjà tenté le même objectif** (un `app.yaml` par agent) : `docs/platform/application-contract.md:3`, `k8s/charts/platform-app/`. Il rejette explicitement base, stockage, exposition publique et auth (`application-contract.md:36-44`). OpenChoreo doit couvrir précisément ce que ce contrat refuse.
3. **Aucun ADR formel dans ce dépôt.** Les décisions vivent dans un autre dépôt (`homelab-infra/docs/decisions.md`, identifiants `D-AAAA-MM-JJ-NN`) : `AGENTS.md:7`. Voir §5.4.
4. L'application des règles est **partielle** : Kyverno en `Audit`, Gatekeeper en `dryrun`, `readOnlyRootFilesystem` exigé par la doc mais absent de Mealie (§3.4).

---

## 1. Stack réelle

| Domaine | Fait | Preuve |
|---|---|---|
| Clusters | 2 : **homelab** (Talos sur Proxmox, nœud unique `homeops-01`, k8s v1.36.3) et **OKE `oracle-a1`** (Basic, 1 nœud arm64, 2 OCPU/12 Go, Always Free) | `k8s/infrastructure/storage/longhorn/values.yaml:7` ; `k8s/infrastructure/storage/longhorn/node-homeops.yaml:4` ; `docs/state/cluster-reality.md:6` ; `docs/operations/two-argo-one-workflow.md:7` ; `k8s/clusters/oracle-a1/README.md:25,44` |
| Substrat | Proxmox/Talos, UniFi, Cloudflare (compte, edge), Doppler bootstrap, OpenTofu : hors dépôt (homelab-infra) | `AGENTS.md:11` |
| GitOps | **2 Argo CD indépendants**, même dépôt `main`, pas d'Argo central. Racine `root` -> `k8s/bootstrap/argocd-root` | `docs/operations/two-argo-one-workflow.md:7` ; `k8s/bootstrap/argocd-root/root-application.yaml:16` ; `k8s/clusters/oracle-a1/README.md:3` |
| App-of-apps / ApplicationSet | 3 ApplicationSets Git-directory/fichier : `applications` (1 Application `apps-<dossier>` par dossier de catégorie), `infrastructure`, `apps-generated` (1 `gen-<name>` par `app.yaml`) | `k8s/bootstrap/argocd-root/applications-applicationset.yaml:12-26,35` ; `infrastructure-applicationset.yaml:40-52` ; `apps-generated-applicationset.yaml:33,38` |
| Sync | `automated prune+selfHeal`, `ServerSideApply`, `preserveResourcesOnDeletion: true` (retrait sans cascade) | `applications-applicationset.yaml:31-32,63-78` |
| OKE GitOps | Argo local en *pull*, racine `apps/` ordonnée par sync-wave ; bootstrap manuel par l'opérateur | `k8s/clusters/oracle-a1/README.md:3,8-9` |
| Helm | **Pas de chart commun pour les apps legacy** : Kustomize brut + `helmCharts` ponctuels. Un seul chart in-repo, `platform-app` 0.2.0 (stateless) ; pas d'app-template/bjw-s | `k8s/charts/platform-app/Chart.yaml:2-7` ; `applications/catalog/vikunja/kustomization.yaml:1-12` |
| Ingress | Gateway API sur **Cilium** (`gatewayClassName: cilium`), 2 Gateways `internal` et `external` (ns `gateway`), listeners `*.smadja.dev`, apex, `gestion.lechaplais.com`. Manifests **identiques** : la différence est hors manifeste (IP L2 / tunnel) [S] | `network/gateway/gw-external.yaml:7-12` ; `gw-internal.yaml:7-12` ; `network/cilium/values.yaml:62,68` |
| Public | Cloudflare Tunnel : `cloudflared` DaemonSet (homelab), Deployment (OKE), jeton via ESO. Cloudflare Access (équipe `smadja`) avec Authentik comme IdP | `network/cloudflared/daemon-set.yaml:3,36-37` ; `k8s/clusters/oracle-a1/cloudflared/deployment.yaml:5` ; `auth/authentik/extra/blueprints/apps-cloudflare.yaml:12-15` ; `.agents/skills/deploy-a-service/SKILL.md:37-38` |
| LB cloud | Interdit sur OKE (VAP) : l'edge passe par le tunnel sortant | `k8s/clusters/oracle-a1/guardrails/deny-loadbalancer-service.yaml:1-19` |
| DNS | `externaldns-private` vers UniFi (webhook) ; Cloudflare pour le public (hors dépôt) | `network/externaldns-private/values.yaml:6-12` |
| TLS | cert-manager, ClusterIssuer Let's Encrypt **DNS-01 Cloudflare**, un certificat wildcard `*.smadja.dev` ; pas d'issuer ACME sur OKE | `controllers/cert-manager/cloudflare-issuer.yaml:7-13` ; `network/gateway/cert-smadja.yaml:7-14` ; `k8s/clusters/oracle-a1/README.md:13` |
| Secrets | ESO `external-secrets.io/v1`, `ClusterSecretStore doppler-cluster`, refresh 1 h ; Reloader (homelab seul) ; rotation OKE = redémarrage manuel | `controllers/external-secrets/doppler-store.yaml:1-15` ; `k8s/CLAUDE.md:18` ; `k8s/clusters/oracle-a1/README.md:54-58` |
| Stockage | Longhorn mono-réplica : `longhorn-fast` et `longhorn-bulk` (Retain) ; `longhorn-workspace/sandbox/drill` spéciaux ; Proxmox CSI = compat ; OKE `oci-bv` (50 Gi min) | `storage/longhorn/storageclasses.yaml:4-25` ; `storage/longhorn/drill-storageclass.yaml:15` ; `k8s/CLAUDE.md:29` ; `k8s/clusters/oracle-a1/README.md:44-45` |
| PostgreSQL | CNPG + plugin barman-cloud ; règle : nouvelle base = `Database` dans `pg-shared` ; ~20 `Cluster` dédiés hérités ("à consolider") | `k8s/CLAUDE.md:36-38` ; `docs/operations/cnpg-cluster-inventory.md:3,9-30` |
| Sauvegarde | Velero/Kopia vers R2 (PVC) ; CNPG/Barman vers R2 ; restic chiffré (Immich, Paperless) ; MySQL = CronJob logique | `k8s/CLAUDE.md:30,38` ; `docs/operations/plt-286-restic-backups.md:18-32` ; `.justfile:44` |
| Policy | Kyverno (cible) + Gatekeeper (en retrait) + VAP ; PSA `restricted` par namespace (partiel) | `docs/state/cluster-reality.md:77,82` ; §3 |
| Réseau | Cilium (kube-proxy remplacé, Hubble), `CiliumNetworkPolicy` seulement. **OKE = flannel, NetworkPolicy non appliquées** | `network/cilium/values.yaml:6,90` ; `k8s/CLAUDE.md:23` ; `k8s/clusters/oracle-a1/README.md:60-62` |
| Observabilité | Prometheus/Loki/Tempo/Grafana + **Alloy -> Grafana Cloud** (homelab et OKE, label `cluster`) ; Gatus retiré d'OKE ; alertes via ntfy | `infrastructure/monitoring/alloy/values.yaml:27-31` ; `k8s/clusters/oracle-a1/README.md:19,27-30` |
| Identité | **Authentik** (blueprints GitOps), OIDC natif par défaut, 1 proxy outpost (forward-auth) seulement si l'app n'a pas d'OIDC ; accès par **groupe** : `authentik-admins`, `family`, `friends` | `auth/authentik/extra/blueprints/outposts.yaml:11-17` ; `docs/operations/authentik-access-model.md:5-13` |
| Accès admin | NetBird (routeur OKE, API 6443) ; OCI Bastion en secours ; homelab : kubeconfig Doppler | `k8s/clusters/oracle-a1/README.md:17,34-38` ; `AGENTS.md:50` |
| Renovate | Actif, **sans automerge**, planning 0-7 h, `rangeStrategy: pin`, gestionnaires custom (`# renovate:`) ; manager helm-values sur `k8s/**/values.yaml` | `renovate.json:10-19,31-35,36-47` |
| CI | `just check` = 40 tests de contrat ; `check-affected` ; workflows `platform-app-contract`, `apps-generated-contract`, `stateful-plan` | `.justfile:28-67` ; `.github/workflows/` |

---

## 2. Contrat implicite d'une app

### 2.1 Chemin A : `app.yaml` (stateless, 1 fichier) [C]
Champs : `metadata.{name,owner,description}`, `spec.{profile,source.image,runtime{replicas,size,port,healthPath,env},exposure{mode,auth},backup.policy,observability,secrets[],config{},egress.https[]}` (`k8s/charts/platform-app/values.schema.json:11-130`).
- Image **tag@sha256 obligatoire** (`values.schema.json:52`), replicas 1-3 (`:62`), `size` small/medium = 50m/128Mi vers 250m/256Mi ou 200m/512Mi (`templates/_helpers.tpl:64-65`).
- Nom = namespace `svc-<name>` + hostname `<name>.smadja.dev` (`values.schema.json:19` ; `templates/network.yaml:6,14`).
- Secrets : clés Doppler préfixées `<NAME>_`, ExternalSecret rendu (`application-contract.md:59-63`). Egress : FQDN exacts HTTPS 443, 8 max (`:65-67` ; `values.schema.json:125-135`).
- Mutualisé par le chart : Namespace PSA restricted, SA sans token, Deployment durci, Service, HTTPRoute `internal`, CNP default-deny, PDB, ServiceMonitor (`application-contract.md:48-52` ; `templates/workload.yaml:36-82`).
- Rejets : base, stockage, `public`, `auth: authentik` (`application-contract.md:38-43`). Un seul app réel : `idp-e2e` (carte §3.1).

### 2.2 Chemin B : Kustomize à la main (tout le reste, ~30 apps)
Un développeur écrit 8-12 fichiers par app. Exemple minimal Mealie : `namespace.yaml` (PSA + `Prune=false,Delete=false`), `deployment.yaml`, `externalsecret.yaml`, `service-route.yaml`, `storage.yaml`, `networkpolicy.yaml` (`applications/catalog/mealie/`). Vikunja ajoute `database.yaml`, `backup*.yaml` (`applications/catalog/vikunja/kustomization.yaml:3-12`). L'agent doit ensuite l'ajouter à la bonne racine (`applications-applicationset.yaml:17-26`) et à un Schedule Velero (`controllers/velero/schedules/daily-<app>.yaml:1-21`).
Recette agent : arbre de décision Q0-Q7 (existe, groupe, cluster, état, identité, exposition, baseline, livraison) : `.agents/skills/deploy-a-service/SKILL.md:12-50`.

### 2.3 Variantes observées
| Variante | Comment aujourd'hui | Preuve |
|---|---|---|
| Stateless | `app.yaml` ou `tools/it-tools` (scale-to-zero KEDA) | `applications/tools/it-tools/http-route.yaml:18-19` |
| Postgres | `Database` dans `pg-shared` (règle) ; en pratique 1 `Cluster` + `ObjectStore` + `ScheduledBackup` par app | `k8s/CLAUDE.md:36` ; `vikunja/kustomization.yaml:5-8` |
| PVC | `longhorn-fast`/`bulk`, `Prune=false,Delete=false`, `Recreate` | `mealie/storage.yaml:5,10` ; `mealie/deployment.yaml:9-10` |
| Worker / cron | Deployments multiples, StatefulSet, CronJob restic, CronJob MySQL | `docs/operations/plt-286-restic-backups.md:23` ; carte §2 K07, K08, K16, K23 |
| OIDC natif | Blueprint Authentik, client confidentiel, secret `APP_<APP>_OIDC_CLIENT_SECRET` via ESO, groupe lié | `deploy-a-service/SKILL.md:32` ; `mealie/externalsecret.yaml:15-17` ; `mealie/deployment.yaml:35-41` |
| Proxy (forward-auth) | Outpost Authentik partagé, app sans OIDC | `deploy-a-service/SKILL.md:33` ; `outposts.yaml:11-17` |
| Interne | HTTPRoute `Gateway/internal` (défaut) | `deploy-a-service/SKILL.md:37` |
| Public | HTTPRoute `Gateway/external` + Cloudflare Access par groupe. **Piège : wildcard vers `external`, une route externe est publique dès le merge** | `deploy-a-service/SKILL.md:38` |
| Admin/foyer | NetBird seulement, aucune route `external` | `deploy-a-service/SKILL.md:39` |

---

## 3. Primitives de sécurité

### 3.1 Où et comment
| Primitive | Où | Mode | Preuve |
|---|---|---|---|
| PSA `restricted` enforce/audit/warn | label de Namespace, **manuel par app** (16 dossiers sur 29 selon la carte) ; automatique via `platform-app` | enforce | `applications/catalog/mealie/namespace.yaml:8-10` ; `templates/namespace.yaml:9-11` |
| securityContext pod/conteneur | règle écrite ; appliquée par le chart ; manifestes legacy hétérogènes | convention | `k8s/CLAUDE.md:7-9` ; `templates/workload.yaml:38-43,76-82` |
| Requests/limits, emptyDir bornés, image épinglée sans `latest` | règle | convention + CI [S] | `k8s/CLAUDE.md:10-11` |
| `CiliumNetworkPolicy` default-deny ingress+egress par namespace, jamais NetworkPolicy standard | par app ; ingress `fromEntities [host, remote-node, ingress]` | convention | `k8s/CLAUDE.md:23` ; `vikunja/networkpolicy.yaml:7` ; `templates/network.yaml:33-35` |
| Egress FQDN (`toFQDNs`) | CNP par app, ou `spec.egress.https` du chart | enforce (homelab) | `application-contract.md:65-67` ; carte §4.3 |
| Egress restic vers R2 `*.eu.r2.cloudflarestorage.com` | CNP du composant | enforce | `plt-286-restic-backups.md:32` |
| **IMDS** (169.254.0.0/16) | exclu des CIDR d'egress de Matrix et Media ; **pas de règle générique** | partiel | `applications/platform/matrix/networkpolicy.yaml:198` ; `applications/media/kustomization.yaml:73` |
| Pas de LB cloud | VAP OKE | Deny | `deny-loadbalancer-service.yaml:5-28` |
| Garde d'identité agent | VAP `agent-operator-guard` : toute écriture de l'identité agent hors `scope.tsv` refusée | Deny | `security/agent-operator/validatingadmissionpolicy.yaml:1-9` ; `scope.tsv:1-7` |
| Secrets | Aucun Secret rendu par le golden path ; ESO seul ; garde de sortie `secret-output-guard.py` | Deny + hook | `security/policies/apps-generated-boundary.yaml:87-96` ; `AGENTS.md:60-62` |
| Token SA | `automountServiceAccountToken: false` (chart)  | chart | `templates/workload.yaml:8,36` ; 18 dossiers d application sur 27 mentions de SA/token le fixent explicitement (`grep`) |

### 3.2 Politiques Kyverno / Gatekeeper
| Politique | But | Mode | Preuve |
|---|---|---|---|
| `nsa-hardening-all-namespaces` (5 règles : non-root, drop caps, rootfs RO, pas de host namespace, pas de privileged) | Durcissement NSA/CISA, tous namespaces | **Audit** (non bloquant) | `security/policies/kyverno-policies.yaml:4,8,10,27,54,78,99` |
| `apps-generated-namespace-name` | Namespace du golden path = `svc-*` | Deny | `security/policies/apps-generated-boundary.yaml:19,21` |
| `apps-generated-objects-in-svc-namespace` | Objets du golden path dans `svc-<name>` | Deny | `apps-generated-boundary.yaml:40` |
| `apps-generated-no-rbac` | Aucun Role/ClusterRole rendu | Deny | `apps-generated-boundary.yaml:64` |
| `apps-generated-no-rendered-secret` | Aucun Secret rendu | Deny | `apps-generated-boundary.yaml:87` |
| `apps-generated-pod-no-host-access` | Pas de hostNetwork/PID/IPC, hostPath, privileged | Deny | `apps-generated-boundary.yaml:109-130` |
| `add-ttl-to-velero-maintenance-jobs` | Hygiène Velero | mutation | `controllers/velero/auto-cleanup-jobs-policy.yaml:2-4` |
| Gatekeeper `nsa-restricted-psp` | PSP-like, **en cours de retrait** | `dryrun` | `security/policies/gatekeeper-constraints.yaml:2-8` ; `docs/state/cluster-reality.md:77` |
| Falco, Trivy operator | Détection runtime, scan | observation | `docs/state/cluster-reality.md:76,89` |

Première couche de la frontière golden path : **AppProject `apps-generated`** (namespaces `svc-*`, liste blanche de kinds, RBAC/Secret/Quota interdits) : `bootstrap/argocd-root/apps-generated-project.yaml:26-60`.

### 3.3 Exceptions
`PolicyException` Kyverno nominatives : `applications/automation/hassio/policy-exception.yaml:2-35` (hostNetwork, NET_ADMIN), `applications/ai/opencode/policy-exception.yaml`. Paliers T0-T3 de tolérance CVE : `docs/operations/security-tiers-v1.md:8-13`.

### 3.4 Écarts constatés (règle vs réalité)
- Mealie : pas de `readOnlyRootFilesystem` (`mealie/deployment.yaml:46-49` (aucune clé `readOnlyRootFilesystem`)), route aussi sur `external` (`mealie/service-route.yaml:18`) ; reconnu par `deploy-a-service/SKILL.md:57`.
- Règle « pas de wildcard » (`k8s/CLAUDE.md:25`) contredite par `network/gateway/cert-smadja.yaml:7-9`.
- `policies/README.md:10-11` annonce `policyAuditMode: true` ; la clé est **absente** de `network/cilium/values.yaml` (README périmé).
- Root dans stirling-pdf, pinepods, trilium, opencode, gpt-researcher (carte §2).

---

## 4. Données stateful

| Sujet | Fait | Preuve |
|---|---|---|
| Classes | 5 classes **IRREPLACEABLE / USEFUL / REBUILDABLE / RETIRED / DRILL**, décision D-2026-11-11-05 | `docs/operations/backup-coverage-classes.tsv:3-6` |
| Où la classe vit | **Fichier TSV central** par PVC (pas de label k8s), lu par `scripts/backup-coverage-static.py` ; annotation `homelab.smadja.dev/data-class` dans le catalogue Backstage généré | `backup-coverage-classes.tsv:1-2` ; `catalog/generated/all.yaml:95` |
| Couverture | 71 PVC, 62 couverts R2, 0 irremplaçable non couvert (statique) | `docs/operations/backup-coverage-static.md:8-10` |
| PVC | Velero/Kopia, `defaultVolumesToFsBackup`, BSL `r2`, TTL 14 j, 1 `Schedule` par app | `controllers/velero/schedules/daily-agentgateway.yaml:19-21` |
| Postgres | barman plugin, WAL `isWALArchiver`, `ScheduledBackup method: plugin`, rétention 14 j, R2 `homelab-backup-cnpg` | `k8s/CLAUDE.md:38` ; `database/pg-shared-homelab/scheduledbackup.yaml:11-20` ; `objectstore.yaml:34,54` |
| Irremplaçable | + restic chiffré côté client (clé hors ligne papier, Doppler = clé d'exécution distincte), manifeste SHA256, `restic check` 5 %, restauration à blanc hebdo | `docs/operations/plt-285-irreplaceable-data-client-encryption.md:18-25` ; `plt-286-restic-backups.md:23-30` |
| Protection suppression | `Prune=false,Delete=false` sur PVC/Cluster/ObjectStore/ScheduledBackup ; StorageClass `Retain` ; script d'arrêt de sync refuse si PVC/CNPG serait pruné | `mealie/storage.yaml:5` ; `database/pg-shared-homelab/scheduledbackup.yaml:10` ; `AGENTS.md:43` |
| Réversibilité | Classes A/B/C ; **« restauration n'est pas rollback »** : un `git revert` ne rend pas les données | `docs/operations/stateful-reversibility.md:7-11,30-33` |
| Règle de preuve | Stateful incomplet sans backup ; donnée importante incomplète sans **une restauration prouvée** ; backup ≠ preuve | `AGENTS.md:70` ; `.agents/skills/backup-restore/SKILL.md:9-10` |
| Preuves | Drill Paperless PASS (PITR + Velero) du 2026-11-15 ; schéma `backup-audit/restore-evidence-v1`, péremption 24 h | `docs/operations/dr-restore-evidence-2026-11-15.json` (`status: PASS`, `maxAgeSeconds: 86400`) |
| Drills non prouvés | `pg-shared` app restore **NOT_TESTED** (RPO 5 min / RTO 30 min visés) ; OKE : aucune donnée tant que la restauration hors Oracle n'est pas prouvée | `docs/operations/pg-shared-app-restore-drill.md:3-6` ; `k8s/clusters/oracle-a1/README.md:64-75` |
| Hors périmètre | Médias volumineux non sauvegardés en volume (`media-share` 2 Ti REBUILDABLE) | `k8s/CLAUDE.md:30` ; `backup-coverage-classes.tsv:47` |

---

## 5. Déjà formalisé pour les agents

### 5.1 Instructions et skills
- `AGENTS.md` (autorité, ordre de lecture, surface de commandes, Safety, Evidence, STE80) ; `CLAUDE.md` = `@AGENTS.md` ; `k8s/CLAUDE.md` pour les manifestes (`AGENTS.md:7-15`, `k8s/CLAUDE.md:1-50`).
- 11 skills dans `.agents/skills/` (lien `.claude/skills`) : repo-navigation, deploy-a-service, argocd-debug, kubernetes-debug, runtime-observer, cilium-hubble, oidc-integration, backup-restore, sre-triage, observability, agent-memory (`AGENTS.md:17-33`).
- Accès agent : `kubectl-ro.sh` (identité `agent-operator`, sans lecture de Secret), `kubectl-rw.sh` (écriture bornée par `scope.tsv`), `doppler-safe.sh` (`AGENTS.md:41-44`).
- Niveaux de preuve **STATIC < CI < RECONCILED < RUNTIME < USER**, statuts `PASS/FAIL/BLOCKED/NOT_TESTED/NOT_PROVEN` (`AGENTS.md:68-70,74` ; `docs/operations/acceptance-levels.md:3-10`).
- Rôles : l'IA de Paul merge après CI verte ; l'IA d'un proche ouvre une PR et **ne merge jamais** (`deploy-a-service/SKILL.md:10`).

### 5.2 Contrats machine et golden paths
- **`app-status.v1`** : `bash scripts/app-status.sh <app> [--cluster] [--commit]` ; sortie JSON ; codes 0 PASS / 1 FAIL / 3 PENDING / 4 UNKNOWN ; `PASS` exige `RUNTIME` + smoke `pass` ; `checks[] db/backup/restore` = `not_applicable` en stateless (`docs/platform/app-status.md:13-24,36`). Schéma : champs `schemaVersion, app, cluster, requested, synced, argo, workloads, smoke, checks, status, reason, evidenceLevel, timestamp` (`docs/contracts/app-status-v1.schema.json`).
- Autres contrats : `agent-test-result-v1` (Factory seulement, `docs/agent-harness.md:5-14`), `mission-state.v1` (`missions/backstage-pilote-canari.state.json:2`, 8 étapes avec niveau de preuve requis), `restore-evidence-v1`.
- **`golden-paths/`** : `platform-application` (skeleton du contrat v1) et `service-postgres-oidc@v1` (template Backstage : base `pg-shared-homelab` + OIDC + interne ; `dataClass` et `restoreDrillStatus` obligatoires ; cluster = homelab seul, exposition interne seule) : `golden-paths/service-postgres-oidc/template.yaml:17,48-59,65-70` ; `README.md:3-5`. Branche non sur `main` selon `deploy-a-service/SKILL.md:54`.

### 5.3 Reprise de mission
`python3 scripts/mission/resume.py <key>` ; commits avec trailers `Mission-Key/Step/Attempt` (`AGENTS.md:31`).

### 5.4 ADR : liste, gabarit
**Aucun répertoire ADR dans kube-ops** (`git ls-files` : 0 fichier `adr`/`decisions`). Les décisions sont dans `homelab-infra/docs/decisions.md` (hors clone), numérotées `D-AAAA-MM-JJ-NN` (`AGENTS.md:7`). **Décisions citées dans ce dépôt** (22 identifiants distincts, titres non disponibles : seul le sens déduit de la citation est donné) :
| ID | Sens (déduit) | Citée à |
|---|---|---|
| D-2026-11-11-05 | Classer les données par irremplaçabilité | `backup-coverage-classes.tsv:3` |
| D-2026-11-11-06 | Gatekeeper vers Kyverno | `kyverno-policies.yaml:96` |
| D-2026-11-11-12 | Contrat `agent-test-result` pour Factory seulement | `.agents/skills/runtime-observer/SKILL.md:38` |
| D-2026-11-11-17 | OKE : Argo local, aucune donnée sans restauration prouvée hors Oracle | `k8s/clusters/oracle-a1/README.md:3,72` |
| D-2026-11-13-02 | Toute nouvelle base dans `pg-shared` | `k8s/CLAUDE.md:36` |
| D-2026-11-14-01 | Registre des décisions actives, prime sur tout | `AGENTS.md:7` |
| D-2026-11-15-01 | Deux Argo CD, un workflow | `docs/operations/two-argo-one-workflow.md:3` |
| D-2026-11-15-03 | Autonomie maximale des agents, 3 obligations | `AGENTS.md:54` |
| D-2026-11-16-09 | `pg-shared-homelab` | `bootstrap/argocd-root/infrastructure-project.yaml:43` |
Autres : D-11-11-07, -11-11-19, -11-13-01, -11-14-02/-03/-06, -11-15-05/-06/-10/-13, -11-16-05/-06/-07.

**Gabarit le plus proche** (document ADR-like `docs/operations/two-argo-one-workflow.md`), à recopier tel quel :
```
# <Titre>                         (ligne 1)
Status: ACTÉE (homelab-infra `docs/decisions.md` D-AAAA-MM-JJ-NN). Date: .... Owner: .... Ticket: PLT-...
## Decision        (1 paragraphe)
## Comparison      (tableau d'options)
## Reasons         (liste numérotée)
## Convention (no migration)
## Verification
Dernière ligne : « Revisit only with a measured benefit written in a ticket (...) »
```
Variante plus longue (`website/docs/architecture/personal-data-platform.md:9-151`) : Status / Product goals / V1 decision / Identity contract / Data classification / Application admission contract / Storage / Backup / Roadmap par phases. Variante journal (`backup-data-scope-2026-11-05.md:5`) : `## Décision`, état, matrice, mesures, références. Aucun ADR n'a de sections Contexte/Conséquences. **Pas de gabarit standard** : à définir pour la nouvelle plateforme.

---

## 6. Synthèse pour la nouvelle plateforme

### 6.1 Les 10 exigences à préserver
1. **Git = seule autorité**, Argo réconcilie, aucune écriture durable dans le cluster ; retrait sans cascade (`AGENTS.md:3` ; `applications-applicationset.yaml:31-32`).
2. **Données irremplaçables jamais seules** : classe de données obligatoire, backup R2, restauration prouvée avant « safe » (`AGENTS.md:58,70`).
3. **Aucune suppression implicite d'état** : `Prune=false,Delete=false`, PV `Retain`, « restauration n'est pas rollback » (`stateful-reversibility.md:15-17,30`).
4. **Preuve par niveaux datés** STATIC/RECONCILED/RUNTIME/USER, jamais PASS sans runtime (`acceptance-levels.md:3-10` ; `app-status.md:23-24`).
5. **Pod durci par défaut** : non-root, drop ALL, seccomp, rootfs RO, SA sans token, PSA restricted, requests/limits (`templates/workload.yaml:36-82`).
6. **Default-deny réseau + egress FQDN explicite** ; refuser sur un cluster qui n'applique pas les policies (OKE flannel) (`k8s/CLAUDE.md:23` ; `oracle-a1/README.md:60-62`).
7. **Secrets : Doppler -> ESO uniquement**, jamais dans Git/PR/sorties, préfixe par app (`application-contract.md:59-63` ; `AGENTS.md:60-62`).
8. **Images épinglées par digest** (`values.schema.json:52`).
9. **Identité par groupe, jamais par utilisateur** ; OIDC natif par défaut, proxy sinon, client confidentiel (`authentik-access-model.md:5` ; `deploy-a-service/SKILL.md:31-34`).
10. **Exposition publique = décision explicite** (Cloudflare Tunnel + Access, jamais LB cloud, interne par défaut) ; exceptions de sécurité nominatives, bornées et approuvées (`deploy-a-service/SKILL.md:36-39` ; `deny-loadbalancer-service.yaml:1-8` ; `hassio/policy-exception.yaml:2`).
Complément : base partagée par défaut (`k8s/CLAUDE.md:36`), tests de contrat en CI (`.justfile:28-67`), droits agent bornés + garde VAP (`validatingadmissionpolicy.yaml:1-5`).

### 6.2 Les 5 complexités à simplifier pour des agents
1. **Deux façons de déclarer une app** : `app.yaml` (stateless seul) contre 8-12 fichiers Kustomize ; la plupart des apps n'ont aucun chemin simple (`application-contract.md:36-44` ; `vikunja/kustomization.yaml:3-12`).
2. **Exposition ambiguë** : deux Gateways identiques en manifeste, wildcard qui rend une route publique au merge, Cloudflare Access hors dépôt (`gw-external.yaml:1-41` ; `deploy-a-service/SKILL.md:38`). Remplacer par un champ unique `exposure: private|public` + groupes.
3. **Classe de données hors manifeste** : TSV central + backup à 4 mécanismes (Velero, CNPG, restic, CronJob) + 1 Schedule Velero par app + règles manuelles. Remplacer par `backup.class` déclaré dans l'app, mécanisme choisi par la plateforme (`backup-coverage-classes.tsv:1-6` ; `velero/schedules/`).
4. **Postgres : règle `pg-shared` mais 20 `Cluster` dédiés** et allowlist CI ; l'agent copie le mauvais exemple (`cnpg-cluster-inventory.md:9-30` ; `deploy-a-service/SKILL.md:58`).
5. **Règles écrites mais non appliquées** et sources de vérité dispersées : Kyverno Audit, Gatekeeper dryrun, PSA sur 16/29, README périmés, décisions dans un autre dépôt, 2 clusters aux capacités inégales (OKE sans NetworkPolicy, sans Reloader, sans TLS) (`kyverno-policies.yaml:8` ; `gatekeeper-constraints.yaml:8` ; `AGENTS.md:7` ; `oracle-a1/README.md:54-62`).

### 6.3 Points non vérifiés [S]
Différence réelle `internal`/`external` (pool L2, cible du tunnel) ; état Cloudflare Access (Terraform dans homelab-infra) ; texte complet des décisions D-* ; règles d'alertes (homelab-infra) ; politique IMDS générique sur OKE ; branche `claude/backstage-pilote-template`.
