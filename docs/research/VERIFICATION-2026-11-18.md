# Vérification en ligne des faits [E]/[S]/[NV] (2026-11-18)

Méthode : lecture des sources primaires par `curl` (l'outil de lecture web refusait les hôtes, le shell non) ; extraction de texte ; aucun cluster touché, aucun secret, aucun identifiant de compte. Statuts : CONFIRMÉ (la source dit la même chose), CORRIGÉ (la source diffère : le document a été corrigé), INTROUVABLE (aucune source primaire lisible). Preuve = STATIC (documentation) ; aucune preuve runtime. Les documents corrigés portent `[V 2026-11-18 + URL]`.
Hors périmètre non traités : `CONSOLIDATION.md`, `HOMELAB-INFRA-REQUIREMENTS.md`, `KUBE-OPS-REQUIREMENTS.md`, `HOMELAB-CAPACITY-DATAPLANE.md`.

## Tableau fait, statut, source
| # | Fait | Statut | Source |
|---|---|---|---|
| 1 | Grafana Free : 10 000 séries actives | CORRIGÉ (facturées au 95e centile, pas « moyenne ») | grafana.com/pricing ; docs cost-management understand-your-invoice |
| 2 | Grafana Free : 50 Go logs, 50 Go traces, 14 j de rétention, 3 utilisateurs | CONFIRMÉ | grafana.com/pricing |
| 3 | Synthetic Monitoring ~100 000 exécutions/mois | CORRIGÉ (100 000 API + 10 000 navigateur) | grafana.com/pricing |
| 4 | Règles d'alerte gérées : plafond | CONFIRMÉ (500 au plan Free, 2 000 souple en payant) | docs create-grafana-managed-rule |
| 5 | Contact point webhook à charge personnalisée | CONFIRMÉ (Custom Payload, en-tête Authorization, HMAC) | docs webhook-notifier |
| 6 | Free sans carte : ingestion limitée, pas de facture | INTROUVABLE | aucune page lue ne le dit |
| 7 | Alertes sur un stack Free | CORRIGÉ (stacks ouverts depuis 2026-04-20 : pas d'e-mail ni de Cloud Alertmanager ; webhooks OK) | status.grafana.com/incidents/xg2h8ht1d44n |
| 8 | ntfy.sh : 250 msg/jour, rafale 60 puis 1/5 s, 4 096 o, pièce jointe 2 Mo | CONFIRMÉ | docs.ntfy.sh/publish |
| 9 | ntfy : topic = mot de passe, `[-_A-Za-z0-9]`, 64 car. max | CONFIRMÉ | docs.ntfy.sh/publish |
| 10 | Cloudflare Access gratuit jusqu'à 50 utilisateurs | CONFIRMÉ (source secondaire : page de plans citée par recherche web) | cloudflare.com/plans |
| 11 | Service tokens : en-têtes `CF-Access-Client-Id/Secret` ; 50 tokens/compte | CONFIRMÉ | developers.cloudflare.com account-limits, service-tokens |
| 12 | Option « un seul en-tête » (`read_service_tokens_from_header`) | CONFIRMÉ (valeur JSON dans l'en-tête choisi) | service-tokens |
| 13 | Tunnel : gratuit, 1 000 tunnels, 25 réplicas | CONFIRMÉ (limites) ; gratuité INTROUVABLE sur cette page | account-limits |
| 14 | R2 : 10 Go, 1 M classe A, 10 M classe B, egress gratuit | CONFIRMÉ (Standard seulement) | r2/pricing |
| 15 | Workers 100 000 req/jour | CONFIRMÉ | workers/platform/pricing |
| 16 | Runners `ubuntu-24.04-arm` gratuits en dépôt public | CONFIRMÉ (4 vCPU, 16 Go) | docs.github.com runners |
| 17 | Concurrence Actions Free | CONFIRMÉ (20 jobs simultanés, file de 100 runs) | actions/reference/limits |
| 18 | Un événement `GITHUB_TOKEN` ne déclenche pas de workflow | CORRIGÉ (sauf `workflow_dispatch`/`repository_dispatch` ; `pull_request` : runs « approbation requise ») | trigger-a-workflow |
| 19 | Dépôt privé : 2 000 min/mois | CORRIGÉ (12 $ de calcul inclus : ≈ 2 000 min x64, 2 400 min arm64) | billing github-actions |
| 20 | Limite API 5 000 req/h | CORRIGÉ (`GITHUB_TOKEN` : 1 000 req/h/dépôt) | actions/reference/limits |
| 21 | `workflow_dispatch` : Actions write ; `repository_dispatch` : Contents write | CONFIRMÉ | docs.github.com/rest |
| 22 | OCI A1 : 4 OCPU / 24 Go en PAYG | CORRIGÉ (1 500 OCPU-h + 9 000 Go-h/mois = 2/12) | docs.oracle.com Always Free |
| 23 | Block Volume 200 Go + 5 sauvegardes ; LB 10 Mbps + 1 NLB ; egress 10 To | CONFIRMÉ | docs.oracle.com Always Free |
| 24 | Object Storage 20 Go ; Vault 20 clés HSM, 150 secrets | CONFIRMÉ (+ 50 000 requêtes API/mois ; 10+10+10 Go en compte payant) | docs.oracle.com Always Free |
| 25 | Notifications 1 M | CORRIGÉ (1 M HTTPS + 1 000 e-mails) | docs.oracle.com Always Free |
| 26 | OKE Basic gratuit ; IP publique réservée gratuite si attachée | INTROUVABLE | pages lues muettes |
| 27 | Cloud Run 2 M req, 180 000 vCPU-s, 360 000 Gio-s ; Healthchecks 20 jobs | CONFIRMÉ | cloud.google.com/run/pricing ; healthchecks.io/pricing |
| 28 | OpenBao : seal `static` (clé 32 o), rotation `previous_key` | CONFIRMÉ (avertissement : seulement si une source de confiance existe) | openbao.org seal/static |
| 29 | OpenBao : backend PostgreSQL | CONFIRMÉ (production ready ; HA depuis v2.7.0 ; SSL par défaut) | openbao.org storage/postgresql |
| 30 | OpenBao : auth Kubernetes ; génération de mot de passe ; audit stdout | CONFIRMÉ | openbao.org auth/kubernetes, api-docs policies-password, audit/file |
| 31 | CNPG managed roles réalignent les mots de passe | CONFIRMÉ (réconciliation, `ALTER ROLE` manuel annulé) | cloudnative-pg.io docs 1.28 declarative_role_management |
| 32 | …et réalignement après restauration | INTROUVABLE | non documenté |
| 33 | Authentik : back-channel logout ; `blueprints.configMaps` ; JWT fédéré K8s | CONFIRMÉ (JWT : OSS stable à prouver) | docs.goauthentik.io ; chart helm values |
| 34 | Doppler : expiration des jetons de service | CONFIRMÉ | docs.doppler.com service-tokens |
| 35 | Doppler : historique de révision comme retour arrière | CORRIGÉ (rollback existe, mais 3 jours de journal au plan Developer) | docs versioning ; doppler.com/pricing |
| 36 | Doppler : 50 jetons, 10 projets (Developer) | CONFIRMÉ | doppler.com/pricing |
| 37 | Doppler : références croisées avec jeton de service ; jeton d'espace de travail gratuit | INTROUVABLE | doc officielle muette ; fils communautaires |
| 38 | gVisor arm64 ; `systrap` par défaut | CONFIRMÉ | gvisor.dev install, platforms |
| 39 | Talos : extension `siderolabs/gvisor` (aarch64) | CONFIRMÉ (sysctl `max_user_namespaces`) | github siderolabs/extensions |
| 40 | Talos : pas d'extension Kata officielle | CORRIGÉ (`kata-containers` existe, niveau extra) | github siderolabs/extensions |
| 41 | gVisor : incompatibilités syscalls/eBPF | CONFIRMÉ (`bpf` partiel, `io_uring` partiel) | gvisor.dev compatibility |
| 42 | A1 sans virtualisation imbriquée | CONFIRMÉ (source secondaire) | blogs.oracle.com via recherche web |
| 43 | agent-sandbox : CRDs, K8s ≥ 1.25, délégation RuntimeClass | CONFIRMÉ | kubernetes-sigs/agent-sandbox README |
| 44 | agent-sandbox sur arm64 | INTROUVABLE | README muet |
| 45 | agentgateway : clés virtuelles, budgets, authz MCP CEL | CONFIRMÉ (budget par clé : serveur de rate limit requis) | agentgateway.dev docs 1.7.x |
| 46 | Renovate `minimumReleaseAge` / `internalChecksFilter` | CORRIGÉ (`strict` par défaut ; sécurité contourne l'âge) | docs.renovatebot.com |
| 47 | Renovate automerge, `platformAutomerge`, `postUpgradeTasks` auto-hébergé | CONFIRMÉ (`platformAutomerge` actif par défaut) | docs.renovatebot.com |
| 48 | App Mend sans `postUpgradeTasks` | INTROUVABLE (restreint, non interdit explicitement) | hosted-apps-config |
| 49 | cosign : `--certificate-identity`, `--certificate-oidc-issuer` ; Kyverno `verifyImages` | CONFIRMÉ | docs.sigstore.dev ; kyverno.io |
| 50 | SLSA : attestations GitHub = L3 | CORRIGÉ (L2 seul) | docs.github.com artifact-attestations ; slsa.dev |
| 51 | Scorecard : checks cités ; incident tj-actions (CVE-2025-30066) | CONFIRMÉ (incident : sources secondaires, CISA en 403) | github ossf/scorecard ; thehackernews |
| 52 | Talos : A/B et retour arrière si échec de démarrage | CONFIRMÉ | docs.siderolabs.com upgrading-talos |
| 53 | OKE : plan de contrôle d'abord, cycling de nœuds | CORRIGÉ (pas de retour arrière ; « Replace boot volume » sans nouvelle instance) | docs.oracle.com ContEng |
| 54 | CNCF Cloud Native Maturity Model : Build→Adapt | CONFIRMÉ (5 niveaux) ; CORRIGÉ : 4 piliers People/Process/Policy/Technology | maturitymodel.cncf.io |
| 55 | DORA : 5 métriques dont rework rate | CONFIRMÉ (MTTR renommé *failed deployment recovery time*, 2023) | dora.dev |
| 56 | MinIO en « mode maintenance » ; Garage AGPL | CORRIGÉ (dépôt « no longer maintained ») ; Garage CONFIRMÉ | github minio/minio ; deuxfleurs-org/garage |
| 57 | OpenChoreo : agents SRE, FinOps, Portal Assistant | CONFIRMÉ | openchoreo.dev/docs/ai/* |
| 58 | OpenChoreo : « architect agent » | INTROUVABLE dans OpenChoreo (existe dans WSO2 Choreo SaaS) | docs ai, sitemap ; wso2.com/choreo/changelog |
| 59 | OpenChoreo : URL de base LLM configurable | CORRIGÉ (`rca.llm.baseUrl`, `portalAssistant.llm.baseUrl` ; rien pour FinOps) | chart values release-v1.3 |
| 60 | OpenChoreo : agents limités au fournisseur OpenAI | CONFIRMÉ | docs sre-agent, finops-agent, portal-assistant |
| 61 | MCP : 7 toolsets, 14 outils `query_*` | CONFIRMÉ | docs reference/mcp-servers |
| 62 | IDP : Harness en 5 pratiques ; Cycloid en 5 étapes | CONFIRMÉ (Harness) ; CORRIGÉ (Cycloid : cadre complet rédigé) | harness.io ; cycloid.io |
| 63 | Datadog (modèle d'exécution, étapes déterministes) ; Anthropic ; Team Topologies ; SRE toil 50 % ; post-mortems sans blâme | CONFIRMÉ | sources lues |
| 64 | Datadog : « agents 13 % plus rapides » ; Etsy blameless (403) ; Humanitec « vagues » ; détail mergeConfidence | INTROUVABLE | pages sans ces éléments ou inaccessibles |

## Corrections qui changent le plan
1. **A1 = 2 OCPU / 12 Go, même en PAYG** (ligne 22). Touche `missions/MISSION.md` l.31 et `STATE.md` l.18 (« 4/24 »), ADR-0017, T-140/COST-1, `backlog/proposals/homelab.yaml`, l'hypothèse « OKE à 4/24 » de `HOMELAB-CAPACITY-DATAPLANE.md`. Proposé : corriger MISSION et STATE, clore la discordance de T-140 avec la source datée, interdire tout nœud de surge ; ADR-0016 : pour OKE, utiliser « Replace boot volume » ou une coupure planifiée.
2. **Alerting Grafana Free** (lignes 4, 7). Touche ADR-0015, `observability.yaml` (OBS-1, OBS-2). Proposé : vérifier la date de création du stack ; si postérieure au 2026-04-20, webhook seul (e-mail et Cloud Alertmanager indisponibles) ; budget de 500 règles ; séries au 95e centile.
3. **Agent SRE OpenChoreo routable par agentgateway** (ligne 59). Touche ADR-0018 §8 et ADR-0015 §0.2. La condition (a) est remplie pour SRE et Portal Assistant, pas pour FinOps. Proposé : activer SRE en premier derrière une clé virtuelle à budget bas ; mesurer 1 Gi de mémoire (requête) contre 12 Go ; FinOps reste désactivé ; spike sur un modèle non OpenAI (nom reconnu par LangChain exigé).
4. **Retour arrière Doppler limité à 3 jours** (ligne 35). Touche ADR-0014 §6, T-052, `identity-secrets.yaml`. Proposé : chaque étape de nettoyage garde la copie OpenBao vérifiée ; décision de Paul : plan Team (90 jours) ou export du journal vers un webhook.
5. **`GITHUB_TOKEN` et CI** (lignes 18, 20, 21). Touche ADR-0016 (UPG-2, GitHub App) et ADR-0019. Proposé : GitHub App toujours requise pour une CI automatique sur PR Renovate (sinon approbation manuelle) ; l'envoi `workflow_dispatch` de la remédiation (OBS) fonctionne avec le jeton Actions seul ; ingestion DORA : budgéter 1 000 req/h.
6. **SLSA** (ligne 50). Touche ADR-0016 §5, T-020, DATA-PLATFORM S3. Proposé : afficher « Build L2 » ; L3 seulement avec workflow réutilisable vérifié.
7. **Renovate** (lignes 46, 48). Touche T-064 et `.github/renovate.json`. `internalChecksFilter: strict` est le défaut ; l'écart du constat disparaît mais le fixer explicitement ; garder Renovate auto-hébergé (`postUpgradeTasks`).
8. **Dépôt privé** (ligne 19). Touche COST-5 : seuil 12 $, pas 2 000 minutes.
9. **Rôles gérés CNPG** (lignes 31, 32). Touche ADR-0014 (« réalignés à la restauration ») et T-022. Proposé : ajouter un test de restauration prouvant le réalignement avant de s'y fier.
10. **OpenBao sur PostgreSQL** (ligne 29). Touche ADR-0014 §3 : option valide, HA depuis v2.7.0 ; trancher la dépendance circulaire CNPG ↔ OpenBao.
11. **Libellés de métriques** (lignes 54, 55). Touche ADR-0019 : MTTR devient *failed deployment recovery time* ; CNMM 4.0 compte quatre piliers (le dépôt cartografos lu en comptait cinq dimensions : à réconcilier).
12. **Pas d'« architect agent » OpenChoreo** (ligne 58). Aucune ADR à créer ; ne pas le planifier.
