# Architecture cible de l'IDP (OpenChoreo) — conception, rien n'est déployé par ce document

Statut : **PROPOSÉ** (2026-11-17). Cible actée par Paul ; ce document **n'autorise aucune installation**.
Il ne retarde pas le golden path `whoami` sur OKE (étapes 6 à 11 de `docs/PHASE-B.md`), qui tient dans le budget actuel (§6.4).

Marqueurs : **[M]** mesuré (preuve datée), **[P]** publié (chart, documentation éditeur, valeurs de production existantes), **[E]** estimé (non mesuré).

## 1. Conclusion

1. **La cible complète ne tient pas sur le nœud OKE actuel**, même avec les requests « plancher » du dépôt (calées sur l'usage mesuré) :
   - au repos, 1180m CPU (64,5 %), 4510 Mi (52 %), mais **35 pods sur 35** et 29 IP VCN sur 31, avant toute application ;
   - en exploitation, une restauration d'Authentik monte à 1400m (76,5 %), au-delà du seuil de 70 % ;
   - avec les requests publiées des charts, le CPU atteint **2045m (112 %)** ;
   - le **stockage bloc** manque : il reste 50 Go, soit **un seul** volume OCI (50 Go minimum), alors que la cible en demande au moins 2, plus 1 pour une restauration (§6.3).
2. Le golden path `whoami` (CP + DP + portail + Argo, Authentik restant au homelab) tient : environ 510m (28 %), 2046 Mi (24 %), 25 pods (§6.4).
3. Deux voies, à arbitrer par Paul (`DECISIONS-OPEN.md`, D1) :
   - **A, à 0 €** : OKE n'héberge que le plan de contrôle et l'identité ; Kyverno et toutes les applications vont sur Talos. Au repos, cela tient de justesse (60 %, 33 pods), mais il ne reste **aucune capacité** pour un Data Plane OKE utile, et les 100 Go des volumes de drill doivent être libérés.
   - **B, environ 30 €/mois [E]** : un second nœud A1 de 2 OCPU / 12 Go en PAYG, plus 100 Go de bloc. La cible entre sous le seuil de 70 % avec des marges d'exploitation (§7). C'est **la recommandation** si l'IDP doit remplacer durablement l'implémentation actuelle.
4. Un **second nœud A1 « gratuit » n'existe pas** : l'Always Free A1 vaut **2 OCPU et 12 Go au total** pour la tenancy ([doc Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), confirmé par homelab-infra `docs/architecture/oracle-a1.md` l.3). Découper ce quota en deux nœuds n'ajoute aucune capacité et double le coût système.

## 2. Schéma

```text
                     GitHub (openchoreo-lab, kube-ops)          Doppler (secrets externes, bootstrap)
                       │ PR → CI (GitHub Actions) → merge             │
                       ▼                                               ▼
 ┌──────────────────────────── OKE oracle-a1 (cloud, 24/7) ────────────────────────────────┐
 │  Argo CD (1 par cluster) ── applique ──► OpenChoreo CR (Project/Component/RB…)           │
 │                                     └──► charts Helm « plateforme » (Authentik, OpenBao…)│
 │  OpenChoreo Control Plane : controller-manager, openchoreo-api (+MCP), cluster-gateway   │
 │     │ OIDC (JWKS)                         ▲ wss mTLS :8443 (agents en SORTIE)            │
 │  Backstage (portail, catalogue unique) ───┘                                              │
 │  Authentik (server, worker, CNPG) ◄── OIDC de tout le monde (CP, portail, Argo, apps)    │
 │  OpenBao (secrets internes générés) ── ESO ──► Secrets K8s ◄── ESO ── Doppler            │
 │  cert-manager, ESO, kgateway, Gateway API, Cilium (kube-ops #1620), PSA + VAP            │
 │  Data Plane « oke » : cluster-agent ──(in-cluster)──► cluster-gateway ; Envoy ; cellules │
 │  cloudflared (exposition sortante) ; netbird-router (chemin privé admin + agents)       │
 └────────────────────────────────────▲────────────────────────────────────────────────────┘
                                      │ NetBird (sortant depuis le homelab, aucun port entrant)
 ┌──────────────────────────── Talos homelab (local, éteint la nuit) ──────────────────────┐
 │  Data Plane « talos » : cluster-agent ──wss mTLS──► cluster-gateway (OKE)                │
 │  Envoy/kgateway, cert-manager, ESO (ClusterSecretStore propre), Kyverno + PSA + VAP      │
 │  Stockage : OpenEBS LVM fast/bulk, CNPG lab-pg (docs/storage/STORAGE-RECOMMENDATION.md)  │
 └──────────────────────────────────────────────────────────────────────────────────────────┘
```

## 3. Composants et responsabilités

| Composant | Responsabilité | Ne fait pas | Emplacement cible |
|---|---|---|---|
| GitHub + Actions | source de vérité, PR, CI (`appgen`, kubeconform, politiques) | aucun accès au cluster (pas de runner sur OKE, ADR OKE §3) | SaaS |
| Argo CD | GitOps pull, un par cluster, AppProject restreints | builds ; écritures hors Git | OKE (puis un Argo Talos, D4) |
| OpenChoreo CP 1.3.3 | API, rendu des Components, liaisons, MCP, cluster-gateway | stockage d'état hors etcd | OKE |
| Backstage (openchoreo-ui 1.3.3) | portail et **catalogue unique** (`CATALOG-CONTRACT.md`) | source de vérité (le catalogue est dérivé) | OKE |
| Data Plane OKE | services cloud légers, sans état ou à petit état | gros volumes | OKE |
| Data Plane Talos | applications locales, stockage important | dépendre de lui pour le CP ou l'identité | Talos |
| Kyverno | policy-as-code (matrice : `docs/KYVERNO-POLICY-CONTRACT.md`, **pas encore écrit**) ; complète PSA et VAP | remplacer PSA/VAP, qui restent la base | Talos certainement ; OKE seulement en voie B (D3) |
| PSA + VAP | garde-fous natifs, sans webhook | — | les deux clusters |
| OpenBao | secrets **internes générés** (mots de passe de bases, clés d'app) | bootstrap, secrets tiers | OKE (D2) |
| Doppler | secrets **externes** et de **bootstrap** (jeton ESO, Cloudflare, R2) | générer des secrets internes | SaaS |
| ESO | **distribution** vers des `Secret` K8s (un `ClusterSecretStore` par magasin et par cluster) | stocker | les deux clusters |
| Authentik | IdP central (OIDC, `client_credentials`), indépendant du homelab à terme | passer derrière Cloudflare Access (circularité, ADR OKE l.62) | OKE |
| cloudflared | exposition publique sortante | transporter le mTLS des agents (§MULTI-DATAPLANE 4) | OKE (+ homelab) |

## 4. Déployé aujourd'hui et cible

| Élément | Aujourd'hui (OKE, `STATE.md`) | Cible |
|---|---|---|
| Socle kube-ops #1620 (Cilium chaining, CCNP `deny-imds` + `allow-egress-unisolated`, VAP baseline ×3) | présent, PR **non mergée** ; C1 BLOCKED (l.29) | mergé, avec le correctif C1 (#1629) |
| Étapes 1-5 : namespaces/quotas, Gateway API v1.5.1, cert-manager, ESO + `lab-store`, kgateway v2.3.11 | **PASS** 2026-11-17 | idem |
| OpenChoreo CP / DP / ClusterDataPlane `default` / types | EN ATTENTE (étapes 6-9) | CP + 2 ClusterDataPlane (`oke`, `talos`) |
| Backstage | EN ATTENTE (6b), SQLite éphémère, port-forward | portail exposé (Cloudflare Tunnel + Access, accord de Paul), catalogue fédéré |
| Argo CD | EN ATTENTE (11), `lab-argocd` | **un seul** Argo par cluster (D4) |
| Authentik | homelab (`auth.smadja.dev`), éteint la nuit (`STATE.md` l.56) | OKE, CNPG dédié, sauvegarde R2 (ADR OKE PLT-384) |
| OpenBao | absent (k3d en mode dev seulement) | OKE, Raft ou backend PostgreSQL, auto-unseal (D2) |
| Kyverno | absent sur OKE ; présent au homelab (kube-ops) | Talos ; OKE selon D3 |
| CNPG + `lab-pg` | NON AUTORISÉ (volume 50 Go) | bases applicatives sur Talos ; sur OKE, seulement la base de la plateforme |
| Data Plane Talos | non | à prouver (`MULTI-DATAPLANE.md`) |

## 5. Dépendances, ordre d'installation et circularités

### 5.1 Ordre (chaque étape ne dépend que des précédentes)

| # | Étape | Dépend de | Restaurable sans OpenChoreo ? |
|---|---|---|---|
| 0 | OCI/OKE (homelab-infra `terraform/oracle-a1`), socle kube-ops #1620 + C1, StorageClass `oci-bv` | — | oui (OpenTofu, kustomize) |
| 1 | Gateway API CRD, cert-manager, ESO + `ClusterSecretStore` Doppler (jeton créé par l'opérateur) | 0 | oui |
| 2 | CNPG opérateur + plugin barman | 1 | oui |
| 3 | **Authentik** + CNPG dédié (restauration depuis R2) ; secrets depuis Doppler | 1, 2 | **oui, obligatoire** |
| 4 | **OpenBao** (auto-unseal hors cluster, snapshot R2) ; `ClusterSecretStore` OpenBao | 1 (et 2 si backend PostgreSQL) | **oui, obligatoire** |
| 5 | **Argo CD** (admin local de secours ; OIDC Authentik optionnel) | 1 | **oui, obligatoire** |
| 6 | kgateway, puis CP OpenChoreo (OIDC Authentik), puis portail | 1, 3 | — |
| 7 | DP OKE + `ClusterDataPlane oke` + types de plateforme | 6 | — |
| 8 | Exposition cloudflared (Authentik **sans** Access ; portail **avec** Access) | 3, 6 | — |
| 9 | Chemin NetBird agents, puis DP Talos + `ClusterDataPlane talos` | 6, 0 (NetBird) | — |
| 10 | Kyverno (matrice d'ownership) | 1 | — |

### 5.2 Règles anti-circularité

| Règle | Pourquoi | Contrôle proposé |
|---|---|---|
| Authentik, OpenBao et Argo ne sont **jamais** des Components OpenChoreo ; ce sont des charts Helm de plateforme, installables par `helm`/`kustomize` à la main | une panne d'OpenChoreo ne doit pas empêcher leur redémarrage ni leur restauration | `appgen` refuse ces noms (changement proposé) |
| Les secrets d'Authentik, d'Argo et le jeton ESO viennent de **Doppler**, jamais d'OpenBao | OpenBao peut être scellé ; le bootstrap doit rester possible | revue ; ExternalSecret de ces namespaces limités à `doppler-cluster` |
| Le déscellement d'OpenBao ne dépend ni d'Authentik ni d'OpenChoreo ; clés de récupération hors ligne | `docs/storage/OPENBAO-DOPPLER-ESO.md` §2 | exercice de restauration |
| Argo garde un **admin local** (port-forward) ; son OIDC Authentik est un confort | Argo doit pouvoir restaurer Authentik | `configs.cm.admin.enabled: true` (déjà dans `platform/install/values/argocd.yaml`) |
| Authentik n'est pas derrière Cloudflare Access | Access utilise Authentik comme IdP | ADR OKE l.62, l.119 |
| Webhooks d'admission (Kyverno) : `failurePolicy: Ignore` ou exclusion des namespaces `auth`, `openbao`, `argocd`, `kube-system` | un webhook `Fail` sur un nœud unique bloque la restauration | à inscrire dans `KYVERNO-POLICY-CONTRACT.md` |
| OpenChoreo ne dépend que de l'**OIDC** d'Authentik (lecture JWKS, échec fermé) | `platform/install/values/openchoreo-control-plane.yaml` (commentaire sur `middleware.go` l.120-128) | test T-A1 (`docs/IDENTITY.md` §9) |

### 5.3 Dépendances partagées avec kube-ops (aucune autre dépendance technique)

| Objet partagé | Propriétaire | Ce qu'openchoreo-lab en attend | Risque |
|---|---|---|---|
| Socle #1620 : Cilium chaining, CCNP `deny-imds` et `allow-egress-unisolated`, VAP baseline ×3, VAP anti-LoadBalancer | kube-ops `k8s/clusters/oracle-a1` | isolation réseau ; C1 corrigé par #1629 (label `platform.smadja.dev/egress-isolated`) | #1620 non mergée : la baseline vit hors Git |
| StorageClass `oci-bv` (défaut OKE), quotas OCI | OKE / homelab-infra | `capabilities.yaml` | 50 Go minimum facturés par volume |
| CRD cluster-scoped : Gateway API, cert-manager, ESO, `argoproj.io` (`crds.keep`) | premier installeur | versions compatibles | une désinstallation peut supprimer des CRD (bloquant n° 2 de la revue) |
| `ClusterSecretStore doppler-cluster`, jeton Doppler | kube-ops | secrets de bootstrap | un jeton lit tout `cluster/prd` (ADR OKE §2) |
| Blueprints Authentik (clients OpenChoreo) | kube-ops (production protégée) | `docs/IDENTITY.md` §5 | changement d'IdP = PR kube-ops |
| cloudflared, netbird-router | kube-ops `oracle-a1` | exposition, chemin des agents Talos | — |
| Argo CD `oracle-a1` de kube-ops (`argocd`) et `lab-argocd` | les deux dépôts | — | deux Argo sur un nœud : 4 pods, 480 Mi en double (D4) |

## 6. Budget consolidé OKE

### 6.1 Capacité du nœud et seuil

| Ressource | Allocatable réel | Seuil 70 % | Source |
|---|---|---|---|
| CPU (requests) | 1830m | **1281m** | `STATE.md` l.10 [M] |
| Mémoire (requests) | 8650 Mi (≈ 8,4 GiB) | **6055 Mi** | `STATE.md` l.25 [M] |
| Pods | 35 | (ne pas dépasser 33 : garder 2 pods pour Jobs et rollouts) | donnée de la mission [M] |
| IP de pods VCN-native | ≈ 31 (2 VNIC) | — | ADR OKE l.79 ; `docs/PHASE-B.md` l.104 |
| Disque éphémère | ≈ 28,4 Go | GC des images à 85 % | `docs/storage/OKE-AUDIT-2026-11-17.md` [M] |
| Block Volume | 200 Go de quota ; 150 Go pris (boot 50 + 2 volumes de drill de 50, à Paul) ; **≈ 50 Go libres = 1 volume** | — | OKE-AUDIT [M] |

### 6.2 Requests par composant (cible complète sur OKE)

Plancher = requests posées par les values du dépôt (calées sur l'usage mesuré, jamais en dessous) ou, hors dépôt, par CAPACITY.md.
Publié = defaults du chart ou valeurs de production existantes. Quand rien n'est publié, la colonne Publié reprend le plancher.

| Composant | Pods / IP | MESURÉ | PUBLIÉ (cpu/mém.) | PLANCHER retenu | Sources |
|---|---|---|---|---|---|
| Système K8s (OKE + Cilium, kube-system) | 9 / 3 | requests **355m / 686 Mi** [M] | — | 355m / 686 Mi | mesure OKE ; CAPACITY.md l.18-19 |
| cert-manager ×3 | 3 / 3 | usage 3m / 192 Mi (k3d) | 30m / 208 Mi (kube-ops) | 15m / 192 Mi | `docs/PHASE-B.md` §4 ; CAPACITY.md l.24 |
| ESO (contrôleur seul) | 1 / 1 | 5m / 109 Mi pour 3 pods (k3d) | 25m / 100 Mi | 5m / 64 Mi | `values/external-secrets.yaml` l.27 |
| kgateway | 1 / 1 | ≈ 85 Mi (k3d) | aucun default | 10m / 96 Mi | `values/kgateway.yaml` l.19 |
| OpenChoreo CP : controller-manager, api+MCP, cluster-gateway | 3 / 3 | ≈ 15-40m, ≈ 106 Mi (k3d) | **500m / 576 Mi** | 30m / 136 Mi | chart 1.3.3 `values.yaml` l.272, 2296, 3859 |
| Backstage (SQLite éphémère) | 1 / 1 | 4-9m, 259 Mi (k3d, 2 h) | 200m / 256 Mi (chart l.2869) ; 250m / 512 Mi (kube-ops #1618) | 10m / 320 Mi | `docs/PORTAL.md` §2 |
| DP OKE : cluster-agent + Envoy | 2 / 2 | 6-12m, 33 Mi (k3d) | agent 50m / 128 Mi (chart DP l.507) + Envoy 10m / 48 Mi | 15m / 72 Mi | `values/openchoreo-data-plane.yaml` |
| Argo CD ×4 (sans dex, notifications, AppSet) | 4 / 4 | **non mesuré** | 70m / 480 Mi (kube-ops) | 70m / 480 Mi [E] | `values/argocd.yaml` |
| Kyverno minimal (admission + background) | 2 / 2 | non mesuré | 200m / 192 Mi (defaults du chart Kyverno 3.x [E à relire]) | 75m / 256 Mi (kube-ops homelab) | kube-ops `k8s/infrastructure/security/kyverno/values.yaml` l.1-33 |
| CNPG opérateur + plugin barman | 2 / 2 | non mesuré | 60m / 192 Mi | 60m / 192 Mi | CAPACITY.md l.25 |
| Authentik server + worker + CNPG (instance + sidecar barman) | 3 / 3 | non mesuré | Authentik : hôte de 2 CPU / 2 Go minimum | 420m / 1632 Mi | kube-ops `auth/authentik/values.yaml` l.268-271, `database.yaml` l.27-30 ; CAPACITY.md l.31-33 |
| OpenBao ×1 | 1 / 1 | mode dev k3d : 31m / 43 Mi (avec Thunder) | chart sans requests par défaut | 50m / 128 Mi [E] | `tests/k3d/RESULTS.md` |
| cloudflared + netbird-router | 2 / 2 | non mesuré | 40m / 128 Mi | 40m / 128 Mi | CAPACITY.md l.26 |
| Alloy (export Grafana Cloud) | 1 / 1 | non mesuré | 25m / 128 Mi | 25m / 128 Mi | CAPACITY.md l.27 |
| **Total au repos** | **35 / 29** | — | **2045m (112 %) / 4978 Mi (58 %)** | **1180m (64,5 %) / 4510 Mi (52 %)** | |

### 6.3 Verdict par ressource (plancher)

| Ressource | Au repos | Exploitation | Verdict |
|---|---|---|---|
| CPU | 1180m, 64,5 % | rollout Authentik (+100m) : 1280m, 69,9 % ; restauration Authentik (+220m) : **1400m, 76,5 %** | **ne tient pas** en exploitation |
| Mémoire | 4510 Mi, 52 % | restauration (+608 Mi) : 5118 Mi, 59 % | tient |
| Pods | **35/35** avant le moindre service applicatif | tout rollout ou Job échoue | **ne tient pas** |
| IP VCN | 29/31 | +1 par rollout | limite |
| Block Volume | 50 Go libres = 1 volume | Authentik-db 50 Go (le minimum OCI de 50 Go s'applique ; le « 20 Gi → 21,5 Go » de CAPACITY.md l.10 est sous-évalué) + OpenBao 50 Go + restauration 50 Go = **150 Go** | **ne tient pas**, sauf si l'on libère les 2 volumes de drill (alors exactement 200/200, sans marge) |
| Disque éphémère | images ≈ 6-9 Go [E], emptyDir bornés ≈ 8 Gi (Argo 3,25 Gi, Authentik media 2 × 2 Gi) | — | tient probablement ; **NON MESURÉ** (`crictl imagefsinfo` à relever) |

### 6.4 Ce qui tient maintenant (golden path `whoami`, Authentik au homelab)

Calcul : 385m / 1038 Mi mesurés après les étapes 1-5, plus CP 30m / 136 Mi, portail 10m / 320 Mi, DP 15m / 72 Mi et Argo 70m / 480 Mi.
Résultat : **510m (28 %), 2046 Mi (24 %), 25 pods** (avec `whoami`). Rien dans ce document ne change l'ordre `STATE.md` « Ordre de livraison ».

## 7. Propositions de séparation ou d'évolution

| Option | Contenu | CPU / mém. au repos (plancher) | Pods | Bloc | Coût | Limites |
|---|---|---|---|---|---|---|
| **A. Séparation, 0 €** | OKE : CP + portail + Authentik + OpenBao + Argo + socle + DP OKE minimal. Talos : Kyverno, toutes les applications, `lab-pg` | 1105m (60 %), 4254 Mi (49 %) | 33/35 | Authentik + OpenBao dans **un seul** CNPG « plateforme » (backend PostgreSQL d'OpenBao, à vérifier) = 50 Go + 50 Go de restauration : exige de **libérer les volumes de drill** | 0 € | aucune capacité applicative sur OKE ; restauration Authentik à 72 % (il faut arrêter le portail pendant l'opération) ; pas de Kyverno sur OKE (PSA + VAP seulement, conforme à l'ADR OKE l.42) |
| **B. Second nœud A1 2 OCPU / 12 Go en PAYG** (recommandée) | même node pool ou second pool ; Authentik et OpenBao épinglés sur un nœud (volumes AD-1) | capacité ×2 : 1180m / 3660m = **32 %** ; 2045m publiés = 56 % | 35/70 | +100 Go de bloc (3 volumes + 1 de restauration) | ≈ (2 × 0,01 + 12 × 0,0015) $/h × 730 h ≈ 28 USD/mois, plus 100 Go × 0,0425 USD ≈ 4 USD/mois, soit **≈ 32 USD/mois** [P, à reconfirmer : la page tarif Oracle répond 403, et une autre page publique cite 0,0131 $/OCPU] | exige de lever le « Free Tier strict » (ADR OKE §3) et les quotas de compartiment (PLT-260) |
| B'. Agrandir le nœud à 4 OCPU / 24 Go | une seule forme | idem B | selon la `maxPods` et le nombre de VNIC de la forme [E] | idem | idem | remplacement du nœud (fenêtre, BVR) ; pas de second domaine de panne |
| C. Plan de contrôle sur Talos | — | — | — | — | — | **écartée** : le CP et l'identité doivent rester toujours disponibles (homelab éteint la nuit) |

Règle commune : **aucune request n'est baissée pour faire entrer la cible**. Si l'usage mesuré sur OKE dépasse une request, la request monte (`docs/PHASE-B.md` §4).

## 8. Changements proposés (hors périmètre de ce flux, PR séparées)

- `tools/appgen` : refuser les noms de composants de la plateforme (authentik, openbao, argocd, backstage).
- `tools/oke/lib.sh` : ajouter au gate de capacité un contrôle « pods ≤ 33 » à côté du seuil de 70 %.
- `docs/PHASE-B.md` §4 : remplacer « ≈ 31 pods » par les deux limites distinctes (35 pods ; 31 IP VCN).
- CAPACITY.md (notes de session, hors dépôt) : corriger le volume Authentik à 50 Go facturés.

## 9. Prouvé et non prouvé

- **Prouvé [M]** : allocatable, requests kube-system, étapes 1-5, état des volumes OCI, usage k3d d'OpenChoreo et de Backstage.
- **Non prouvé** : usage réel sur OKE d'Argo, d'Authentik, d'OpenBao et de Kyverno ; disque éphémère consommé par les images ; nombre maximal de pods selon la forme ; tarif PAYG actuel ; backend PostgreSQL d'OpenBao dans la version qui sera épinglée.
