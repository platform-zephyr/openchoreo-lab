# Capacité du homelab, data plane local et OKE à 4/24 (recherche du 2026-11-18)

Statut : PROPOSITION à Paul (aucun ADR modifié, aucun cluster touché). Dépôt public : aucune IP, aucun nom d'hôte, aucun secret.
Niveaux : [C] constaté dans un dépôt, [S] source externe lue, [E] estimé, [NP] non prouvé. Mesures runtime : aucune (lecture de fichiers seulement).

## 0. Conclusions

1. **Data plane local : une seconde VM Talos dédiée (« lab »), pas le cluster kube-ops.** Coût ≈ 2,5 Gio de RAM et 2 vCPU au repos [E] ; gain : isolation des données irremplaçables (Immich, Paperless…), périmètre agent sans conflit de CRD, canari des montées Talos/Cilium/Kyverno.
2. **Quand : dès S0** pour la VM et le socle (HOME-1 à HOME-3), **dès T-001 mergé** pour installer OpenChoreo (S1). Ne pas attendre T-030 ni NetBird : en **co-localisant le control plane (CP) et le data plane (DP) sur la VM lab**, aucun chemin réseau n'est requis pour la porte.
3. **Le CP sur OKE n'apporte plus l'indépendance annoncée** : le homelab est allumé 24 h/24 (D-2026-11-16-07), Authentik tourne au homelab, et tout l'état OpenChoreo vient de Git (CP rejouable). Recommandation : CP sur la VM lab pendant la porte ; OKE devient un DP optionnel (demande de Paul). Décision finale à la porte (D11).
4. **Capacité** : 64 Gio / 16 threads suffisent. Découpage proposé : hôte 6 Gio, VM kube-ops 34 Gio (48 aujourd'hui, à mesurer), VM lab 16 Gio (20 max), marge 6-8 Gio. Le facteur limitant est **thermique et sonore** (Tctl 94-97 °C observé) et le **NVMe** (≈ 150 Gio libres), pas la RAM.
5. **OKE à 4/24 : la page Oracle lue le 2026-11-18 dit le contraire de l'hypothèse (b).** « All tenancies get the first 1,500 OCPU hours and 9,000 GB hours per month » = 2 OCPU / 12 Go ; Oracle ne facture que « l'usage au-dessus des limites Always Free » après passage en PAYG. 4/24 est donc une limite de service (plafond), **pas un droit gratuit** : tout ce qui dépasse 2/12 est facturé (≈ 28 USD/mois pour 4/24 [E]). Garder 2/12 ; le quota OCI du dépôt est le garde-fou. HOME-11 n'est plus qu'une confirmation de facturation.
6. 4/24 desserre CPU, RAM et pods (deux nœuds 2/12 = 2 × 31 IP de pods), **pas le stockage bloc** (200 Gio, boots compris) ni la disponibilité.

## 1. Sources et fiabilité (Oracle et OpenChoreo relus en `curl` le 2026-11-18 ; Talos, Cilium, Proxmox : non relus)

| Sujet | Source | Date de lecture | État |
|---|---|---|---|
| A1 : « All tenancies get the first 1,500 OCPU hours and 9,000 GB hours per month… for Always Free tenancies, equivalent to 2 OCPUs and 12 GB » ; après passage en PAYG, Oracle « only charges for usage above the Always Free limits » ; 200 Go de bloc (boots compris), boot minimal 47 Go, VNIC proportionnels aux OCPU ; récupération des instances inactives (p95 CPU, réseau < 20 % sur 7 j ; mémoire < 20 % pour A1) | Oracle, `docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm` | 2026-11-18 | [S] primaire |
| Coupure de 4/24 à 2/12 dès 2026-06-15, rapportée sans annonce ; traitement PAYG « contesté » dans la presse | InfoQ 2026-07, Linuxiac (extraits de recherche) | 2026-11-18 | [S] secondaire, tranché par la page Oracle ci-dessus |
| Dépôt homelab-infra : 2/12 « fixé par Paul », 4/24 vu en PLT-183 = limite de service PAYG, pas un droit gratuit ; pas de réclamation d'instance inactive en PAYG | `docs/architecture/oracle-a1.md`, `terraform/oracle-a1/variables.tf` | 2026-11-18 | [C] |
| OpenChoreo v1.3.x : prérequis d'un plan distant (DP : Gateway API CRD, cert-manager, ESO, kgateway) ; cluster-gateway mono-réplique ; topologie « hybride » : CP + plans de build/observabilité ensemble, **DP dans des clusters séparés « pour donner aux workloads leurs propres clusters isolés »** ; topologie mono-cluster documentée ; minimum 4 cœurs / 8 Go par nœud (1 nœud suffit en test, 3 en production) ; mémoire du CP tributaire du nombre d'objets, CPU API ≈ 0,5 cœur par millier de composants | `openchoreo.dev/docs/platform-engineer-guide/multi-cluster-connectivity/`, `…/deployment-topology/`, `…/production-sizing/` | 2026-11-18 | [S] primaire |
| Cilium 1.20 exige Gateway API v1.6.1 (standard) | kube-ops `k8s/infrastructure/network/gateway-api/kustomization.yaml` l.4 | 2026-11-18 | [C] |
| Talos : gVisor déjà utilisé (extension officielle, RuntimeClass `gvisor`, agent-sandbox) ; ZFS : NVMe ≈ 1 To + 2 HDD 14 To en miroir ; Talos Image Factory / `UserVolumeConfig` | kube-ops `controllers/agent-sandbox/`, homelab-infra `docs/charter.md` l.188-189, `terraform/proxmox/README.md` | 2026-11-18 | [C] ; docs Talos, Proxmox, Cilium non relues en ligne |
| Usage réel kube-ops (24 h, 2026-11-11) : 2,28 cœurs, 27,2 Gio en moyenne ; Longhorn 3,4 Gio, kube-system 4,6 Gio | kube-ops `docs/state/cluster-reality.md` | 2026-11-11 | [C] ancien de 7 jours |

## 2. Q1 — Data plane local

### 2.1 Même cluster Talos que kube-ops : conflits constatés

| Sujet | Constat | Gravité |
|---|---|---|
| CRD Gateway API | Cilium 1.20 impose v1.6.1 ; le socle OpenChoreo du dépôt est calé sur v1.5.1 + kgateway v2.3.11 [C]. Un seul jeu de CRD par cluster ; compatibilité kgateway ↔ v1.6.1 [NP] | Élevée |
| ESO | `ClusterSecretStore doppler-cluster` lit tout `cluster/prd` ; une `ExternalSecret` d'une cellule `dp-*` pourrait le viser : il faudrait une VAP ciblée | Élevée |
| Kyverno | Politiques kube-ops globales (Audit, cible Enforce D-06) ; les pods OpenChoreo les déclenchent, une montée de Kyverno côté kube-ops change le lab | Moyenne |
| Argo | Deux Argo cluster-admin sur un cluster : ApplicationSets kube-ops en `prune+selfHeal` ; risque de suppression croisée, `instanceLabelKey` à séparer | Moyenne |
| Périmètre agent | `AGENTS.md` : écriture `openchoreo-*` / `lab-*` seulement ; or le CP crée des CRD, ClusterRole et VAP cluster-scopés, hors périmètre | Élevée |
| Réseau | CCNP/default-deny du lab testés sur le cluster des données irremplaçables ; interdiction de contourner une NetworkPolicy | Élevée |
| Montées | Talos/K8s/Cilium redémarrent prod et lab ensemble ; pas de canari (T-120 à T-138) | Moyenne |
| Ressources | Voisinage bruyant sur le même nœud et les mêmes disques Longhorn | Moyenne |

### 2.2 Recommandation : VM Talos « lab » (cluster séparé)

- **Isolation** : PKI, CRD, Kyverno, ESO (store propre `lab-store`, jamais `doppler-cluster`), Argo, CNI propres. Tout le cluster est périmètre agent ; kube-ops reste intact (aucun changement à valider avec lui).
- **Simplicité** : le module `terraform/proxmox/modules/talos` est paramétré (`node_count`, `vmid_start`, `cpus`, `memory`, disques) [C] : une seconde instance. Garder `proxmox` comme propriétaire d'état de l'objet VM (une racine par objet réel) ; option : racine `proxmox-lab` pour réduire le rayon d'un plan ARC. Kubeconfig lab distribué par Doppler comme celui de kube-ops (jamais demandé à Paul).
- **Stockage lab** : pas de Longhorn (3,4 Gio et 0,46 cœur chez kube-ops pour un mono-réplica [C]) ; volumes locaux Talos (`UserVolumeConfig` + local-path ou OpenEBS selon `docs/storage/STORAGE-RECOMMENDATION.md`), CNPG + barman vers R2.
- **Réseau** : VLAN ou règle UniFi (homelab-infra) : lab → Internet, lab → aucun accès à l'hôte Proxmox, au NAS, ni au réseau de gestion. Sans cela, un pod `dp-*` atteint le LAN.
- **Alternative écartée** : même cluster avec vcluster/namespaces. Elle économise 2,5 Gio mais garde les 4 conflits « Élevée » ci-dessus.

### 2.3 Quand

| Étape | Contenu | Prérequis | Début |
|---|---|---|---|
| HOME-0/1/2 | mesures, VM Talos lab, isolation réseau | MANDAT de Paul (VM, UniFi) | **S0** |
| HOME-3 | Cilium, Gateway API, cert-manager, ESO, Kyverno (audit), Argo lab, stockage | HOME-1, T-001 (installation fail-closed) | **S1** |
| HOME-4 | OpenChoreo CP + DP co-localisés, `ClusterDataPlane homelab`, app A de bout en bout | HOME-3, T-061 | **S1/S2** : remplace le cœur de T-030 |
| T-030 réduit | DP **OKE** distant (agent OKE → CP) : seulement si Paul demande une app sur OKE | HOME-4, chemin réseau | différé |

### 2.4 Chemin réseau homelab ↔ OKE

- Si le CP est sur la VM lab : aucun chemin pour le MVP. Un DP OKE devrait ouvrir une connexion **sortante OKE → homelab**, ce qui **contredit la règle « flux homelab → OKE seulement »** (`oracle-a1.md` l.24) : exception à décider par Paul (NetBird, ACL limitée au port 8443 de la cluster-gateway ; SAN en DNS).
- Si le CP reste sur OKE : NetBird L4 homelab → OKE (inchangé, MULTI-DATAPLANE §4) ; Cloudflare Tunnel HTTP reste exclu (le mTLS client est perdu).

## 3. Q2 — Capacité du homelab (64 Gio, 16 threads)

### 3.1 Budget mémoire proposé

| Poste | Gio | Remarque |
|---|---|---|
| Hôte Proxmox + cache ZFS (ARC plafonné) | 6 | réservé, jamais prêté |
| VM kube-ops (prod) | 34 | 48 aujourd'hui ; moyenne mesurée 27,2 ; ≈ 1,7 Gio récupérables en retirant falco, trivy, gatekeeper, keda, nfd, vpa (verdicts ALLÉGER) ; **réduire seulement après p95 sur 14 j** (HOME-0) |
| VM lab | 16 (20 max) | voir 3.2 |
| Marge (VM jetable : essai de montée Talos) | 6-8 | |

Le minimum documenté d'OpenChoreo est 4 cœurs / 8 Go pour un nœud de test (tous plans) : 8 Gio suffisent au socle (HOME-3), l'installation du CP+DP (HOME-4) vise 12-16 Gio donc après la réduction de la VM kube-ops. Démarrage sans toucher kube-ops : lab à 8 Gio / 4 vCPU (48 + 8 + 6 = 62), puis passage à 16 Gio après réduction de la VM kube-ops. Le changement de RAM d'une VM Talos redémarre le nœud (délai d'arrêt 600 s, volumes Longhorn détachés) : fenêtre dédiée.

### 3.2 Contenu de la VM lab (Gio de RAM, [E] sauf mention)

| Composant | Repos | Pointe | Où ? |
|---|---|---|---|
| Talos + K8s + Cilium + CoreDNS | 2,5 | 3 | lab |
| cert-manager, ESO, metrics | 0,4 | 0,6 | lab |
| Kyverno (admission, 1 réplique) | 0,3 | 0,6 | **lab** (mesuré chez kube-ops : 210/532 Mi) |
| Argo CD lab | 0,5 | 0,8 | lab |
| OpenChoreo CP (3 pods) + DP + Backstage | 1,0 | 1,5 | lab (CP : voir §4.4) |
| OpenBao ×1 (Raft sur disque local, snapshot hors site) | 0,15 | 0,3 | **lab** par défaut (D2 ; voir §5) |
| CNPG opérateur + `lab-pg` | 0,7 | 1,2 | lab |
| Crossplane + 2 providers (ADR-0009, différé) | 0,8 | 1,2 | lab, à la demande |
| Garage + jobs DuckDB (CronJob) | 0,3 | 2 | lab, données sur HDD |
| Runners ARC éphémères (CI sans Docker) | 0,1 | 2 | lab, plafonnés (cpulimit) |
| Sandboxes IA gVisor (3 concurrentes max) | 0 | 1,5 | lab (gVisor amd64 déjà prouvé chez kube-ops) |
| vcluster jetables pour agents (2 max, ≈ 0,4 chacun) | 0 | 0,8 | lab |
| Apps `development` + `production` (≈ 10 apps A/B) | 2,5 | 3,5 | lab |
| **Total** | **≈ 9,3** | **≈ 19** | 16 Gio tient au repos ; les pointes ne sont pas simultanées (plafond de concurrence 4, T-145) ; 20 Gio en réserve |

Ne vont **pas** dans la VM lab : les sessions d'agents (cloud ou N100, Atlas), k3d (Docker absent de Talos ; reste sur runners GitHub, T-002), OpenBao sur OKE (§5), les services IA lourds (aucune inférence locale : abonnement).
CPU : 16 threads SMT ≈ 8 cœurs physiques ; kube-ops 2,3 cœurs en moyenne, pointe ≈ 6. Proposition : kube-ops 10 vCPU (poids `cpuunits` 2000), lab 6 vCPU (poids 1000, `cpulimit` 5), 2 threads pour l'hôte. Tctl a atteint 94-97 °C et le bruit est un sujet ouvert (homelab-infra, boot-noise) : les rafales CI/sandbox sont limitées et une alerte Tctl > 85 °C coupe les runners (HOME-8).

### 3.3 Stockage (SSD ou HDD, ZFS)

- NVMe ≈ 1 To : kube-ops en utilise 256 (système) + 512 (rapide) provisionnés [C] ; reste ≈ 150 Gio. Lab : disque système 64 Gio + 64 Gio de données sur NVMe (provisionnement fin), le reste sur HDD.
- HDD (miroir ZFS 14 To ; ≈ 8 Tio déjà alloués à kube-ops [C]) : Garage, Parquet/DuckDB, sauvegardes locales, archives. **Jamais** etcd, PostgreSQL, Prometheus, Loki (IOPS de disque rotatif).
- ZFS est déjà en place (NVMe et miroir, `logbias`, `autotrim` appliqués [C]) : ne pas changer de système de fichiers ; plafonner l'ARC ; surveiller SMART/endurance du NVMe (lab = plus d'écritures). Snapshot ZFS de la VM lab avant chaque montée.
- Sauvegarde : barman → R2 (comme kube-ops), jamais seulement le même miroir.

## 4. Q3 — OKE à 4 OCPU / 24 Go

### 4.1 Limite et risque de facturation
- Le dépôt fixe 2/12 (quota OCI dur `oci_limits_quota`), à raison [C]. La page Oracle (2026-11-18) donne 1 500 h-OCPU et 9 000 h-Go par mois pour **tous** les tenancies, soit 2/12 ; le PAYG ne facture que le dépassement [S]. La coupure de juin 2026 rapportée par la presse est donc cohérente avec la page actuelle. 4/24 reste atteignable comme **plafond de service**, mais payant au-delà de 2/12.
- La récupération des instances inactives vise les « Always Free compute instances » ; son application à un tenancy PAYG n'est pas écrite sur cette page [NP] (le dépôt l'affirme sans source).
- Pire cas : +2 OCPU et +12 Go ≈ (2 × 0,01 + 12 × 0,0015) $/h × 730 ≈ 28 USD/mois [E, tarif non relu]. Garde-fous existants : quota 2/12, budget 0,01 USD (alerte après coup), budget de 20 €/mois.
- **Avant toute montée** (HOME-11, Paul) : confirmer par Cost Analysis le coût du dépassement ; un agent ne relève jamais le quota (ADR-0017 §7). Un essai « gratuit » de 4/24 n'est pas à tenter : la page Oracle l'exclut.

### 4.2 Ce que change 4/24 (payant : ≈ 28 USD/mois pour +2/12, à décider par Paul)
| Sujet | 2/12 (1 nœud) | 4/24 en 2 nœuds 2/12 [E] |
|---|---|---|
| CPU / RAM requests à 70 % | 1281m / 6055 Mi | ≈ 2560m / 12 100 Mi |
| Pods | 35 (≤ 33 retenus) | 2 × 35 ; IP VCN : 31 par nœud (2 VNIC) → 62 |
| Second domaine de panne | non | oui (drain d'un nœud sans coupure) |
| Bloc 200 Gio, boots compris (boot minimal 47 Go) | 150 pris, 50 libres | 2 boots → ≈ 100 pris + 2 volumes de drill : **≈ 0 libre** sans D5 |
| Authentik, OpenBao, CP, Kyverno | ne tiennent pas ensemble | tiennent, mais le bloc reste bloquant |

Un nœud unique 4/24 : les VNIC croissent avec les OCPU (Oracle) mais le nombre exact et `maxPods` ne sont pas vérifiés [NP] ; deux nœuds 2/12 sont la quantité connue, sans remplacement du nœud existant (redimensionnement du pool).

### 4.3 Conséquence sur la voie D1
Le homelab absorbe Kyverno, OpenBao, Crossplane, la data platform et les apps : **OKE n'a plus besoin de 4/24 pour la voie A**. 4/24 payant ne se justifie que si Paul demande des apps sur OKE ; le CP seul tient dans 2/12 (§4.4).

### 4.4 CP OpenChoreo : OKE ou homelab ?
| Critère | CP sur OKE | CP sur la VM lab (recommandé pour la porte) |
|---|---|---|
| Dépendance du DP principal (homelab) | OKE + NetBird + MANDAT ; chaque déploiement dépend du free tier | locale ; aucun chemin réseau |
| Indépendance vis-à-vis de la panne maison | oui, **mais** Authentik (OIDC du CP) est au homelab : l'indépendance n'est réelle qu'après migration d'Authentik | non ; workloads intacts, changements en attente |
| Charge | ≈ 0,5-1,5 Gio, pods et IP rares sur OKE | négligeable sur 16 Gio |
| Flux réseau | respecte homelab → OKE | un DP OKE exigerait OKE → homelab (exception) |
| Réversibilité | CP rejouable depuis Git (CR) dans les deux cas : déplacer = nouvelle URL d'agent + `clientCA` | idem |
| Vérification de la porte (C1, C4) | dépend de T-213, T-030, NetBird | indépendante, plus rapide |

Recommandation : **CP + DP homelab sur la VM lab jusqu'à la porte** ; à la porte, Paul choisit (D11) de le laisser ou de le déplacer vers OKE si OKE héberge des apps de Paul et qu'Authentik y est. Cela suppose d'amender ADR-0003 §1 et §6.

## 5. Q4 — Amendements proposés (texte)

**ADR-0003 (Topologie)** — remplacer §1 par : « Le control plane OpenChoreo est hébergé, pendant la porte (ADR-0020), sur le cluster `lab` (VM Talos dédiée du homelab), co-localisé avec le data plane `homelab`. Son emplacement définitif (lab ou OKE) est décidé par Paul à la porte (D11). » §2 : « Deux `ClusterDataPlane` (`homelab`, et `oke` seulement sur demande de Paul). » §6 : « Argo CD `lab` applique les objets OpenChoreo ; l'Argo de kube-ops ne gère jamais le cluster `lab`. » Contexte : remplacer « Talos sur Proxmox, nœud unique » par « deux clusters Talos sur le même hôte (kube-ops : données de production ; lab : plateforme) ». Ajouter : « Le homelab est allumé 24 h/24 (D-2026-11-16-07) ; `availability: always` partout ». Alternatives écartées : retirer « Control plane sur le homelab » (raison caduque), ajouter « OpenChoreo sur le cluster kube-ops (conflits CRD Gateway API, ESO, Kyverno, périmètre) ». Conséquences : OKE ≤ 2/12 sauf MANDAT de Paul pour un dépassement payant ; flux OKE → homelab exige une exception si un DP OKE existe.

**ADR-0017 (Coût)** — Contexte : « A1 : gratuit = 1 500 h-OCPU + 9 000 h-Go par mois pour tous les tenancies, soit 2/12 (Oracle, page Always Free, lue le 2026-11-18) ; 4/24 est un plafond de service payant au-delà de 2/12 (≈ 28 USD/mois). Quota OCI du dépôt = 2/12. » §1 : « Coût additionnel 0 € ; électricité et usure du matériel du homelab non comptées (à estimer une fois). » Ajouter §8 : « Toute montée A1 au-delà de 2/12 est payante : MANDAT de Paul avec coût mensuel chiffré. » Ajouter §9 : « Budget de capacité du homelab (RAM, NVMe, Tctl) versionné dans `docs/state/homelab-capacity.yaml` avec seuils d'alerte à 80 %. »

**ADR-0020 (Porte)** — C2 : « C2 : nomenclature du **cluster hébergeant le CP** mesurée ≤ 70 % des requests et ≤ 70 % de la RAM allouée (lab : 16 Gio), places réservées incluses ; **si le CP est sur OKE** : ≤ 33 pods et ≤ 70 % (inchangé). » C4 : « agent reconnecté sans action après 3 coupures simulées (redémarrage de la VM lab, arrêt du pod agent 10 min ; et NetBird 10 min si un DP OKE existe) » (le homelab n'est plus éteint la nuit). C1 : ajouter « sur le cluster `lab` ». §3 : l'échec d'une voie n'exige plus de MANDAT NetBird. §4 : T-030 devient HOME-4.

**TARGET-ARCHITECTURE** — §2 schéma : le cadre Talos « éteint la nuit » devient « 24 h/24 », avec deux VM (kube-ops, lab) ; §3 : Kyverno, OpenBao, Argo, CP : lab ; §7 : l'option C (CP sur Talos) n'est plus « écartée » mais « recommandée pendant la porte » ; ajouter ligne « Hôte Proxmox : budget §3 de ce rapport ». §6 : le budget OKE ne compte plus CP/Backstage tant qu'ils sont sur lab.
**MULTI-DATAPLANE** — `availability: scheduled` supprimé ; ajouter `arch: amd64|arm64` aux capacités (homelab amd64, OKE arm64 : images multi-arch) ; §4 : NetBird seulement si DP OKE ; cluster `homelab` = VM lab.
**DECISIONS-OPEN** — D1 : reformuler en « A (2/12, 0 €) recommandé ; B′ = 2 nœuds 2/12 payants (≈ 28 USD/mois) seulement sur demande d'app OKE par Paul ». D2 : OpenBao **sur lab** (Raft, snapshot chiffré hors site, un seul volume local) ; OKE lit Doppler (pas de route OKE → homelab). D3 : Kyverno sur lab. D4 : un Argo par cluster, `lab-argocd` devient l'Argo du lab. Nouvelles : **D11** emplacement du CP à la porte ; **D12** seconde VM Talos et réduction de la VM kube-ops (MANDAT) ; **D13** exception de flux OKE → homelab (seulement si DP OKE) ; **D14** confirmation de facturation A1 (HOME-11).

**Tickets** — T-030 : réduit à « DP OKE distant », `deferred` ; son cœur devient HOME-4 (S1). T-031 : le test de coupure porte sur la VM lab (HOME-6). T-213 : plus bloquant du MVP (Argo OKE seulement si OKE sert) ; T-022 : variante « OpenBao sur lab » prioritaire ; T-140 : trancher 2/12 vs 4/24 avec la source Oracle relue ; T-145 : ajouter la concurrence CPU/thermique ; T-212 : cible lab (backend plain). Nouveaux : HOME-0 à HOME-12 (`backlog/proposals/homelab.yaml`).

## 6. Non prouvé / à relire
Relire (curl) : tarifs PAYG Oracle, docs Talos (Image Factory, UserVolume), Cilium Gateway API, Proxmox. Non mesuré : p95 14 j de la VM kube-ops, usage réel du NVMe, nombre de VNIC d'un nœud 4 OCPU, compatibilité kgateway ↔ Gateway API v1.6.1, empreinte réelle d'une VM Talos mono-nœud (2,5 Gio estimés). k3d ≠ OKE ≠ lab : aucun PASS ici.
