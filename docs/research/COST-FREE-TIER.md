# Coût global : rester dans le free tier (FinOps)

Date : 2026-11-18 · Domaine : coût · Statut : recherche (rien n'est appliqué, aucun cluster touché).

**Conclusion** : le coût marginal de la plateforme peut rester à **0 €/mois d'infrastructure**. Le seul poste à
risque réel est le **LLM** (hors périmètre infra). Les quotas gratuits *cloud* ne sont pas la contrainte : le nœud OKE
(CPU/IP/volumes) l'est déjà. Trois dépassements silencieux sont à surveiller : volumes OCI orphelins, opérations/volume
R2 (WAL + verrous de rétention), séries actives Grafana. Les garde-fous existent déjà en partie dans homelab-infra.

## 0. Ce que j'ai pu lire

- **Lu dans les dépôts** : ADR 0002/0003/0009/0014, T-009, T-004, TARGET-ARCHITECTURE §6, HOMELAB-INFRA-REQUIREMENTS,
  homelab-infra (`terraform/oracle-cloud/modules/admin/budget.tf`, `terraform/oracle-a1/main.tf` quotas,
  `terraform/grafana-cloud/{budget,usage}-rules.tf`, `docs/state/billing.md`, `docs/architecture/{oracle-a1,secret-store-decision}.md`).
- **Web : vérifié le 2026-11-18** (docs.oracle.com, developers.cloudflare.com, grafana.com, docs.github.com, docs.ntfy.sh,
  cloud.google.com, doppler.com, healthchecks.io, lus via `curl`). **[V AAAA-MM-JJ + URL]** = confirmé en ligne ;
  **[E]** restant = non revérifié. Le résultat est consigné dans `VERIFICATION-2026-11-18.md`. Graver un seuil en CI
  (ticket COST-1) sur les valeurs [V]. **[R]** = lue dans un dépôt, **[M]** = mesurée par le dépôt.

## 1. Inventaire et limites gratuites

| Service | Limite gratuite | Date / source | Usage ici | Marge |
|---|---|---|---|---|
| OCI Always Free A1 | **CORRIGÉ** : 1 500 OCPU-heures et 9 000 Go-heures par mois pour tous les tenancies (y compris PAYG), soit **2 OCPU / 12 Go** en continu ; la valeur 4/24 (3 000 / 18 000) est **obsolète** [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm] ; le dépôt avait raison [R] | 2026-11-18 [V] ; 2026-11-14 [R] `oracle-a1.md` | 1 nœud 2/12, fixé par quota compartiment | 0 : 2/12 est le plafond réel, pas seulement prudent ; aucun nœud de surge possible |
| OCI Block Volume | 200 Go total boot+bloc, 5 sauvegardes de volume, dans la région d'origine [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm] ; minimum de boot 50 Go (la page écrit aussi 47 Go à un endroit) [V] ; [R] OKE-AUDIT | [V] | 150 Go pris (boot 50 + 2 volumes de drill) [M] | 50 Go = **1 volume** |
| OCI Load Balancer | 1 LB flexible 10 Mbps (tenancies créés depuis le 2020-12-15) + 1 LB réseau [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm] | [V] | **0 voulu** : quota LB = 0 + VAP kube-ops [R] | n/a (interdit) |
| OCI egress | 10 To/mois sortants [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm] | [V] | négligeable (tunnel sortant, peu d'apps) | large |
| OCI OKE | plan de contrôle *Basic* gratuit ; *Enhanced* payant [E : la page de présentation OKE lue ne chiffre pas le tarif ; la doc dit seulement que le nombre de clusters *basic* n'est pas augmentable : https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm] | [E] | Basic [R] | n/a |
| OCI Object Storage / Vault / Notifications | Object Storage : 20 Go (état Always Free seul) ou 10 + 10 + 10 Go Standard/Accès peu fréquent/Archive (compte payant ou essai), **50 000 requêtes API/mois** ; Vault : clés logicielles gratuites, 20 versions de clé HSM, 150 secrets, 40 versions par secret ; Notifications : **1 M notifications HTTPS + 1 000 e-mails par mois** [V 2026-11-18 + https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm] | [V] | state OpenTofu [R] ; Vault = option auto-unseal OpenBao (ADR-0014) | à mesurer |
| OCI IP publique réservée | gratuite si attachée [E : non retrouvée sur la page Always Free] | [E] | aucune voulue | piège : IP orpheline |
| Cloudflare Tunnel | gratuit ; limites de compte : 1 000 tunnels `cloudflared` par compte, 25 réplicas actifs par tunnel, applications publiées limitées par 1 Mo de configuration, aucune limite de débit publiée [V 2026-11-18 + https://developers.cloudflare.com/cloudflare-one/account-limits/ ; la gratuité du Tunnel lui-même n'est pas rappelée sur cette page : [E]] | [V] | 1 tunnel `oracle-a1` + homelab | large |
| Cloudflare Zero Trust (Access) | plan Free : « teams under 50 users » à 0 $, puis 7 $/utilisateur/mois [V 2026-11-18 par recoupement : page de plans Cloudflare citée par la recherche web, https://www.cloudflare.com/plans/zero-trust-services/ non extractible] ; **50 service tokens** et **50 applications personnalisées** par compte, 500 applications Access [V 2026-11-18 + https://developers.cloudflare.com/cloudflare-one/account-limits/] ; en-têtes `CF-Access-Client-Id` / `CF-Access-Client-Secret`, **ou un seul en-tête** au choix (`read_service_tokens_from_header`, ex. `Authorization` avec un JSON `{"cf-access-client-id":…,"cf-access-client-secret":…}`), durée du jeton configurable (ex. 8760 h), rotation avec délai de grâce [V 2026-11-18 + https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/] | [V] ; plan « à confirmer » [R] billing.md | famille/amis | 50 comptes |
| Cloudflare R2 | **10 Go-mois**, 1 M opérations classe A, 10 M classe B /mois, egress gratuit ; le palier gratuit ne s'applique qu'au stockage *Standard* ; DeleteObject/DeleteBucket/AbortMultipartUpload gratuits [V 2026-11-18 + https://developers.cloudflare.com/r2/pricing/] | [V] | 5 buckets de backup + tfstate [R] ; WAL CNPG, restic | **faible, non mesurée** |
| Cloudflare Workers | 100 000 requêtes/jour [V 2026-11-18 + https://developers.cloudflare.com/workers/platform/pricing/] | [V] | non utilisé ici (billing.md : « à lire console ») | n/a |
| Grafana Cloud Free | **10 000 séries actives** (95e centile mensuel), 50 Go logs, 50 Go traces, 14 j de rétention (métriques, logs, traces, profils), 3 utilisateurs actifs, 500 règles d'alerte gérées, Synthetic Monitoring 100 000 API + 10 000 navigateur /mois [V 2026-11-18 + https://grafana.com/pricing/] ; nouveaux stacks depuis le 2026-04-20 : pas d'alertes par e-mail ni de Cloud Alertmanager, webhooks OK [V + https://status.grafana.com/incidents/xg2h8ht1d44n] | 2026-11-15 [M] : 2 786 séries, 1 utilisateur | Alloy OKE + homelab | ~72 % libre |
| GitHub Actions | dépôt **public** : runners standard gratuits et illimités, dont `ubuntu-24.04-arm` (4 vCPU / 16 Go arm64) ; privé : **12 $ de calcul inclus par mois** au plan Free (≈ 2 000 min Linux x64 à 0,006 $/min ou 2 400 min arm64 à 0,005 $/min), plus 500 Mo d'artefacts et 10 Go de cache ; **concurrence : 20 jobs simultanés** au plan Free, 500 runs mis en file / 10 s, file de concurrence de 100 runs ; `GITHUB_TOKEN` : 1 000 requêtes API/h/dépôt ; les runners plus gros sont facturés même en public [V 2026-11-18 + https://docs.github.com/en/actions/reference/runners/github-hosted-runners , https://docs.github.com/en/billing/concepts/product-billing/github-actions , https://docs.github.com/en/actions/reference/limits] | [V] ; dépôt public [R] `claude-agent.yml` l.6 | CI + agent sur arm64 | illimité tant que public |
| GitHub stockage | artefacts Actions 500 Mo (Free) ; GitHub Packages gratuit pour les paquets publics ; stockage et bande passante du Container registry actuellement gratuits [V 2026-11-18 + https://docs.github.com/en/billing/concepts/product-billing/github-packages] | [V] | images GHCR publiques | surveiller si privé |
| Doppler Developer | gratuit pour 3 utilisateurs, 10 projets, 4 environnements, 10 configs/env, **50 jetons de service**, **3 jours** de journal d'activité [V 2026-11-18 + https://www.doppler.com/pricing] ; [R] | 2026-11-15 [R] secret-store-decision | 8-10 projets sur 10 ; Team = 21 USD/mois [R] | 0-2 projets |
| ntfy | ntfy.sh gratuit : **250 messages/jour**, rafale de 60 requêtes puis 1 requête / 5 s, message de 4 096 octets, pièce jointe 2 Mo (20 Mo par visiteur), bande passante 200 Mo/jour, 30 connexions ouvertes ; auto-hébergé : 0 [V 2026-11-18 + https://docs.ntfy.sh/publish/#limitations] | [V] ; ntfy reste au homelab [R] | alertes critiques | large |
| Google Cloud Run | 2 M requêtes, 180 000 vCPU-s, 360 000 Gio-s /mois (tarif us-central1, agrégé par compte de facturation) [V 2026-11-18 + https://cloud.google.com/run/pricing] ; **compte de facturation requis, pas de plafond dur** [E] | [V] ; budget 1 €/mois [R] | sonde sécurité `workflow_dispatch` | à garder < 1 € |
| Healthchecks.io | Hobbyist gratuit, 20 jobs [V 2026-11-18 + https://healthchecks.io/pricing/] | billing.md « à confirmer » | dead man's switch | à confirmer |
| LLM (Claude Code) | abonnement forfaitaire ou API au token ; **pas de free tier** | [R] `claude-agent.yml` : jeton OAuth d'abonnement | agents parallèles | **le vrai risque** |

Hors free tier mais déjà payés et hors scope : Migadu, domaines, Hetzner (Object Storage/Storage Box), électricité,
Minimax (LLM de production d'Hindsight). Ils pèsent dans le budget de 20 € de homelab-infra [R], pas ici.

## 2. Ce qui fait sortir du gratuit, et l'alarme avant

| Risque | Mécanisme | Alarme avant | Statut |
|---|---|---|---|
| Volume OCI > 200 Go ou orphelin | un PVC `oci-bv` = 50 Go min. ; `Retain` laisse le volume après suppression du PVC ; volumes de drill laissés | quota compartiment `block-storage 200` [R] (refus dur) ; CI : refuser tout `storage`/PVC sur OKE ; contrôle périodique des volumes sans PVC (T-009) | quota OK ; contrôle orphelins absent |
| LB / IP publique OCI | `Service type: LoadBalancer`, IP réservée détachée | quota LB = 0 [R] ; VAP kube-ops ; à porter dans les VAP de ce dépôt | quota OK ; VAP à vérifier |
| Région hors `eu-paris-1` | création de compute/volume ailleurs | quotas zéro hors région [R] | OK |
| Facturation OCI (PAYG) | tout cent hors Always Free | budget `homelab-zero-usd-strict` 0,01 USD réel **et** prévision, e-mail [R] | en place (alerte, pas de coupure) |
| R2 > 10 Go ou > 1 M classe A | rétention + verrous de bucket, versions, WAL CNPG (un objet par segment 16 Mo + `.history`), restic petits fichiers | **aucune** : pas d'API de facture [R] | **trou principal** : mesurer (COST-4) |
| Grafana séries/logs/traces | cardinalité d'une app (labels), logs verbeux | règles `usage` à 80 % séries + dépassement logs/traces [R] ; coupe l'ingestion, ne facture pas | en place (homelab-infra) |
| Actions si le dépôt devient privé | 12 $ de calcul inclus/mois (≈ 2 000 min x64, 2 400 min arm64), runners arm64 payants au-delà [V 2026-11-18 + https://docs.github.com/en/billing/concepts/product-billing/github-actions] | contrôle « dépôt public » en CI ; compteur de minutes | à créer (COST-5) |
| Doppler 10 projets | nouveau domaine de secrets | liste fermée de projets (ADR-0014 : Doppler = primitives seulement) | OK si ADR-0014 tenu |
| Cloud Run | pas de plafond dur | budget GCP 1 € + règles 0,80/1 € [R] ; désactiver le service plutôt que le plafonner | en place côté alertes |
| LLM | agents en parallèle × tokens ; jeton OAuth partagé | plafond de concurrence + `--max-turns` + minutes de job ; suivi par jeton (§5) | **partiel** : `--max-turns 60`, `timeout-minutes 45`, `concurrency` [R] |

## 3. Budget mensuel cible

| Périmètre | Cible | Plafond d'alerte |
|---|---|---|
| Infrastructure cloud (OCI, Cloudflare, Grafana, GitHub, Doppler, ntfy) | **0 €** | tout cent = incident (budget OCI 0,01 USD déjà en place) |
| Sonde Cloud Run | ≤ 1 € | 0,80 € warning, 1 € critique [R] |
| Plateforme + LLM de production (budget global de homelab-infra) | < 20 € [R] D-2026-11-16-07 | 16 € prévu / 20 € réel [R] |
| LLM de développement (abonnement Claude, agents) | **forfait fixe, hors 20 €** (décision Paul 16/11 [R]) | plafond de concurrence ; aucune API au token sans MANDAT |

La proposition : **ce dépôt s'engage sur 0 € d'infra additionnelle** et n'ajoute aucun fournisseur payant ; le budget de
20 € reste celui de homelab-infra. Toute dépense > 0 = MANDAT (ADR-0002 §3 : « un coût hors Always Free »).

## 4. Garde-fous exécutables (du plus rentable au moins)

1. **CI `appgen` : refuser** tout `storage` ou base sur `cluster: oke`, tout `expose` impliquant LB, plus de volumes que
   `clusters/oke/capabilities.yaml` n'en déclare (`freeTier: {blockGB: 50, lb: 0}`), tout `Service type: LoadBalancer`
   et tout PVC rendu dans `generated/`. Complète T-004 (frugalité dev).
2. **Quotas OCI** (déjà en OpenTofu côté homelab-infra) : miroir lu en lecture seule par `tools/oke/` ; le test échoue si
   le quota réel dépasse 2/12/200/LB 0.
3. **Contrôle périodique OCI** (T-009) : volumes sans PVC, IP réservées détachées, boot > 50 Go, backups > 5 ; sortie
   JSON `cost-evidence.v1` datée. Lecture seule, clé OCI dédiée en lecture (MANDAT une fois).
4. **Compteur de minutes CI** : `gh api /repos/.../actions/runs` agrégé par semaine (durée × multiplicateur) ; alerte si
   dépôt privé détecté (`visibility != public`) ou > 70 % de 2 000 min. Aujourd'hui illimité car public.
5. **R2** : job quotidien `rclone size`/liste par bucket (comptage d'objets, Go) avec la clé *reader* existante ;
   alerte à 7 Go et à 70 % des opérations estimées ; bucket `lifecycle` (expiration WAL > 14 j, versions non courantes).
6. **Grafana** : règles `usage` existantes ; ajouter un **budget de séries par app** (allowlist Alloy, `sample_limit`
   par scrape) pour qu'une app ne consomme pas à elle seule le quota.
7. **LLM** : (a) plafond de concurrence des agents (`concurrency` par groupe, N=2 sessions simultanées) ; (b) `--max-turns`,
   `timeout-minutes` (existants) ; (c) pas de clé API au token dans le dépôt : si une clé API est un jour nécessaire,
   **plafond de dépense mensuel côté console fournisseur** + clé dédiée (MANDAT) ; (d) comptage des tokens, §5.
8. **Cloud Run** : sonde désactivée par défaut, `workflow_dispatch`, jamais plus d'une instance ; alertes 0,80/1 €.
9. **Registre** `docs/state/billing.md` (homelab-infra) : la source des montants ; ce dépôt y renvoie, il ne le duplique pas.

## 5. FinOps Agent / OpenCost et mesure par app / par agent

- **OpenCost (module communautaire, OpenChoreo « cost insights » + FinOps Agent)** [R] `mcp-ai-agents.md`, `observability.md` :
  **trop lourd à activer sur OKE** et peu utile : il dépend de l'observability plane (OpenSearch, collecteur « pèsent lourd
  sur un petit cluster » [R]), de Prometheus, et d'un prix par ressource. Or la plateforme ne facture rien : le coût
  euro est déjà 0 et les requests sont bornées par quota de cellule. Le FinOps Agent est une recommandation de
  dimensionnement exigeant une clé LLM : un coût pour économiser 0 €. **Verdict : ne pas déployer** ; ré-évaluer seulement
  si le homelab reçoit un observability plane (marge CPU : ~260m avant 70 % sur OKE, OpenChoreo non compté [R]).
- **Coût par app, sans OpenCost** : *requests* CPU/mémoire par cellule (label `app`) en sommant `kube_pod_container_resource_requests`
  déjà exporté vers Grafana Cloud (série budgétée), + volumes déclarés dans `app.yaml`. Résultat : une part du « budget nœud
  70 % », donc une **monnaie de CPU/Go**, pas d'euros. `appgen` sait déjà ce qu'une app réserve.
- **Coût par agent (tokens)** : le workflow d'agent utilise un jeton d'abonnement : pas de facture au token lisible [R billing.md].
  Mesure réaliste : par issue/PR, **durée de job, nombre de tours** (`--max-turns`), et tokens lus dans la sortie `result`
  de Claude Code si exposée (`usage`, `total_cost_usd` en mode API [NV : non revérifié, hors périmètre de la vérification du 2026-11-18]). Les consigner dans le compte-rendu de PR
  (`mission-result.v1`, T-043/T-068) et agréger hebdomadairement. Ne pas promettre d'euros par agent tant que l'abonnement est
  forfaitaire. Attribution par identité d'agent : T-068.

## 6. Risques de dépassement classés

1. **LLM / parallélisme d'agents** (probabilité haute, impact élevé hors forfait : limites de débit de l'abonnement et
   facture si bascule en API).
2. **R2** : opérations et Go non mesurés ; verrous de rétention + WAL peuvent gonfler.
3. **Volumes OCI orphelins** (150/200 Go déjà pris ; un seul volume possible).
4. **Dépôt rendu privé** : perd minutes arm illimitées.
5. **Cloud Run** (pas de plafond dur) et **Doppler 10 projets** : faibles.

## 7. Proposition d'ADR

```markdown
# ADR-0015 — Coût : rester dans le free tier, garde-fous exécutables
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0004, ADR-0009, ADR-0014, D-2026-11-11-17, D-2026-11-16-07 (homelab-infra)

## Contexte
- Paul veut le coût global le plus faible possible et reste dans les free tiers. OKE : A1 2/12 fixé, 200 Go de bloc
  dont 150 pris, LB = 0 par quota. homelab-infra a déjà un budget OCI à 0,01 USD, des alertes Grafana d'usage et un
  budget de 20 €/mois ; ce dépôt n'a aucun garde-fou de coût propre (T-009 seulement estimatif).
- Le web n'était pas lisible (2026-11-18) : les limites du fournisseur sont à reconfirmer.

## Décision
1. **Coût d'infrastructure additionnel de la plateforme : 0 €.** Aucun fournisseur payant n'est ajouté sans MANDAT (ADR-0002 §3).
2. **Registre unique des limites** `docs/state/free-tier.yaml` (valeur, date, source URL, prochaine revue) ; une limite
   non revérifiée depuis 90 jours échoue le lint.
3. **Refus à la source** : `appgen` et la CI refusent tout ce qui sort du free tier d'après `capabilities.yaml`
   (volume sur OKE, LB, `type: LoadBalancer`, IP publique, hors région).
4. **Alarme avant, jamais seulement après** : chaque ressource limitée a un seuil de 70-80 % qui crée une issue et une
   alerte ntfy ; le budget OCI 0,01 USD reste la dernière ligne.
5. **LLM** : abonnement forfaitaire pour les agents ; plafond de concurrence et de tours ; aucune clé API au token sans
   MANDAT, plafond de dépense côté fournisseur ; consommation consignée par PR.
6. **Pas d'OpenCost ni de FinOps Agent** tant que l'observability plane n'est pas déployé pour d'autres raisons.
7. **Un agent ne relève jamais un plafond** (quota, budget, seuil) : c'est un MANDAT.

## Conséquences
- Un registre et ~3 contrôles périodiques en lecture seule ; une clé OCI de lecture à créer (MANDAT, une fois).
- Aucune dépense ; refus plus tôt des apps lourdes sur OKE (cohérent avec ADR-0003/0004).
- Coût agents mesuré en durée/tours, pas en euros.

## Alternatives écartées
- **OpenCost + FinOps Agent** : lourd sur OKE, pour un coût en euros nul.
- **Budgets en euros seulement** : alerte après coup ; OCI facture avant coupure.
- **Plafond dur par API** : OCI/GCP n'en offrent pas ; les quotas OCI sont le seul plafond dur disponible.

## Vérification
- Test CI : une `app.yaml` avec volume sur OKE ou `expose: lb` est refusée (un test par refus).
- Preuve runtime datée : sortie `cost-evidence.v1` (volumes, quotas, R2 Go/objets, séries, minutes CI) PASS/FAIL.
- Test de lint : le registre `free-tier.yaml` n'a aucune ligne périmée.

## Références
`docs/research/COST-FREE-TIER.md`, homelab-infra `docs/state/billing.md`, `terraform/oracle-a1/main.tf` (quotas).
```

## 8. À vérifier par Paul (une fois)

- Que le dépôt reste **public** (sinon minutes et arm64 changent).
- La limite A1 réelle : **2 OCPU / 12 Go confirmés** (1 500 OCPU-h + 9 000 Go-h/mois) [V 2026-11-18] ; le chiffre 4/24 est obsolète. Aucune montée possible.
- Le plan Zero Trust (Free), le plan Doppler, la facture Cloudflare/R2 : montants « à renseigner » dans `billing.md`.
