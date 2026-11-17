# Phase B : OpenChoreo 1.3.3 minimal sur OKE oracle-a1

> Statut réel (2026-11-17) : **étapes 1 à 5 appliquées sur OKE** (18:22-18:28Z), critères de sortie PASS (§9).
> Étapes 6, 6b et 7-12 : **non exécutées**. Jalon réseau : **BLOCKED (C1)**. Correctifs de la revue
> `docs/REVIEW-PHASE-B.md` intégrés hors cluster le 2026-11-17 (§8) ; leur effet runtime reste à prouver (§7).

## 0. Conclusion

1. L'installation tient en **12 étapes idempotentes, plus 6b (portail)** (`tools/oke/install.sh --step N`, dry-run par défaut : aucune écriture, seulement des lectures de garde). Chaque étape a un critère de sortie (`tools/oke/verify.sh --step N`), un rollback (`tools/oke/uninstall.sh --step N`) et une mesure de budget. L'installation s'arrête si l'usage MAXIMAL de la pile dépasse **1,5 Gi ou 300m au repos** (code 3), si une mesure manque (code 4) ou si les requests de tous les pods dépassent **70 %** de l'allocatable (code 5).
2. Requests d'OpenChoreo (CP + DP + kgateway + Envoy) : **55m / 304 Mi** sans portail, **65m / 624 Mi** avec le portail (backstage 10m / 320 Mi), contre 850m / 1088 Mi sur k3d. Elles sont calées sur l'usage mesuré, sans descendre sous lui. Pile complète avec cert-manager, ESO et Argo CD : 155m / 1360 Mi. Avec CNPG et lab-pg : 225m / 1552 Mi.
3. **Conflit bloquant pour la preuve, pas pour l'installation (C1)** : la CCNP kube-ops `allow-egress-unisolated` (allow-all egress cluster-wide) s'additionne aux NetworkPolicy (union Cilium). Elle **neutralise le default-deny egress** de `openchoreo-*`, `lab-*` et `dp-*`. Correctif minimal à faire dans kube-ops : §6.
4. **IdP : Authentik externe** (`https://auth.smadja.dev/`, issuer global, clients distincts portail / service / CLI / agents ; `docs/IDENTITY.md`). ThunderID abandonné (3 PVC = 150 Go OCI). Tant que les clients Authentik n'existent pas, l'API et le MCP refusent tout appel (401) : l'échec est fermé.
5. Une seule exception PSA : `openchoreo-data-plane` est en `baseline`. Le schéma du chart DP interdit `seccompProfile` sur le cluster-agent. Tous les autres pods rendus sont `restricted` (vérifié statiquement).

## 1. Préconditions (toutes requises avant l'étape 1)

- [ ] Relire `…/side-session-notes/local_35b37a0a-…/idp/agents/OKE-EXEC.md` (chemin complet dans `STATE.md`). Vérifier : cluster nu et qualifié, baseline #1620 appliquée (3 VAP, CCNP `allow-egress-unisolated` et `deny-imds`), `prevent_destroy` rétabli (hi #616 mergée).
- [ ] **Accès opérateur ouvert par Paul** avec `open-oke-access.sh open [ttl ≤ 10800]` (bastion OCI, tunnel 127.0.0.1:16443, kubeconfig 0600 dans `~/.cache/oke-access/`). Un agent ne crée **jamais** cet accès. La session dure au plus 3 h : les étapes sont reprenables (`--from N`). Fermer avec `open-oke-access.sh close`.
- [ ] `export KUBECONFIG=~/.cache/oke-access/kubeconfig`. Les scripts refusent tout autre fichier, tout contexte qui n'est pas `context-oracle-a1-*`, tout `admin@*`, `*homeops*` ou `*homelab*`, un serveur différent de `https://127.0.0.1:16443`, un `tls-server-name` hors 10.0.2.0/24, et un cluster qui n'a pas exactement 1 nœud arm64 OCI. Si le contexte réel s'appelle autrement (`oci ce create-kubeconfig` produit `context-c…`), Paul fixe `OKE_CONTEXT_RE` en connaissance de cause.
- [ ] `tools/oke/preflight.sh` retourne `GO` (lecture seule).
- [ ] Avant l'étape 10 : **accord écrit de Paul sur le stockage** (`--confirm-storage`, toujours interdit par `missions/MISSION.md` au 2026-11-17). lab-pg crée 1 block volume de 50 Go. Le budget actuel est boot 50 + 2 × 50 Go restés du drill = 150/200 Go.
- [ ] Mesure « avant » : `tools/oke/measure.sh avant`.
- [ ] Avant toute désinstallation avec `--delete-crds` : `$STATE_DIR/crds-before.txt` (inventaire écrit par `preflight.sh` avant l'étape 1). **Absent sur OKE** (preflight du 2026-11-17 antérieur à cette fonction) : `--delete-crds` conservera donc toutes les CRD (échec fermé).

### 1.1 Reprise après les étapes 1-5 du 2026-11-17 (dans cet ordre, avant l'étape 6)

| # | Action | Pourquoi | Preuve attendue |
|---|---|---|---|
| R1 | `install.sh --step 1 --apply` | crée `lab-cnpg`, relève le quota CP (640 Mi / 2304 Mi) ; la garde refuse tout namespace préexistant sans `part-of` | `verify.sh --step 1` PASS sauf `B1-legacy-cnpg` |
| R2 | `uninstall.sh --migrate-cnpg-system` (dry-run), puis `--apply` | supprime l'ancien `cnpg-system` **seulement** s'il est vide (aucun pod, PVC, release Helm, ni objet sans `part-of`) et marqué essai | `verify.sh --step 1` : `B1-legacy-cnpg` PASS |
| R3 | `install.sh --step 4 --apply` | `helm upgrade` d'ESO : annotation `helm.sh/resource-policy: keep` sur les 23 CRD (revue I1) | `verify.sh --step 4` : `B4-crd-keep` PASS. Tant que ce n'est pas fait, `uninstall.sh --step 4` refuse |
| R4 | `verify.sh --step 1` (motif PSA exact, VAP `baseline-image-digest`) | les PASS B1-admission du 2026-11-17 utilisaient un motif trop large (revue m1) | `B1-admission`, `B1-vap-digest` PASS |

## 2. Plan ordonné

`install.sh --step N` sans `--apply` affiche le plan. Avec `--apply`, il exécute puis mesure. Après chaque étape, lancer `verify.sh --step N`.

| # | Étape | Critère de sortie (`verify.sh --step N`) | Rollback (`uninstall.sh --step N`) |
|---|---|---|---|
| 0 | `preflight.sh` | `GO` | — |
| 1 | Namespaces, quotas, LimitRange, NetworkPolicy/CNP (`manifests/00,01,02`). **Garde** : refus si un de ces namespaces existe sans `part-of=openchoreo-lab` | PSA attendue par namespace ; quota et `lab-default-deny` partout ; pod privileged+hostNetwork refusé avec le motif `violates PodSecurity "restricted` ; image sans digest refusée par `baseline-image-digest` ; `cnpg-system` absent | suppression des namespaces d'essai (label `part-of=openchoreo-lab` exigé), puis migration `cnpg-system` (§1.1) |
| 2 | Gateway API CRD v1.5.1 (sha256 vérifié) | 5 CRD `Established` | CRD supprimées seulement avec `--delete-crds` et si inutilisées ailleurs |
| 3 | cert-manager v1.19.4 → `openchoreo-cert-manager` | 3 Deployments Available ; rien dans kube-system ; webhook joignable (dry-run d'un Issuer) | `helm uninstall` (refusé si la release ne déclare pas `keep` sur ses CRD) ; CRD gardées (`crds.keep`) |
| 4 | ESO 2.0.1 → `openchoreo-external-secrets` + `ClusterSecretStore lab-store` ; CRD annotées `helm.sh/resource-policy: keep` | ESO Available ; `lab-store` Ready ; `B4-crd-keep` | suppression du store, `helm uninstall` **refusé** tant que la release ne porte pas `keep` sur ses 23 CRD |
| 5 | kgateway-crds + kgateway v2.3.11 → `openchoreo-control-plane` | kgateway Available ; GatewayClass `kgateway` Accepted | `helm uninstall kgateway` ; `kgateway-crds` (CRD dans `templates/`, sans `keep` possible) **conservée** sauf `--delete-crds` et gardes |
| 6 | Egress IdP (`03-idp-egress.yaml`), OpenChoreo CP 1.3.3 avec OIDC Authentik, **sans portail** (`--set backstage.enabled=false`), ni event-forwarder ni Gateway CP ; CA du cluster-gateway copiée. Refus si le portail est déjà actif | CP Available ; ConfigMap CA peuplé ; webhook OK (dry-run du CCT) ; `/health` 200 ; `/mcp` sans jeton **401** ; CNP IdP présentes ; aucune liaison `mcp-tryout`/`platform-engineer`/`sre` | `helm uninstall`, suppression de `03` ; CRD `openchoreo.dev` avec `--delete-crds` |
| 6b | Portail Backstage (`docs/PORTAL.md` §4) : préconditions lues (quota CP 640 Mi / 2304 Mi, Secret `backstage-secrets` avec ses 4 clés, créé hors dépôt), puis `helm upgrade` du CP avec `backstage.enabled=true`. Seulement si nommée (`--step 6b` ou `--with-portal`) | `verify.sh --step 6b` : Deployment `backstage` Available, 1 pod, 0 redémarrage ni OOMKilled ; PSA (pas d'AppArmor Unconfined) ; ni HTTPRoute, Ingress, PVC ni Service non ClusterIP ; redirection vers Authentik (P2). P3-P5 : BLOCKED (navigateur). **Arrêt** sur tout FAIL ou code 3/4/5 du budget | `helm upgrade` avec `backstage.enabled=false`, suppression du Secret et de la CNP `lab-allow-backstage-authentik` |
| 7 | Security bundle vérifié (`docs/SECURITY-BUNDLE.md`) et rendu durci contrôlé AVANT toute écriture, puis VAP du labo (`platform/policies`, VAP-1 avec CONNECT et `*/*`), TLS (`11`), GatewayParameters (`12`), OpenChoreo DP 1.3.3 par `helm_secure` : les droits du cluster-agent sont rendus avec le chart (jamais ceux d'origine, même transitoirement) | agent et Envoy Available ; Gateway `Programmed` ; aucun Service LB ou NodePort ; release durcie (B7-bundle) ; permissions effectives de l'agent (B7-agent-effective) ; RoleBinding hors `dp-*` refusé (B7-agent-rb) ; ClusterRoleBinding de l'agent refusée par VAP-1 ; **`kubectl exec --as=<agent>` dans `openchoreo-control-plane` refusé par VAP-1** (B7-exec) ; Namespace `dp-*` restricted admis, privileged refusé (B7-psa-ok / B7-psa-lock) | `helm uninstall`, puis suppression de 11, 12, quota RBAC et VAP (dans cet ordre) ; **refusé** tant qu'une Application Argo `lab-root`/`lab-platform` existe |
| 8 | `ClusterDataPlane default` : `clientCA` = `ca.crt` de `cluster-agent-tls` (procédure de D-gitops-empreinte §6), `secretStoreRef: lab-store` | CDP présent ; **`status.agentConnection.connected=true`, `connectedAgents ≥ 1`, heartbeat < 5 min** (B8-agent) ; journal de l'agent sans refus VAP-1 ni erreur TLS | `kubectl delete clusterdataplane default` |
| 9 | Label `openchoreo.dev/control-plane=true` sur `default` (exception OpenChoreo, `missions/MISSION.md`) ; Environment `production`, DeploymentPipeline `standard`, ClusterTrait `health-probes` (`40`) ; CCT, ClusterTrait PVC, CPT, CRT du labo | objets présents | refus tant qu'il reste des Components (CLEANUP.md 2) ou qu'Argo adopte ; puis suppression et retrait du label |
| 10 | Opérateur CNPG 0.29.1 (**`lab-cnpg`**), `lab-pg-namespace` (garde de propriété), overlay `51` (dont NP `lab-cnpg` → `lab-pg:8000`), `lab-pg-cluster` (**`--confirm-storage`**, interdit sans accord écrit de Paul) | Cluster `Ready` ; 1 PVC Bound ; PSA restricted ; opérateur Available dans `lab-cnpg` | suppression du Cluster (le PVC et son volume OCI d'essai partent avec), `helm uninstall` ; **refusé** tant qu'Argo adopte (selfHeal recréerait un volume de 50 Go) |
| 11 | Argo CD 10.3.3 (v3.5.1) → `lab-argocd`, AppProject `lab` (kinds cluster-scoped **nommés**, Authz* bloqués) et `lab-authz` (seul porteur de l'authz, chemin `platform/authz/`, sync manuelle), Application `lab-root` (adopte les objets des étapes 7, 9, 10 via `lab-platform`) | `lab-root` et `lab-platform` `Synced` et `Healthy` ; AppProject `lab` et `lab-authz` présents | suppression des Application (sans finalizer : objets conservés), des AppProject, `helm uninstall` ; CRD argoproj gardées si un namespace `argocd` existe |
| 12 | **Sans effet** : intégrée à l'étape 7 (security bundle). Conservée pour ne pas casser `--to 12` | `verify.sh --step 12` = mêmes contrôles que B7-bundle et B7-agent-effective (utile après un upgrade ou un rollback) | aucun ; rollback du DP : `tools/oke/security-bundle.sh rollback openchoreo-data-plane REV` (refusé si la révision n'est pas durcie), jamais `helm rollback` direct |
| — | `verify.sh --security` (pod de sonde éphémère) | DNS OK ; IMDS 80 injoignable ; intra-namespace OK ; **egress Internet refusé** (`BLOCKED` tant que C1 est ouvert) | suppression du pod |

Ordre des `platform/*` : `policies/` passe **avant** le data plane, pour qu'aucune écriture du cluster-agent n'échappe à VAP-1 (étape 7). `cluster-agent/extra-rbac-quota.yaml` n'est plus appliqué : les droits du cluster-agent viennent du security bundle, avec le chart (étape 7 ; complément `lab-pg` à l'étape 10, après le namespace). Étapes 6, 6b, 7 et 10 : security bundle obligatoire, vérifié au démarrage d'`install.sh` (aussi en dry-run et avec `--step`/`--from`) ; `helm rollback` direct interdit sur les releases OpenChoreo (`docs/SECURITY-BUNDLE.md` § Rollback). `component-types/`, `traits/`, `project-types/` et `resource-types/` passent après l'enregistrement (étape 9). `data/lab-pg-*` vient ensuite (étape 10). Argo adopte le tout en dernier (étape 11).

Nettoyage complet : `uninstall.sh --all --apply` (12 → 1, 6b avant 6), aligné sur `CLEANUP.md`. Il ne touche que les namespaces de `TRIAL_NS` étiquetés `part-of=openchoreo-lab`, l'ancien `cnpg-system` s'il est vide et marqué, les `dp-*` étiquetés `platform.smadja.dev/cell=restricted` et le label de `default`. Toute lecture en erreur arrête le script (aucun `|| true` sur kubectl). Les CRD ne partent qu'avec `--delete-crds`, si elles ne figurent pas dans `crds-before.txt` et qu'aucun objet hors essai (namespacé hors `openchoreo-*`/`lab-*`/`dp-*`, ou cluster-scoped sans `part-of` ni release Helm d'essai) ne les utilise ; au moindre doute, elles restent.

Relancer l'étape 9 ou 10 après l'étape 11 provoque un conflit SSA avec le gestionnaire d'Argo (revue m12) : échec franc voulu, Argo est alors le seul écrivain.

## 3. Namespaces et mise sous baseline

| Namespace | Contenu | Nom imposé ? | PSA enforce | Quota (req. cpu/mém., pods) | Réseau |
|---|---|---|---|---|---|
| `openchoreo-control-plane` | controller-manager, openchoreo-api (MCP), cluster-gateway, kgateway, backstage (6b) | convention OpenChoreo (URL d'agent par défaut) | restricted | 100m / **640 Mi** (limites 2304 Mi), 8 | default-deny ; DNS ; apiserver (CNP) ; intra ; ingress depuis DP sur :8443 (agent) et :9977 (xDS) ; webhook :9443 depuis kube-apiserver ; api et backstage → `auth.smadja.dev:443` (`03`, toFQDNs) |
| `openchoreo-data-plane` | cluster-agent, Envoy `gateway-default` (ClusterIP) | **oui** : VAP-1 et `platform/cluster-agent` nomment le SA | **baseline** (warn/audit restricted) | 50m / 192 Mi, 4 | default-deny ; DNS ; apiserver ; egress vers CP :8443/:9977 et vers les cellules (`platform.smadja.dev/cell`) |
| `openchoreo-cert-manager` | cert-manager (3 pods), CA de la ClusterIssuer éventuelle | non | restricted | 50m / 256 Mi, 4 | default-deny ; DNS ; apiserver ; webhook :10250 depuis kube-apiserver |
| `openchoreo-external-secrets` | contrôleur ESO seul | non | restricted | 25m / 128 Mi, 2 | default-deny ; DNS ; apiserver |
| `lab-secrets` | Secrets générés (coffre de `lab-store`), aucun pod | non | restricted | 0, 0 pod | default-deny |
| `lab-argocd` | Argo CD (controller, repo-server, server, redis) | non (pas `argocd`, réservé à kube-ops) | restricted | 100m / 640 Mi, 6 | default-deny ; DNS ; apiserver ; intra ; repo-server → `github.com:443` (toFQDNs + visibilité DNS) |
| `lab-cnpg` | opérateur CNPG (remplace `cnpg-system`, revue B3) | non | restricted | 50m / 128 Mi, 2 | default-deny ; DNS ; apiserver ; → lab-pg :8000 ; webhook :9443 depuis kube-apiserver |
| `lab-pg` | instance CNPG lab-pg + Jobs du CRT | défini par `platform/data` | restricted | 200m / 512 Mi, 4, **1 PVC** | NP de `platform/data` + CNP apiserver (overlay `51`, la NP k3d en ipBlock ne vaut pas sous Cilium) |
| `dp-*` | cellules d'apps (Phase C) | **oui** : préfixe du contrôleur OpenChoreo (exception acquittée, détail à acquitter par Paul : `missions/MISSION.md`) | restricted (constante du CPT ; VAP-1 interdit à l'agent de la baisser) | quota du CPT | default-deny du CPT |
| `default` | objets OpenChoreo des apps (aucun pod), label `openchoreo.dev/control-plane=true` | **oui** : `tools/appgen` génère dans `default` (exception acquittée, détail à acquitter par Paul) | inchangée | — | — |

Prérequis strictement requis par OpenChoreo 1.3.3 : **Gateway API CRD, cert-manager, kgateway** (les deux charts rendent `gatewayClassName: kgateway`, des `HTTPListenerPolicy` et des Certificate). **ESO** est requis par le labo (CRT `cnpg-lab-db`, CCT). ThunderID et OpenBao ne sont pas requis pour démarrer. Aucun de ces prérequis n'impose son namespace : cert-manager quitte `cert-manager`, avec `global.leaderElection.namespace` rapatrié de `kube-system`, et ESO quitte `external-secrets`. Exceptions au préfixe `openchoreo-*`/`lab-*` : `dp-*` et le label de `default`, imposés par OpenChoreo (`missions/MISSION.md`). `cnpg-system` n'en est plus une (renommé `lab-cnpg`). Hors périmètre de ce pack, à corriger par PR : la NP `allow-intra-dns-operator` de `platform/data/lab-pg-namespace.yaml` (l.37) nomme encore `cnpg-system` ; l'overlay `51` ajoute la NP équivalente pour `lab-cnpg` en attendant.

Labels communs : `app.kubernetes.io/part-of=openchoreo-lab` (nettoyage) et `platform.smadja.dev/egress-isolated=true` (marqueur du correctif C1).

## 4. Budget, requests et mesures

| Composant | Requests retenues (cpu / mém.) | Limites | Base (mesure k3d, RESULTS.md / FOOTPRINT.txt) |
|---|---|---|---|
| controller-manager | 15m / 64 Mi | 500m / 384 Mi | CP hors Backstage et kgateway ≈ 106 Mi pour 3-4 pods |
| backstage (6b) | 10m / 320 Mi | 1000m / 768 Mi | 4-9m, 259 Mi (`docs/PORTAL.md` §2) |
| openchoreo-api (+MCP) | 10m / 48 Mi | 500m / 256 Mi | idem |
| cluster-gateway | 5m / 24 Mi | 200m / 128 Mi | idem |
| kgateway | 10m / 96 Mi | 500m / 256 Mi | ≈ 85 Mi mesurés |
| cluster-agent | 5m / 24 Mi | 100m / 128 Mi | DP = 6-12m, 33 Mi (agent + Envoy) |
| Envoy DP (GatewayParameters) | 10m / 48 Mi | 500m / 256 Mi | idem |
| **OpenChoreo** | **55m / 304 Mi** (65m / 624 Mi avec 6b) | | **avant : 850m / 1088 Mi** (event-forwarder retiré, Backstage à 10m) |
| cert-manager ×3 | 15m / 192 Mi | | 3m, 192 Mi |
| ESO (contrôleur seul) | 5m / 64 Mi | | 5m, 109 Mi pour 3 pods |
| Argo CD ×4 | 70m / 480 Mi | | **non mesuré** (requests de kube-ops #1620) [S] |
| CNPG + lab-pg | 70m / 192 Mi | | 11m, 84 Mi |

- Budget **au repos**, sur l'usage et non sur les requests : pile = `STACK_NS_RE` de `tools/oke/lib.sh`, soit `openchoreo-control-plane`, `openchoreo-data-plane`, `openchoreo-cert-manager`, `openchoreo-external-secrets`, `lab-argocd`, `lab-secrets`, `lab-cnpg`, `lab-pg` et `dp-*`, ≤ **1,5 Gi et 300m** (objectif d'optimisation, `missions/MISSION.md`).
- **Méthode du MAX** : `install.sh` mesure après chaque étape ≥ 3 (et 6b) : 3 échantillons à 20 s, chacun réessayé 3 fois s'il est indisponible ; on journalise les valeurs, la moyenne et le **maximum**, et c'est le **maximum** qui est comparé au budget (jamais le minimum ni la moyenne). Code 3 si dépassé ; **code 4 `MEASUREMENT_UNAVAILABLE`** si une mesure manque (API kubelet en erreur, namespace de la pile avec des pods Running absent du résumé, valeur NA, ou `kubectl` en erreur : jamais lu comme zéro, jamais de PASS) ; puis `capacity_gate` : requests effectives de **tous** les pods ≤ **70 %** de l'allocatable CPU et mémoire, comparaison entière exacte (70,9 % échoue), code 5 sinon. `measure.sh` mesure à la demande (avant, après chaque étape, au repos sur 24 h). Projection à partir de k3d : ≈ 40-80m et 0,7-0,95 Gi sans portail, ≈ 0,96-1,21 Gi avec, dont Argo [S].
- **Preuves de budget invalidées** : dans `$STATE_DIR/budget.log`, les lignes « étape 3 cpu=0m mem=0Mi », « étape 4 … 70Mi » et « étape 5 … 101Mi » (18:25-18:28Z) viennent d'une version antérieure du gate qui lisait une mesure absente comme zéro : **elles ne valent pas PASS**. Seule mesure valable : 18:31:44Z, méthode du MAX, pile = 5m / 135 Mi (budget 300m / 1536 Mi) ; capacité 18:31:47Z : requests 385m / 1830m (21 %), 1038 Mi / 8650 Mi (12 %).
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

### 5.4 OIDC : Authentik externe (ThunderID abandonné)

ThunderID 1.0.1 imposait 3 PVC (150 Go OCI) et n'était pas conforme à PSA restricted. Décision (`docs/IDENTITY.md`, `missions/MISSION.md`) : **Authentik du homelab**, issuer global `https://auth.smadja.dev/`, un provider par client (`openchoreo-backstage-client`, `openchoreo-backstage-service`, `openchoreo-cli`, `openchoreo-agent-reader`, `openchoreo-agent-operator`). Intégré dans `platform/install/values/openchoreo-control-plane.yaml` : `security.oidc` (issuer, `jwksUrl`, `authorizationUrl`, `tokenUrl`, `wellKnownEndpoint`), audience vide, sujets `user` (`groups`, `preferred_username`) et `service_account` (`client_id`), `bootstrap.mappings` remplacé (`admin` ← `authentik-admins`, `developer` ← `openchoreo-developers`, `backstage-catalog-reader` ← `openchoreo-backstage-service` ; `mcp-tryout-client-binding` supprimée). L'API démarre sans clients (JWKS paresseux, `middleware.go` l.120-128) et refuse tout jeton : échec fermé. `iss` global à prouver (T-A1).

## 6. Conflits entre la baseline #1620 réelle et l'installation

| # | Conflit | Effet | Solution minimale |
|---|---|---|---|
| **C1** | CCNP `allow-egress-unisolated` : `toEntities: [all]` pour tout namespace hors auth, backstage, hindsight et databases | Union Cilium : le default-deny egress de `openchoreo-*`, `lab-*`, `lab-pg` et **`dp-*`** (CPT) est neutralisé. L'installation passe, mais la primitive « default-deny egress » et les profils d'egress des cellules sont **non prouvables**. L'IMDS reste refusé (`deny-imds` prévaut). **Constaté sur OKE** : `S-egress` BLOCKED (OPEN-HTTP depuis le namespace isolé) à 18:32, 18:33 et 18:43Z le 2026-11-17 ; jalon réseau **BLOCKED** jusqu'au correctif kube-ops (#1629). | PR kube-ops (Paul) : ajouter à son `endpointSelector.matchExpressions` deux exclusions par label : `{key: io.cilium.k8s.namespace.labels.platform.smadja.dev/egress-isolated, operator: DoesNotExist}` et `{key: io.cilium.k8s.namespace.labels.platform.smadja.dev/cell, operator: DoesNotExist}`. Les autres namespaces ne changent pas. Les namespaces d'essai portent déjà le label, et les cellules le reçoivent en constante du CPT. Pas d'exception globale. Effet suivi par `verify.sh --security` (S-egress). |
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
- Agent connecté en mTLS (`status.agentConnection` du ClusterDataPlane) ; rendu d'une première app (whoami) ; RBAC réduit (étape 12).
- VAP-1 étendue (CONNECT, `*/*`, verrou PSA des `dp-*`) : B7-exec et B7-psa-lock refusés, B7-psa-ok admis ; aucune écriture légitime de l'agent refusée pendant le rendu de whoami (journal sans `lab-cluster-agent-scope`). Les expressions CEL n'ont été évaluées par aucun API server.
- Portail (6b) : P1-P6 de `docs/PORTAL.md` ; `iss` global Authentik (T-A1) ; synchro du catalogue avec `openchoreo-backstage-service`.
- AppProject `lab` : refus réel d'un objet cluster-scoped non nommé (ex. Application de test pointant une VAP `baseline-*`, en dry-run Argo) ; `lab-authz` seul porteur de l'authz.
- Migration `cnpg-system` → `lab-cnpg` (§1.1) et annotation `keep` des CRD ESO.
- C1 corrigé, puis egress refusé depuis `openchoreo-*` et une cellule ; IMDS refusé depuis une cellule (T08f d'OKE).
- Taille réelle du PVC lab-pg (50 Go) et quota OCI.
- `uninstall.sh --all` rejoué (CLEANUP.md testé, Phase D).

## 8. Validation statique faite (2026-11-17, hors cluster)

Correctifs de la revue (5 points « avant l'étape 6, puis 7 »), revalidés le 2026-11-17 au soir sans cluster :
- `tools/oke/render-check.sh` (charts épinglés, sha256 OK, cache Helm isolé sous `$STATE_DIR/helm`) : 8 rendus dont le CP sans et avec portail ; `psa_check.py` rc 0 partout (restricted, baseline pour le DP) ; **0 PVC, 0 Service LoadBalancer/NodePort, 0 image sans digest** ; 23/23 CRD ESO et 6/6 CRD cert-manager avec `keep`.
- `kubeconform -strict` : manifests `platform/install/{manifests,argocd}` + `platform/policies` 75/75 valides (schémas tirés des CRD des charts épinglés et de `fetch-ext-schemas.sh`) ; rendus 199 valides, 43 CRD sautées.
- `tools/oke/argo_guard.py` : 0 écart ; cas négatif (VAPB `baseline-pod-hardening`, Namespace `kube-system`, `ClusterAuthzRoleBinding` sous `policies/`) : 4 écarts, rc 1.
- `install.sh --step N` sans `--apply`, N = 1…12 et 6b, avec des `kubectl`/`helm` factices qui journalisent : seuls `config view`, `config current-context` et `get` sont appelés ; aucune écriture. Gardes vérifiées : namespace préexistant sans `part-of` refusé ; `uninstall.sh --step 7|9|10` refusé si Argo adopte ; migration `cnpg-system` refusée avec un objet étranger.
- `helm pull --repo` : échoue avec le cache Helm du poste (`no cached repo found … crowdsec-index.yaml`), réussit avec le cache isolé.
- Job CI à intégrer : `docs/CI-PLATFORM-CHECKS.md`.

Validation initiale (avant la revue) :

- Charts récupérés : `helm pull` aux versions de `platform/install/versions.env` (digest OCI et sha256 du .tgz relevés).
- Images épinglées par digest d'index multi-arch ; plateforme arm64 vérifiée pour chaque image.
- `helm template` des 7 charts avec les values, puis `tools/oke/psa_check.py` : 0 écart. Niveau restricted partout, baseline pour le DP. Aucun objet hors du namespace de la release (cert-manager sans kube-system).
- Reproductible : `tools/oke/render-check.sh`.
- `kubeconform -strict` : manifests 67/67 valides, rendus 155/155 valides. Schémas générés depuis les CRD épinglées, CRD sautées.
- `yamllint -c tools/appgen/yamllint.yaml platform/install` : 0 erreur. Seuls avertissements : longueur de ligne de la copie upstream de `health-probes`.
- `shellcheck -x` : 0 constat. `bash -n` : OK. Garde de contexte testée hors ligne : refus d'un KUBECONFIG étranger.

Fichiers : `platform/install/{versions.env,values/,manifests/,argocd/}`, `tools/oke/{lib,preflight,install,measure,verify,uninstall,render-check}.sh`, `tools/oke/psa_check.py`.

À reporter hors de ce périmètre par le coordinateur :

- `platform/data/lab-pg-namespace.yaml` l.37 : `cnpg-system` → `lab-cnpg` (puis retirer la NP de transition de l'overlay `51`).
- Job CI `platform` (`docs/CI-PLATFORM-CHECKS.md`) dans `.github/workflows/ci.yaml`.
- `platform/identity/authz/openchoreo-authz.yaml` duplique des noms de `platform/authz/` (`lab-viewer`, `lab-*-binding`) : seul `platform/authz/` est synchronisé (projet `lab-authz`) ; à dédoublonner.
- CPT `idpNamespace` (Phase C) ; correctif C1 dans kube-ops (#1629) ; `STATE.md`.

## 9. Preuves runtime OKE (2026-11-17, `$STATE_DIR` = `~/.cache/openchoreo-lab-phaseb/`)

| Étape | Appliquée (steps.log) | Critère de sortie (verify.log) |
|---|---|---|
| 1 | 18:22:50Z | B1 PASS 18:22:53-18:23:27Z (PSA, quota, default-deny sur 7 namespaces dont l'ancien `cnpg-system` ; admission avec l'ancien motif large, à rejouer : §1.1 R4) |
| 2 | 18:23:39Z | B2 PASS ×5 (18:23:42Z et 18:23:52Z) |
| 3 | 18:25:08Z | B3 PASS (deploy, noks, webhook) 18:25:12Z et 18:25:21Z |
| 4 | 18:26:41Z | B4 PASS (deploy, store) 18:26:44Z et 18:26:49Z ; `B4-crd-keep` à obtenir (§1.1 R3) |
| 5 | 18:28:03Z | B5 PASS (deploy, GatewayClass) 18:28:07Z et 18:28:12Z |
| budget | — | 18:31:44Z pile 5m / 135 Mi (MAX) ; capacité 21 % CPU / 12 % mémoire. Lignes antérieures invalidées (§4) |
| réseau | — | 18:43Z : S-dns PASS, S-imds PASS (témoin :53), S-intra PASS (kgateway:9977), **S-egress BLOCKED (C1)** ; S-cleanup PASS 18:45:01Z |
