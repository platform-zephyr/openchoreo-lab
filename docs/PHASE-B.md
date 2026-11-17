# Phase B : OpenChoreo 1.3.3 minimal sur OKE oracle-a1

> Statut (2026-11-17) : **préparé, statique, NON exécuté**. Aucune commande n'a touché OKE. Les scripts
> `tools/oke/*.sh` n'ont jamais tourné contre un cluster. Validation hors cluster : §8.

## 0. Conclusion

1. L'installation tient en **12 étapes idempotentes** (`tools/oke/install.sh --step N`, dry-run par défaut). Chaque étape a un critère de sortie (`tools/oke/verify.sh --step N`), un rollback (`tools/oke/uninstall.sh --step N`) et une mesure de budget. L'installation s'arrête si la pile dépasse **1,5 Gi ou 300m au repos**.
2. Requests d'OpenChoreo (CP + DP + kgateway + Envoy) : **55m / 304 Mi**, contre 850m / 1088 Mi sur k3d. Elles sont calées sur l'usage mesuré (30-60m, ≈ 480 Mi Backstage compris), sans descendre sous lui. Pile complète avec cert-manager, ESO et Argo CD : 145m / 1040 Mi. Avec CNPG et lab-pg : 215m / 1232 Mi.
3. **Conflit bloquant pour la preuve, pas pour l'installation (C1)** : la CCNP kube-ops `allow-egress-unisolated` (allow-all egress cluster-wide) s'additionne aux NetworkPolicy (union Cilium). Elle **neutralise le default-deny egress** de `openchoreo-*`, `lab-*` et `dp-*`. Correctif minimal à faire dans kube-ops : §6.
4. **ThunderID n'est pas installé en Phase B.** Son chart 1.0.1 impose 3 PVC (base SQLite, clés, secrets), soit 3 × 50 Go de block volume OCI. Il ne reste qu'environ 50 Go sur le quota de 200 Go. Sans IdP, l'API et le MCP refusent tout appel (401) : l'échec est fermé. Options pour la Phase C : §5.4.
5. Une seule exception PSA : `openchoreo-data-plane` est en `baseline`. Le schéma du chart DP interdit `seccompProfile` sur le cluster-agent. Tous les autres pods rendus sont `restricted` (vérifié statiquement).

## 1. Préconditions (toutes requises avant l'étape 1)

- [ ] Relire `…/side-session-notes/local_35b37a0a-…/idp/agents/OKE-EXEC.md` (chemin complet dans `STATE.md`). Vérifier : cluster nu et qualifié, baseline #1620 appliquée (3 VAP, CCNP `allow-egress-unisolated` et `deny-imds`), `prevent_destroy` rétabli (hi #616 mergée).
- [ ] **Accès opérateur ouvert par Paul** avec `open-oke-access.sh open [ttl ≤ 10800]` (bastion OCI, tunnel 127.0.0.1:16443, kubeconfig 0600 dans `~/.cache/oke-access/`). Un agent ne crée **jamais** cet accès. La session dure au plus 3 h : les étapes sont reprenables (`--from N`). Fermer avec `open-oke-access.sh close`.
- [ ] `export KUBECONFIG=~/.cache/oke-access/kubeconfig`. Les scripts refusent tout autre fichier, tout contexte qui n'est pas `context-oracle-a1-*`, tout `admin@*`, `*homeops*` ou `*homelab*`, un serveur différent de `https://127.0.0.1:16443`, un `tls-server-name` hors 10.0.2.0/24, et un cluster qui n'a pas exactement 1 nœud arm64 OCI. Si le contexte réel s'appelle autrement (`oci ce create-kubeconfig` produit `context-c…`), Paul fixe `OKE_CONTEXT_RE` en connaissance de cause.
- [ ] `tools/oke/preflight.sh` retourne `GO` (lecture seule).
- [ ] Avant l'étape 10 : **accord de Paul sur le stockage**. lab-pg crée 1 block volume de 50 Go. Le budget actuel est boot 50 + 2 × 50 Go restés du drill = 150/200 Go.
- [ ] Mesure « avant » : `tools/oke/measure.sh avant`.

## 2. Plan ordonné

`install.sh --step N` sans `--apply` affiche le plan. Avec `--apply`, il exécute puis mesure. Après chaque étape, lancer `verify.sh --step N`.

| # | Étape | Critère de sortie (`verify.sh --step N`) | Rollback (`uninstall.sh --step N`) |
|---|---|---|---|
| 0 | `preflight.sh` | `GO` | — |
| 1 | Namespaces, quotas, LimitRange, NetworkPolicy/CNP (`manifests/00,01,02`) | PSA attendue par namespace ; quota et `lab-default-deny` partout ; pod privileged+hostNetwork refusé (dry-run serveur) | suppression des namespaces d'essai (label `part-of=openchoreo-lab` exigé) |
| 2 | Gateway API CRD v1.5.1 (sha256 vérifié) | 5 CRD `Established` | CRD supprimées seulement avec `--delete-crds` et si inutilisées ailleurs |
| 3 | cert-manager v1.19.4 → `openchoreo-cert-manager` | 3 Deployments Available ; rien dans kube-system ; webhook joignable (dry-run d'un Issuer) | `helm uninstall` ; CRD gardées (`crds.keep`) |
| 4 | ESO 2.0.1 → `openchoreo-external-secrets` + `ClusterSecretStore lab-store` | ESO Available ; `lab-store` Ready | suppression du store, `helm uninstall` |
| 5 | kgateway-crds + kgateway v2.3.11 → `openchoreo-control-plane` | kgateway Available ; GatewayClass `kgateway` Accepted | `helm uninstall` ×2 |
| 6 | OpenChoreo CP 1.3.3 (sans Backstage, event-forwarder ni Gateway CP), puis CA du cluster-gateway copiée dans les ConfigMap | CP Available ; ConfigMap CA peuplé ; webhook OK (dry-run du CCT) ; `/health` 200 ; `/mcp` sans jeton **401** | `helm uninstall` ; CRD `openchoreo.dev` avec `--delete-crds` |
| 7 | VAP du labo (`platform/policies`), ClusterRole quota (`platform/cluster-agent/extra-rbac-quota.yaml`), TLS (`11`), GatewayParameters (`12`), OpenChoreo DP 1.3.3 | agent et Envoy Available ; Gateway `Programmed` ; aucun Service LB ou NodePort ; `can-i patch resourcequotas` = yes ; ClusterRoleBinding de l'agent refusée par VAP-1 | `helm uninstall`, puis suppression de 11, 12, quota RBAC et VAP (dans cet ordre) |
| 8 | `ClusterDataPlane default` : `clientCA` = `ca.crt` de `cluster-agent-tls` (procédure de D-gitops-empreinte §6), `secretStoreRef: lab-store` | CDP présent, condition vraie ; logs d'agent sans erreur | `kubectl delete clusterdataplane default` |
| 9 | Label `openchoreo.dev/control-plane=true` sur `default` ; Environment `production`, DeploymentPipeline `standard`, ClusterTrait `health-probes` (`40`) ; CCT, ClusterTrait PVC, CPT, CRT du labo | objets présents | refus tant qu'il reste des Components (CLEANUP.md 2) ; puis suppression et retrait du label |
| 10 | Opérateur CNPG 0.29.1 (`cnpg-system`), `lab-pg-namespace` + labels, overlay `51`, `lab-pg-cluster` (**`--confirm-storage`**) | Cluster `Ready` ; 1 PVC Bound ; PSA restricted | suppression du Cluster (le PVC et son volume OCI d'essai partent avec), `helm uninstall` |
| 11 | Argo CD 10.3.3 (v3.5.1) → `lab-argocd`, AppProject `lab`, Application `lab-root` (adopte les objets des étapes 9-10 via `lab-platform`) | `lab-root` et `lab-platform` `Synced` et `Healthy` | suppression des Application (sans finalizer : objets conservés), de l'AppProject, `helm uninstall` ; CRD argoproj gardées si un namespace `argocd` existe |
| 12 | *Optionnel, après la 1re app en Phase C* : RBAC réduit (`platform/cluster-agent/reduced-clusterrole.yaml`, puis `rbac.create=false`) | `can-i create clusterrolebindings` = no ; `pods/exec` = no ; quotas = yes ; rendu de whoami OK | `helm upgrade --set clusterAgent.rbac.create=true`, puis suppression du ClusterRole réduit |
| — | `verify.sh --security` (pod de sonde éphémère) | DNS OK ; IMDS 80 injoignable ; intra-namespace OK ; **egress Internet refusé** (`BLOCKED` tant que C1 est ouvert) | suppression du pod |

Ordre des `platform/*` : `policies/` et `cluster-agent/extra-rbac-quota.yaml` passent **avant** le data plane, pour qu'aucune écriture du cluster-agent n'échappe à VAP-1 (étape 7). `component-types/`, `traits/`, `project-types/` et `resource-types/` passent après l'enregistrement (étape 9). `data/lab-pg-*` vient ensuite (étape 10). Argo adopte le tout en dernier (étape 11).

Nettoyage complet : `uninstall.sh --all --apply` (12 → 1), aligné sur `CLEANUP.md`. Il ne touche que les namespaces étiquetés `part-of=openchoreo-lab`, les `dp-*` étiquetés `platform.smadja.dev/cell=restricted` et le label de `default`.

## 3. Namespaces et mise sous baseline

| Namespace | Contenu | Nom imposé ? | PSA enforce | Quota (req. cpu/mém., pods) | Réseau |
|---|---|---|---|---|---|
| `openchoreo-control-plane` | controller-manager, openchoreo-api (MCP), cluster-gateway, kgateway | convention OpenChoreo (URL d'agent par défaut) | restricted | 100m / 384 Mi, 8 | default-deny ; DNS ; apiserver (CNP) ; intra ; ingress depuis DP sur :8443 (agent) et :9977 (xDS) ; webhook :9443 depuis kube-apiserver |
| `openchoreo-data-plane` | cluster-agent, Envoy `gateway-default` (ClusterIP) | **oui** : VAP-1 et `platform/cluster-agent` nomment le SA | **baseline** (warn/audit restricted) | 50m / 192 Mi, 4 | default-deny ; DNS ; apiserver ; egress vers CP :8443/:9977 et vers les cellules (`platform.smadja.dev/cell`) |
| `openchoreo-cert-manager` | cert-manager (3 pods), CA de la ClusterIssuer éventuelle | non | restricted | 50m / 256 Mi, 4 | default-deny ; DNS ; apiserver ; webhook :10250 depuis kube-apiserver |
| `openchoreo-external-secrets` | contrôleur ESO seul | non | restricted | 25m / 128 Mi, 2 | default-deny ; DNS ; apiserver |
| `lab-secrets` | Secrets générés (coffre de `lab-store`), aucun pod | non | restricted | 0, 0 pod | default-deny |
| `lab-argocd` | Argo CD (controller, repo-server, server, redis) | non (pas `argocd`, réservé à kube-ops) | restricted | 100m / 640 Mi, 6 | default-deny ; DNS ; apiserver ; intra ; repo-server → `github.com:443` (toFQDNs + visibilité DNS) |
| `cnpg-system` | opérateur CNPG | **oui** : la NP de `platform/data/lab-pg-namespace.yaml` le nomme. Namespace d'essai à nettoyer | restricted | 50m / 128 Mi, 2 | default-deny ; DNS ; apiserver ; → lab-pg :8000 ; webhook :9443 depuis kube-apiserver |
| `lab-pg` | instance CNPG lab-pg + Jobs du CRT | défini par `platform/data` | restricted | 200m / 512 Mi, 4, **1 PVC** | NP de `platform/data` + CNP apiserver (overlay `51`, la NP k3d en ipBlock ne vaut pas sous Cilium) |
| `dp-*` | cellules d'apps (Phase C) | **oui** : préfixe du contrôleur OpenChoreo | restricted (constante du CPT) | quota du CPT | default-deny du CPT |
| `default` | objets OpenChoreo des apps (aucun pod), label `openchoreo.dev/control-plane=true` | **oui** : `tools/appgen` génère dans `default` | inchangée | — | — |

Prérequis strictement requis par OpenChoreo 1.3.3 : **Gateway API CRD, cert-manager, kgateway** (les deux charts rendent `gatewayClassName: kgateway`, des `HTTPListenerPolicy` et des Certificate). **ESO** est requis par le labo (CRT `cnpg-lab-db`, CCT). ThunderID et OpenBao ne sont pas requis pour démarrer. Aucun de ces prérequis n'impose son namespace : cert-manager quitte `cert-manager`, avec `global.leaderElection.namespace` rapatrié de `kube-system`, et ESO quitte `external-secrets`. Exceptions documentées au préfixe `openchoreo-*`/`lab-*` : `cnpg-system`, `dp-*`, le label de `default`, et `thunder` en Phase C si le CPT n'est pas modifié.

Labels communs : `app.kubernetes.io/part-of=openchoreo-lab` (nettoyage) et `platform.smadja.dev/egress-isolated=true` (marqueur du correctif C1).

## 4. Budget, requests et mesures

| Composant | Requests retenues (cpu / mém.) | Limites | Base (mesure k3d, RESULTS.md / FOOTPRINT.txt) |
|---|---|---|---|
| controller-manager | 15m / 64 Mi | 500m / 384 Mi | CP hors Backstage et kgateway ≈ 106 Mi pour 3-4 pods |
| openchoreo-api (+MCP) | 10m / 48 Mi | 500m / 256 Mi | idem |
| cluster-gateway | 5m / 24 Mi | 200m / 128 Mi | idem |
| kgateway | 10m / 96 Mi | 500m / 256 Mi | ≈ 85 Mi mesurés |
| cluster-agent | 5m / 24 Mi | 100m / 128 Mi | DP = 6-12m, 33 Mi (agent + Envoy) |
| Envoy DP (GatewayParameters) | 10m / 48 Mi | 500m / 256 Mi | idem |
| **OpenChoreo** | **55m / 304 Mi** | | **avant : 850m / 1088 Mi** (Backstage et event-forwarder retirés) |
| cert-manager ×3 | 15m / 192 Mi | | 3m, 192 Mi |
| ESO (contrôleur seul) | 5m / 64 Mi | | 5m, 109 Mi pour 3 pods |
| Argo CD ×4 | 70m / 480 Mi | | **non mesuré** (requests de kube-ops #1620) [S] |
| CNPG + lab-pg | 70m / 192 Mi | | 11m, 84 Mi |

- Budget **au repos**, sur l'usage et non sur les requests : pile = `openchoreo-*`, `lab-argocd`, `lab-secrets` ≤ **1,5 Gi et 300m**. `install.sh` mesure après chaque étape (3 mesures à 20 s, minimum retenu) et sort en code 3 si le seuil est dépassé. `measure.sh` mesure à la demande (avant, après chaque étape, au repos sur 24 h). Projection à partir de k3d : ≈ 40-80m et 0,7-0,95 Gi, dont Argo [S].
- Méthode de mesure : API summary du kubelet (`/api/v1/nodes/<n>/proxy/stats/summary`), car le cluster nu n'a probablement pas de metrics-server. `kubectl top` est ajouté s'il existe. On n'installe pas de metrics-server, qui serait hors périmètre.
- Si une request mémoire est sous l'usage au repos mesuré sur OKE, **on remonte la request** dans une PR. Ne jamais l'inverser.
- Si le budget est dépassé, leviers dans l'ordre : Argo en mode core (sans server : −1 pod, −64 Mi), puis Flux, puis arrêt et rapport.
- **IP de pods (VCN-native)** : 16 pods permanents, plus des Jobs transitoires. Le nœud plafonne à environ 31 pods (`preflight.sh` exige une marge de 20). Pour cette raison : ESO sans webhook ni cert-controller, `startupapicheck` coupé, ApplicationSet à 0 réplica, pas de Gateway CP.
- **Stockage** : un seul PVC en Phase B (lab-pg, 50 Go réels). Les 2 volumes du drill (100 Go) appartiennent à Paul.
- Cohabitation : réserve kube-ops S4 1025m + essai 215m = 1240m sur ≈ 1830m allouables.

## 5. Recommandations

### 5.1 Argo CD plutôt que Flux : confirmé

APP-CONTRACT §4-§5 a tranché pour Argo (D-2026-11-15-01, « Argo CD par cluster »). Ce choix tient pour l'essai, pour trois raisons :

- le bootstrap OKE de kube-ops utilise le même chart 10.3.3 ;
- `ignoreDifferences: /spec/projectRelease` est nécessaire au ProjectReleaseBinding ;
- `orphanedResources.warn` signale les objets créés hors Git (T5, MCP).

E-revue préférait Flux, à cause de la doc OpenChoreo (seul chemin documenté) et du poids d'Argo. Ce coût est mesuré à l'étape 11. Flux reste le repli si le budget casse.

Argo de l'essai :

- namespace `lab-argocd`, jamais `argocd` ;
- TLS conservé sur argocd-server : on ne reprend pas le `server.insecure` de kube-ops ;
- AppProject `lab` fermé : dépôt public sans identifiant, destinations `default`, `lab-pg` et `lab-argocd`, kinds listés, **ni RBAC ni CRD** ;
- `automated.prune: false` sur toute l'Application, ce qui inclut les kinds OpenChoreo, les VAP et le Cluster CNPG.

### 5.2 kgateway plutôt qu'une Gateway OKE

Le cluster nu n'a aucune implémentation Gateway API. La Gateway de Cilium est désactivée par la baseline (`gatewayAPI.enabled=false`, `envoy.enabled=false`). Les charts OpenChoreo codent `kgateway` en dur (HTTPListenerPolicy). On garde donc kgateway, avec :

- un **seul** Envoy (celui du DP) ;
- un Service **ClusterIP** (GatewayParameters, forme de la doc `api-gateway/topology.md`), donc 0 LoadBalancer OCI (quota `services.loadbalancers=0`) ;
- TLS par une CA d'essai namespacée.

L'exposition (Cloudflare Tunnel → ClusterIP) attend l'accord de Paul.

### 5.3 ESO obligatoire, store `lab-store` sans Doppler

Les secrets générés (`Password`, puis `PushSecret`, puis `ExternalSecret`) exigent ESO. Doppler exigerait un jeton créé par Paul, et son PushSecret reste [S]. Le provider ESO **kubernetes** vers `lab-secrets` répond au besoin :

- secrets générés dans le cluster ;
- un SA dédié, limité aux Secrets de `lab-secrets` ;
- `conditions.namespaceRegexes: [^dp-, ^lab-pg$]`.

Limite : une cellule peut demander n'importe quelle clé du coffre. La seule barrière est la règle CI des clés préfixées. Test de refus à ajouter en Phase C.

Hors périmètre : `clusters/oke/capabilities.yaml` doit passer `secretStore` à `lab-store`.

### 5.4 OIDC ThunderID : reporté en Phase C

Constats sur le chart 1.0.1 :

- 3 PVC obligatoires avec SQLite et `setup.enabled` : 150 Go OCI, impossible dans le quota ;
- conteneur en `capabilities.drop: [all]` minuscule, donc **refusé par PSA restricted** (PSA attend `ALL`) ;
- `seccompProfile` désactivé par défaut.

Recommandation, dans l'ordre :

1. Prouver sur k3d ThunderID **sans PVC** : `setup.enabled=false`, clés fournies par cert-manager et ESO (option documentée dans ses values), bases PostgreSQL sur lab-pg, namespace `openchoreo-thunder` en PSA baseline. Il faut alors passer `idpNamespace` du CPT de `thunder` à `openchoreo-thunder`.
2. Sinon, Authentik de kube-ops quand il existera sur OKE (E-revue §2.7).

En Phase B, l'issuer prévu (`https://thunder.lab.smadja.dev`) est déjà posé. L'API démarre, car le JWKS est chargé paresseusement (`middleware.go` l.120-128), et refuse les jetons.

## 6. Conflits entre la baseline #1620 réelle et l'installation

| # | Conflit | Effet | Solution minimale |
|---|---|---|---|
| **C1** | CCNP `allow-egress-unisolated` : `toEntities: [all]` pour tout namespace hors auth, backstage, hindsight et databases | Union Cilium : le default-deny egress de `openchoreo-*`, `lab-*`, `lab-pg` et **`dp-*`** (CPT) est neutralisé. L'installation passe, mais la primitive « default-deny egress » et les profils d'egress des cellules sont **non prouvables**. L'IMDS reste refusé (`deny-imds` prévaut). | PR kube-ops (Paul) : ajouter à son `endpointSelector.matchExpressions` deux exclusions par label : `{key: io.cilium.k8s.namespace.labels.platform.smadja.dev/egress-isolated, operator: DoesNotExist}` et `{key: io.cilium.k8s.namespace.labels.platform.smadja.dev/cell, operator: DoesNotExist}`. Les autres namespaces ne changent pas. Les namespaces d'essai portent déjà le label, et les cellules le reçoivent en constante du CPT. Pas d'exception globale. Effet suivi par `verify.sh --security` (S-egress). |
| C2 | VAP `baseline-pod-hardening` (Deny, tous namespaces sauf kube-system et cloudflared) | Aucun pod rendu n'est privileged, host* ou hostPath (`psa_check.py` sur les 7 rendus). Les Envoy rendus à l'exécution par kgateway et les pods CNPG restent [S]. | aucune |
| C3 | PSA : cluster-agent sans `seccompProfile`, interdit par le schéma du chart | Pas de `restricted` possible | `openchoreo-data-plane` en baseline + warn/audit restricted. Correctif amont à proposer. Ni `--skip-schema-validation` ni post-renderer. |
| C4 | AppArmor `Unconfined` par défaut (controller-manager, openchoreo-api) | Refusé par PSA baseline **et** restricted | `appArmorProfile: null` dans les values |
| C5 | Webhooks (cert-manager, OpenChoreo, CNPG ; `failurePolicy: Fail`) derrière default-deny ingress | Admission bloquée si le control plane managé n'est pas vu comme `kube-apiserver` par Cilium | CNP `fromEntities: [kube-apiserver]` sur le seul port du webhook. Repli : `fromCIDR 10.0.2.65/32` sur ce port. Testé par `verify.sh` (B3-webhook, B6-webhook) |
| C6 | `lab-pg` : NP `allow-apiserver` en ipBlock (k3d) | Sous Cilium, un ipBlock ne sélectionne pas l'identité kube-apiserver | overlay CNP `toEntities` (`51`), sans toucher `platform/data` |
| C7 | Coexistence future : kube-ops installera `cnpg-system`, `cert-manager`, `external-secrets` et `argocd` (bootstrap #1620) | Deux contrôleurs ESO ou cert-manager sur les mêmes CRD | Essai et bootstrap d'apps kube-ops **mutuellement exclusifs** sur oracle-a1 (OKE-EXEC : ne pas appliquer le bootstrap #1620 sur ce cluster). Nettoyer l'essai avant. |

Constats annexes sur #1620, à remonter sans les corriger ici :

- `applicationSet.enabled: false` n'existe pas dans argo-cd 10.3.3 : le pod tourne quand même.
- La CNP `allow-egress-github-backstage` (toFQDNs) n'a pas de règle DNS L7. Cilium n'apprendra probablement pas les IP [S].

## 7. Ce qui reste à prouver sur le cluster

- Tout ce qui est marqué [S] ci-dessus :
  - identité des appels webhook ;
  - Envoy kgateway sous PSA (rendu à l'exécution) ;
  - usage réel d'Argo ;
  - `readOnlyRootFilesystem` d'Envoy ;
  - `ClusterSecretStore` kubernetes `Ready` ;
  - toFQDNs `github.com`.
- Usage au repos de la pile sur 24 h ≤ 1,5 Gi et 300m (`measure.sh repos-24h`).
- Agent connecté en mTLS (condition du ClusterDataPlane) ; rendu d'une première app (whoami) ; RBAC réduit (étape 12).
- C1 corrigé, puis egress refusé depuis `openchoreo-*` et une cellule ; IMDS refusé depuis une cellule (T08f d'OKE).
- Taille réelle du PVC lab-pg (50 Go) et quota OCI.
- `uninstall.sh --all` rejoué (CLEANUP.md testé, Phase D).

## 8. Validation statique faite (2026-11-17, hors cluster)

- Charts récupérés : `helm pull` aux versions de `platform/install/versions.env` (digest OCI et sha256 du .tgz relevés).
- Images épinglées par digest d'index multi-arch ; plateforme arm64 vérifiée pour chaque image.
- `helm template` des 7 charts avec les values, puis `tools/oke/psa_check.py` : 0 écart. Niveau restricted partout, baseline pour le DP. Aucun objet hors du namespace de la release (cert-manager sans kube-system).
- Reproductible : `tools/oke/render-check.sh`.
- `kubeconform -strict` : manifests 67/67 valides, rendus 155/155 valides. Schémas générés depuis les CRD épinglées, CRD sautées.
- `yamllint -c tools/appgen/yamllint.yaml platform/install` : 0 erreur. Seuls avertissements : longueur de ligne de la copie upstream de `health-probes`.
- `shellcheck -x` : 0 constat. `bash -n` : OK. Garde de contexte testée hors ligne : refus d'un KUBECONFIG étranger.

Fichiers : `platform/install/{versions.env,values/,manifests/,argocd/}`, `tools/oke/{lib,preflight,install,measure,verify,uninstall,render-check}.sh`, `tools/oke/psa_check.py`.

À reporter hors de ce périmètre par le coordinateur :

- `clusters/oke/capabilities.yaml` : `secretStore: lab-store`.
- `platform/data/lab-pg-namespace.yaml` : labels `part-of` et `egress-isolated` (posés aujourd'hui par `install.sh`).
- CPT `idpNamespace` (Phase C).
- Correctif C1 dans kube-ops.
- `STATE.md`.
