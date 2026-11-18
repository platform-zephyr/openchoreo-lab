# Exigences de homelab-infra (base des ADR OpenChoreo hybride)

Date : 2026-11-18. Lecture seule de `homelab-infra` (privé) @ `042f1cb`. Références `chemin:ligne` relatives à ce dépôt. Aucun secret, identifiant de compte, CIDR ni IP reproduit : mécanismes seulement. Complète `KUBE-OPS-REQUIREMENTS.md` (non répété). Légende : [C] constaté en code/doc, [S] supposé, non vérifié.

## 0. Conclusions

1. Le socle est **déjà séparé proprement** : homelab-infra = ressources externes (OCI, Cloudflare, Doppler, GitHub, UniFi, Proxmox) en OpenTofu via ARC ; kube-ops = tout l'état Kubernetes (`AGENTS.md:18`, `docs/architecture/invariants.md:16`). Crossplane ne doit donc **pas** reprendre les roots socle.
2. Les ressources « par application » sont aujourd'hui **dispersées et centralisées en Tofu** : secrets générés par app dans la root `doppler`, sous-domaines et Access par app dans la root `cloudflare`, clients OIDC en blueprints Authentik côté kube-ops. C'est le vrai point de friction pour « déclarer une app en un fichier ».
3. Authentik n'a **aucun** provider Tofu ici : ses clients OIDC sont des blueprints (kube-ops) ; seul le secret client est généré par Tofu puis posé dans Doppler (`terraform/doppler/generated-app-secrets.tf:135-200`) [C].
4. Le wildcard public `*.smadja.dev` vers la Gateway externe est **déjà** porté par homelab-infra (`INV-EDGE-01`, `invariants.md:78`) : un DNS par app n'est pas nécessaire pour les apps Kubernetes.
5. Les `decisions` imposent : PR + CI verte + retour arrière réel pour merger ; MANDAT pour l'irréversible (données, secrets, nouvelle exposition publique) ; Tofu seulement via ARC.

---

## 1. Réseau OKE ↔ homelab

### 1.1 Cilium sur OKE (chaining) [C]
- Cluster **reconstruit en VCN-native** (`cni_type = OCI_VCN_IP_NATIVE`, cluster et node pool, ForceNew) : `terraform/oracle-a1/main.tf:92,154` ; sous-réseau de pods + NSG : `terraform/oracle-a1/network.tf:1-30`. Avant : Flannel overlay, sans application des NetworkPolicy (`docs/architecture/oke-target-architecture.md:47,53`).
- **Cilium 1.20.4 en chaining** au CNI OCI (`cni.chainingTarget=oci`, « même version que le homelab ») : `oke-target-architecture.md:15,38`. Installé par le bootstrap opérateur de kube-ops (Helm), non par Tofu : `oke-target-architecture.md:207`.
- Choix motivé par le score (option A 64 %, repli Flannel 70 % mais sécurité 1/5) : `oke-target-architecture.md:69-76`. Calico, Kyverno, Enhanced (Workload Identity) rejetés : `:232-238`.
- Politiques cluster-wide appliquées (qualifiées, `acceptance.sh` PASS le 17/11) : 3 ValidatingAdmissionPolicy + 2 CiliumClusterwideNetworkPolicy, `allow-egress-unisolated` et `deny-imds` (ports 80/443 ; le 53 reste ouvert car le résolveur VCN partage l'adresse de l'IMDS) : `oke-target-architecture.md:16,22-23,29-30`. Un `egressDeny` seul met les pods en default-deny egress, d'où l'`allow` : `:22`.
- Limite structurante : **31 IP de pods par nœud A1 (2 VNIC)** ; budget retenu 19 IP, 21 avec Backstage et pg-shared : `oke-target-architecture.md:79`. Chaque agent/app/pod OpenChoreo consomme une IP VCN.
- Les NSG s'appliquent aussi aux VNIC des pods, indépendamment de Cilium ; la security list de pods est vide, les NSG sont la seule allow-list : `network.tf:10-16`. **L'IMDS n'est filtré ni par NSG ni par security list** : seul le CCNP le bloque : `network.tf:20-26`.

### 1.2 Identique / différent

| Sujet | Homelab (Talos) | OKE `oracle-a1` | Preuve |
|---|---|---|---|
| CNI | Cilium (kube-proxy remplacé) | Cilium 1.20.4 chaining sur CNI OCI | `oke-target-architecture.md:15,198` |
| Types de politique | `CiliumNetworkPolicy` default-deny par namespace | idem (mêmes CRD) ; CCNP de base en plus | `:191,16` |
| Admission | Kyverno (existant) + PSA + VAP | PSA `restricted` + VAP seulement (pas de Kyverno : 384 Mi, webhook `Fail`) | `:42,190,235` |
| Gateway/ingress | Gateway API Cilium `internal` + `external` | **pas de LB** (quota 0 + VAP) ; Cloudflare Tunnel sortant seul | `oracle-a1.md:23,25` ; `oke-target-architecture.md:198` |
| Edge public | wildcard tunnel vers Gateway `external` | tunnel `oracle-a1` dédié (config distante) | `invariants.md:78` ; `terraform/cloudflare/oracle-a1.tf:17-62` |
| Stockage | Longhorn | `oci-bv` (volumes 50 Go min, quota 200 Go) | `oke-target-architecture.md:198` ; `oke-migration-plan.md:20` |
| IMDS | sans objet (Proxmox) | à bloquer (CCNP) ; instance principal du worker (CSI/CCM) | `oke-target-architecture.md:123,161` |
| Workload Identity | n/a | **absente** (Basic) : aucun credential OCI dans les pods | `:39,161` |
| GitOps | Argo CD local pull | Argo CD local pull ; aucune route homelab vers OKE | `decisions.md:456-467` ; `oracle-a1.md:22,24` |
| Accès admin | kubeconfig Doppler / NetBird | API privée : Bastion OCI (actuel), NetBird (à rétablir) | `oke-target-architecture.md:17` |
| Disponibilité | éteint la nuit (aujourd'hui « 24 h/24 » depuis D-16-07) | 1 nœud, aucun SLA, suspension possible | `decisions-active.md:62` ; `oke-migration-plan.md:22` |

Flux : **homelab → Oracle uniquement**, Oracle n'a aucune route vers le LAN : `oracle-a1.md:24` ; `decisions.md:225-254`.

---

## 2. Inventaire OpenTofu (20 roots, un state chacun)

Source machine : `docs/architecture/arc-iac-roots.json` ; synthèse : `arc-iac-root-inventory.md:3-57`. State : bucket OCI partagé (5 roots à bucket dédié : `aiostreams`, `atlantis-pilot`, `github`, `mastrafactory`, `polyfin`) : `:36-39`. Copie hors Oracle vers R2 (`homelab-backup-tfstate`) en cours, états `cloudflare`, `cloudflare-r2`, `netbird`, `doppler` exclus au 17/11 : `oke-target-architecture.md:57,183`.

| Root (`terraform/…`) | Fournisseurs | Gère (mécanisme) | Statut ARC |
|---|---|---|---|
| `oracle-a1` | oci | cluster OKE, node pool A1, sous-réseau pods, NSG, quotas | apply_candidate |
| `oracle-cloud` (modules admin, monitoring, network, object-storage) | oci, doppler, null | VCN, Bastion, budget, IAM racine, buckets de state ; 21 `prevent_destroy` | plan_qualified (jamais apply) |
| `cloudflare` (modules dns, tunnel, access, security, waf, rate-limit, email_routing, global_config…) | cloudflare, doppler | zone, wildcard tunnel, tunnels, DNS, Access (apps+policies), WAF, jetons API, D1/R2 partner | apply_candidate |
| `cloudflare-r2` | cloudflare | 5 buckets de backup (cnpg, velero, longhorn, restic, tfstate) + bucket locks | apply_candidate |
| `doppler` | doppler, random | projets/configs Doppler, jetons ESO, **secrets générés par app** | plan_pending |
| `grafana-cloud` | grafana, cloudflare, doppler, random, healthchecksio | stack Grafana, alertes, **jetons R2 par bucket (writer/reader)**, mot de passe restic | apply_candidate |
| `github` | integrations/github | dépôts, rulesets (kube-ops main) | apply_candidate |
| `netbird`, `migadu-lechaplais`, `stripe` | netbird, metio/migadu, stripe (+doppler) | accès opérateur, mail, webhooks Stripe | apply_candidate / plan_pending |
| `proxmox` (modules talos, agent_dev), `unifi`, `adguard` | bpg/proxmox, siderolabs/talos, badgerops/unifi, adguard | VM Talos, réseau physique, DNS LAN (adguard retiré) | apply_candidate / retired |
| `hetzner-object-storage` | minio | sortie Hetzner en cours (PLT-94) | apply_candidate |
| `aiostreams`, `polyfin`, `mastrafactory` | providers maison | configuration d'applications | apply_candidate / inventory_only |
| `gcp-arc`, `google-cloud-build`, `atlantis-pilot` | google | WIF d'ARC, évidence ; pilote historique | apply_candidate / inventory_only / apply_qualified |

Application : **tout plan/apply passe par ARC** sur `main` (workflows `arc-iac-*`, `scripts/arc-apply-dispatch.sh`), aucun apply local sauf bris de glace = escalade : `decisions.md:420-427`. Un groupe de concurrence par state : `decisions-active.md:35`. Chaque root porte une liste `apply_allowed_changes` (ex. `cloudflare-r2` : create/update admis, delete/replace refusés) : `arc-iac-root-inventory.md:53` ; `terraform/cloudflare-r2/main.tf:8-10`. Accès Doppler unique pour les roots : `decisions.md:429-436`. Plan de PR (branches `claude/`, `codex/`) évalue le HCL de l'agent avec les jetons de plan : exposition connue : `agent-identities.md:8`. Sorties de plan/state jamais publiées : `arc-iac-root-inventory.md:11-28`.

---

## 3. Candidats Crossplane

Principe : par application, déclaré à côté de l'app, réversible par `git revert` => Crossplane ; socle => Tofu. Contrainte : `INV-TF-01` (Tofu ne doit pas être second réconciliateur de K8s) et `INV-STATE-02` (un objet = un seul état) : `invariants.md:16,20` ; une migration Tofu→Crossplane exige `removed {}`/import coordonné (`INV-STATE-04`, `:24`).

| Ressource | Aujourd'hui | Verdict | Raison |
|---|---|---|---|
| Bucket de backup par app/DB | 5 buckets partagés par domaine de risque, `cloudflare-r2/main.tf:15-30` ; jetons R2 limités au bucket (pas au préfixe) | **Passer en Crossplane** (nouveaux, par app) ; les 5 existants **garder Tofu** | « Un bucket par risque » est la règle (`decisions.md:998-1033`, writer R2 partagé). Bucket par app = isolation réelle. Mais bucket + jeton R2 = deux providers (S3 + token Cloudflare) |
| Jeton R2 (writer/reader) | minté par `grafana-cloud/r2-identities.tf:1-30`, secret dans le state protégé | **Hors cluster / Tofu** tant que le jeton racine « token factory » est requis | Un controller détenant un droit « API Tokens Write » = élévation ; D-14-05 isole ce droit |
| Client OIDC Authentik | blueprint kube-ops ; secret généré par Tofu (`generated-app-secrets.tf:135-200`) | **Passer en Crossplane** ou, plus simple, **blueprint généré** par OpenChoreo | Par app, sans IaC externe. Authentik = classe identité (MANDAT pour la protection) |
| Enregistrement DNS public | wildcard déjà là (`invariants.md:78`) ; DNS par app seulement pour hôtes hors wildcard (`terraform/cloudflare/oracle-a1.tf:62,154`) | **Hors besoin** par défaut ; sinon Crossplane (provider Cloudflare) | Le wildcard rend le DNS par app inutile pour K8s |
| Cloudflare Access (app + policy) | par app dans `cloudflare/oracle-a1.tf:117-154,191-246`, interrupteurs `enable_*` | **Passer en Crossplane** (candidat n°1) | Nouvelle exposition publique = MANDAT (`decisions.md:894-956`) : la PR porte le mandat |
| Secret Doppler par app | `doppler/generated-app-secrets.tf:36-80` (liste centrale, `random_password`) | **Passer en Crossplane** *ou* générer dans le cluster (ESO `Password` generator) [S] | Un secret généré n'a pas besoin de Doppler ; élimine le goulot de la root `doppler` (`plan_pending`, PLT-299) |
| Tunnel Cloudflare / ingress | `cloudflare/oracle-a1.tf:17-62` | **Garder Tofu** | Socle (INV-EDGE-01) |
| Cluster OKE, VCN, NSG, quotas, Bastion, IAM | `oracle-a1`, `oracle-cloud` | **Garder Tofu** | Socle ; ne peut pas dépendre du cluster (`INV-REC-01`, `invariants.md:36`) |
| Comptes (Doppler projets/jetons ESO, GitHub, Migadu, Stripe, NetBird) | roots dédiées | **Garder Tofu** | Racines de confiance, hors cluster |
| State, Proxmox, UniFi, Talos | roots | **Hors cluster** | Cluster dépendant de ce qu'il gère = circulaire |

### 3.1 Providers Crossplane [S] sauf mention
Accès web partiel : GitHub et marketplace bloqués par le proxy ; une seule recherche web.
- **Cloudflare** : providers upjet communautaires existent (prolixalias, cloudhippie), non vérifiés (maintenance, couverture de `zero_trust_access_*` v5, R2, D1) : https://pkg.go.dev/github.com/prolixalias/provider-cloudflare
- **Authentik** : providers upjet communautaires (hops-ops, vhdirk, publié `xpkg.upbound.io/vhdirk/provider-authentik`) : https://github.com/vhdirk/crossplane-provider-authentik ; maturité inconnue.
- **Doppler** : aucun trouvé [S]. Repli : `provider-terraform` ou `provider-http`, ou ESO `PushSecret`/generator.
- **OCI** : provider upjet Oracle probable [S], non vérifié. Inutile pour le socle.
- **R2/S3** : provider S3 (AWS upjet ou `provider-minio`) avec endpoint R2 [S] ; les bucket locks R2 n'ont pas d'équivalent S3 connu [S].
- Risque transversal : la plupart sont des ports upjet du provider Tofu (même couverture, même lag de version) ; ils ajoutent un contrôleur par fournisseur. Vérifier chaque lien avant l'ADR.

### 3.2 Coût en ressources
Allocatable du nœud : **1830m / 8,4 GiB**, requests 46 %/45 % avant reconstruction (`oke-target-architecture.md:48`). Budget retenu : ~1025m (56 %) / 3554 Mi (41 %), 19 IP ; 76 % CPU avec Backstage + pg-shared : `:172`. Seuil réel : requests ≤ 70 % de l'allocatable (`decisions.md:527-534`). Marge CPU actuelle ≈ 14 points (~260m) avant le seuil, et OpenChoreo n'est pas encore compté. Crossplane core + 1 provider = au moins 2 pods (donc 2 IP sur 31) ; chaque provider = 1 pod supplémentaire, ordre de grandeur 50-150m / 100-300 Mi chacun [S, à mesurer]. Argo, ESO et Kyverno ont déjà été taillés pour tenir : `:173`. Conclusion : **au plus 1-2 providers sur OKE**, ou Crossplane sur le homelab seul (plus de marge) ; il ne pourrait alors piloter que les ressources externes (API fournisseurs), pas OKE, faute de route homelab→OKE.

---

## 4. Décisions pertinentes (`docs/decisions.md`)

| Décision | Ce que ça impose à la plateforme |
|---|---|
| D-2026-11-15-03 (`:480`), D-2026-11-16-07 (`:894`) autonomie | Agents font PR, merge, déploiement, apply sans accord ; merge si CI verte + **retour arrière réel** (`git revert` sans perte de données). Reste Paul : MFA, achat, consentement, perte irréversible. Toute PR portant un MANDAT ou amendant l'autonomie : Paul seul. Interdits : `--admin`, check requis désactivé, TLS off, apply local |
| D-2026-11-11-05 (`:57`) sauvegarde | Classer les données (irremplaçable/utile/reconstructible). Aucun mécanisme retiré avant preuve du successeur. Un « PASS » exige restauration prouvée |
| D-2026-11-11-17 (`:225`) hybride | Un Argo par cluster, pull ; flux homelab→OKE seul ; OKE reconstructible depuis Git + sauvegardes hors Oracle ; exposition par Tunnel seul ; 1 hébergement actif par service ; images arm64 vérifiées ; pas de conso artificielle |
| D-2026-11-15-11/14 (`:575`,`:619`) OKE prioritaire | Authentik, Polyfin, AIOStreams sur OKE ; bascules sans fenêtre mais : rien en parallèle d'un apply, répétition prouvée, retour arrière écrit, Authentik/Matrix protégés |
| D-2026-11-16-09 (`:998`) Postgres | Base par app dans `pg-shared-homelab` par défaut ; dédié sur critère chiffré (identité/IRREPLACEABLE, RPO<5 min, >10 Go…). Admission automatisée (REVOKE CONNECT, test de refus inter-apps) **à construire** ; RPO/RTO « non prouvé » avant drill ; writer R2 partagé = risque exposé. `pg-shared` reste le nom côté OKE |
| D-2026-11-15-01 (`:456`) deux Argo | Chemin agent unique : branche, `just check`, PR, merge, `just verify-delivery <cluster> <app>` ; choix du cluster = choix du dossier ; aucune UI Argo ; vérification lit Grafana Cloud (niveau RUNTIME) |
| D-2026-11-15-15 (`:632`) mandats | Un accord relayé ne vaut rien ; l'autorisation durable est une entrée `MANDAT` mergée avant (source citée, périmètre fermé, exclusions, expiration, preuve) ; exige un gabarit de mandat dans la plateforme |
| D-2026-11-15-05 (`:527`) budget 70 % | Somme des requests ≤ 70 % de l'allocatable, pas de baisse sous le p95 ; ntfy/Gatus hors OKE (l'alerte vit hors des deux sites) |
| D-2026-11-14-04 (`:420`) ARC | Tout OpenTofu par ARC ; nouveau root = inventaire + profil d'auth + `apply_allowed_changes` ; Crossplane sur ARC n'a pas d'équivalent : à décider |
| D-2026-11-14-05 (`:429`), D-2026-11-15-10 (`:566`) secrets | Un accès Doppler unique pour les roots ; lecture d'un secret racine interdite ; secrets irrégénérables protégés (`prevent_destroy`, restic) |
| D-2026-11-14-03 (`:410`) mémoire | Rien de persistant sur OKE sans restauration prouvée hors Oracle ; hostname public = exposition protégée (jamais anonyme) |
| D-2026-11-15-12 (`:601`) Home Assistant | Jamais exposé par Tunnel ; accès distant NetBird (classe d'exposition « jamais public ») |
| D-2026-11-16-09/16-07 cap | Budget plateforme < 20 €/mois, RTO ≤ 30 min, RPO base ≤ 5 min (non prouvé), fichiers ≤ 24 h ; vraie donnée : Vikunja seule |
| INV-HYG-01 (`invariants.md:58`) | Interfaces upstream et schémas natifs ; pas de DSL maison : à confronter au contrat `app.yaml` |
| INV-SEC-02, INV-REC-01 (`:32,36`) | Aucune valeur secrète dans Git/logs/plans ; reconstruction du cluster impossible à dépendre de lui seul |

### 4.1 Gabarit d'une entrée (`docs/decisions.md`, validé par `scripts/check-decisions.py:26-39`)

```
## D-AAAA-MM-JJ-NN — Titre court — STATUT [· AMENDÉE PAR D-…, D-…]

Paul a décidé le JJ/MM/AAAA (chat, ticket PLT-nnn) : « citation exacte ». [Contexte et décisions amendées/remplacées.]

### Règles | Cible | Conditions (sections libres, listes à puces **gras** pour les termes clés)
- **Terme** : règle opposable, courte. Référence aux autres D-… par identifiant.

### Amendement                      (si elle modifie une décision antérieure)
Amende D-… : ce qui change ; le reste est inchangé.

### Ce que la décision ne fait pas  (périmètre exclu)

### MANDAT n — Titre — EN ATTENTE | EXÉCUTÉ   (si irréversible ; décisions.md:632-660)
- **Source** : « citation exacte », canal, date/heure UTC, session.
- **Périmètre** : liste fermée de noms (jamais de valeur), verbes précis.
- **Exclusions** : ce qui reste interdit.
- **Expiration** : date ou condition.
- **Conditions d'arrêt** (optionnel) · **Preuve attendue** : contenu du `mission-result.v1`.
```
Statuts de base : ACTÉE, HYPOTHÈSE, PROPOSÉE, ACTÉE / HYPOTHÈSE ; suffixes `REMPLACÉE PAR D-…` ou `· AMENDÉE PAR D-…` (`check-decisions.py:27-29`). Une décision n'est jamais réécrite : une nouvelle l'amende (`decisions.md:6`). Le résumé `docs/decisions-active.md` (≤ 1200 mots) doit citer la nouvelle D-… sinon le contrôle échoue (`check-decisions.py:77-78`).

---

## 5. Identité et secrets à reprendre

**Identité** (`identity-layer.md`, `agent-identities.md`) : Authentik OSS est l'unique IdP (`identity-layer.md:8`) ; groupes `authentik-admins`, `family`, `friends` (`agent-identities.md:23`) ; OIDC natif par défaut, outpost proxy seulement sans OIDC ; Authentik ne passe jamais derrière Cloudflare Access (pas de circularité : `oke-target-architecture.md:62,119`). Une identité logique par agent, un credential par surface et par exécutant (`agent-identities.md:6`) ; agents sans droit d'écriture d'infra : ils lisent, ouvrent des PR, déclenchent ARC (`:8`). Jetons courts (GitHub App 1 h, TokenRequest K8s, `client_credentials` Authentik), rotation 90 j, coupe-circuit, audit dans `mission-result.v1` (`:25-29`). Exclus : Authentik Enterprise (comptes d'agent, PAM), Doppler Team, SPIFFE, Vault (`:30`). Sous-agents famille : jeton de l'utilisateur, restreint par groupe ; jamais les droits techniques (`:10`). Statut : documents PROPOSÉS, partiellement appliqués.

**Secrets** (`secret-store-decision.md`, `docs/secrets.md`) : **garder Doppler gratuit**, consolider 46 → ~19 jetons (`secret-store-decision.md:9`) ; pas d'OpenBao (pas d'hébergement sain : homelab éteint la nuit, OKE sans SLA, `:12`) ; déclencheurs T1-T6 (`:91-100`) vers Doppler Team puis GCP Secret Manager. ESO : un `ClusterSecretStore doppler-cluster` unique aujourd'hui, cible un SecretStore et un jeton par namespace/domaine sur OKE (`oke-target-architecture.md:149,192`). Plafond : 10 projets Doppler, 8 utilisés (`secret-store-decision.md:21`). Contrat : pas de `.tfvars` de secrets ni de `doppler secrets download` (`docs/secrets.md:10`) ; Doppler doit rester récupérable hors Kubernetes (`:12`). Écarts : le jeton ESO d'OKE lit probablement tout `cluster/prd` (`oke-target-architecture.md:55`) ; 143 `doppler_secret` dans 8 roots (`secret-store-decision.md:24`).

---

## 6. Conclusion

### 6.1 Huit contraintes structurantes
1. **Une seule voie d'écriture durable** : PR vers Git, CI verte, merge ; jamais d'écriture directe dans le cluster ; retour arrière réel = `git revert` (D-15-03, D-16-07).
2. **Irréversible = MANDAT sur `main` avant l'action** : données, secrets, nouvelle exposition publique ; PR de mandat mergée par Paul seul (D-15-15).
3. **Budget nœud OKE** : 1830m/8,4 GiB, requests ≤ 70 %, 31 IP de pods, 200 Go bloc ; OpenChoreo + Crossplane doivent y tenir ou rester au homelab.
4. **Pas de LB, pas d'IP publique, pas de Workload Identity sur OKE** : exposition par Tunnel, aucun credential OCI dans les pods, IMDS refusé par CCNP.
5. **Flux homelab → OKE uniquement**, un Argo local par cluster ; la plateforme ne peut pas dépendre d'un plan de contrôle central joignable des deux côtés.
6. **Tout état persistant sur OKE exige une restauration prouvée hors Oracle** (R2) ; RPO/RTO déclarés « non prouvé » jusqu'au drill (D-14-03, D-16-09).
7. **Tofu via ARC seulement, un state = un propriétaire** ; le socle ne dépend pas du cluster (`INV-REC-01`, `INV-STATE-02`) ; migration d'un objet Tofu→Crossplane = transition d'état unique et revue.
8. **Secrets : Doppler + ESO, aucune valeur dans Git/PR/logs** ; garde-fous admission natifs (PSA restricted + VAP + CNP default-deny), pas de contournement pour faire passer un test ; k3d ≠ OKE.

### 6.2 Cinq simplifications possibles
1. **Crossplane limité aux seules ressources par app** (Access, bucket par app, éventuellement DNS hors wildcard), socle intact en Tofu ; ou **aucun Crossplane** si le coût d'un contrôleur par fournisseur dépasse le gain : la plupart des ressources par app disparaissent déjà avec le wildcard et les générateurs.
2. **Supprimer le DNS par app** : le wildcard `*.smadja.dev` (INV-EDGE-01) suffit pour toutes les apps Kubernetes.
3. **Générer les secrets applicatifs dans le cluster** (générateur ESO) au lieu de `random_password` + `doppler_secret` centralisés : retire le goulot de la root `doppler` et ses 143 ressources ; Doppler garde les seuls secrets externes.
4. **Clients OIDC par blueprint généré** depuis `app.yaml` (kube-ops en a déjà 43) plutôt qu'un provider Authentik de plus.
5. **Une Postgres partagée par cluster** + un bucket R2 par classe de risque (déjà acquis) ; l'app ne déclare qu'une classe (stateless / DB / PVC) et un niveau d'exposition (interne / famille / public avec MANDAT).
