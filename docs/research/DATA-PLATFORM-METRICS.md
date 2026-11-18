# Data platform légère et mesure de la plateforme agentique

Recherche du 2026-11-18. Statut : proposition (aucun cluster touché). Marqueurs : [L] lu aujourd'hui, [E] non lu ou
issu de ma connaissance, à vérifier avant d'acter.

## Conclusion
- Premier objectif : **mesurer la plateforme elle-même** (DORA par agent, sécurité, maturité cloud native), pas bâtir
  une data platform généraliste. Le besoin tient dans quelques Mo par an : **Parquet partitionné + DuckDB**, sans
  Iceberg/Delta ni serveur. Un format de table se justifie quand plusieurs écrivains concurrents ou du time travel
  apparaissent (non requis) [E].
- **Phase 0 sans cluster** : un workflow GitHub Actions planifié ingère, calcule, publie une page statique et les
  Parquet. **Phase 1** (après T-030) : Garage + CronJob sur le homelab, jamais sur OKE (budget CPU, ADR-0003).
- Restitution : **fichier statique dans Git/Pages** (source de vérité lisible par les agents) + quelques jauges poussées
  à Grafana Cloud pour les alertes. Les agents lisent les fichiers, pas Grafana.
- La maturité CNCF se mesure en **grille de preuves automatisables**, pas en note déclarative : chaque case est un
  check PASS/FAIL/NOT_TESTED daté (AGENTS.md). Le niveau reste jugé par application, comme le modèle le dit [L].

## Sources lues
| Source | Statut | Apport |
|---|---|---|
| github.com/cncf/cartografos (README, `reference/v4beta1/prologue.md`, `technology.md`) | [L] | 5 niveaux, 5 dimensions, capacités techniques par niveau |
| maturitymodel.cncf.io, tag-app-delivery.cncf.io, dora.dev | NON LU : hôtes non autorisés dans la session | à autoriser, puis relire |
| github.com/cncf/tag-app-delivery (`platforms-maturity-model/README.md`) | [L] partiel | v1 d'oct. 2023 ; détail des critères non lu |
| `docs/research/IDP-AGENTIC-BEST-PRACTICES.md` L39-40 | [L] | modèle plateformes : 5 aspects, 4 niveaux |
| `kube-ops/docs/runbooks/observability-for-agents.md` | [L] | Grafana Cloud, label `cluster`, budget 8 000 séries/cluster, Alloy |
| `homelab-infra` : « projet Data Platform / OKR » | [L] introuvable (`docs/`, `roadmap/`) | NON TROUVÉ ; ne rien en déduire |
| OpenSSF Scorecard, SLSA, DORA 2024 (5 métriques), DuckDB, Garage/MinIO/SeaweedFS | [E] | connaissance générale, à confirmer |

Modèle CNCF v4beta1 [L] : niveaux **Build, Operate, Scale, Improve, Adapt** ; dimensions **Business Outcomes, People,
Process, Policy, Technology** ; pas de grille de notation formelle, évaluation par application, « ne retenir que le
pertinent ». `technology.md` numérote les niveaux 1 à 5 et y rattache : N1 IaC, CI, registre, sondes ; N2 GitOps,
admission, scan d'images + SBOM, Prometheus/OTel, quotas ; N3 policy-as-code, multi-cluster, SLSA 1, alerting/traces ;
N4 Crossplane, SLSA 2, Falco, chaos ; N5 IaC entièrement automatisé, anti-dérive, SLSA 3, déploiement continu,
récupération automatique, FinOps intégré.

## Architecture minimale
```
GitHub API (PR, merges, runs, reverts, reviews) ─┐
Argo CD (apps, history, sync) via git/notifications ├─> ingest (Python/DuckDB, idempotent) ─> bronze/ Parquet
app-status.v1 (statuts publiés, ADR-0011) ────────┤                                       ─> silver/ (normalisé)
Grafana Cloud (alertes, incidents, API lecture) ───┤                                       ─> gold/ (métriques)
Coûts LLM (journaux d'usage agents) ───────────────┘                                              │
                                                  DuckDB (requêtes SQL) ─> metrics.json + index.html (Git/Pages)
                                                                      └─> jauges remote_write -> Grafana Cloud
```
- **Stockage objet** (phase 1) : Garage (S3, léger, Rust ; AGPL) [E] sur le homelab, un volume Longhorn. MinIO
  (édition communautaire en mode maintenance fin 2025) [E] et SeaweedFS (plus riche, plus lourd) écartés pour la
  taille ; R2 reste le choix hors site (déjà utilisé, ADR-0008) pour la copie des données de classe `useful`.
- **Partitionnement** : `source=<x>/dt=AAAA-MM-JJ/part-*.parquet` ; un fichier par jour et source (petits fichiers,
  compactés mensuellement). Bronze = réponses brutes filtrées (champs utiles uniquement) ; silver = événements
  normalisés ; gold = une ligne par (métrique, fenêtre, dimension).
- **Idempotence** : clé naturelle (`pr_number`, `run_id`, `sha`) ; relecture à fenêtre glissante de 14 jours ;
  réécriture de la partition du jour, jamais de mise à jour en place.
- **Où ça tourne** : phase 0, GitHub Actions `schedule` (gratuit pour un dépôt public ; minutes sinon à compter) [E] ;
  phase 1, CronJob dans `lab-data` (homelab, PSA restricted, egress `api.github.com` et `*.grafana.net` déclarés),
  déployé comme une app du golden path (archétype D, T-011) : pas de chemin spécial.
- **Fréquence** : ingestion toutes les heures (rate limit GitHub : 5 000 req/h authentifié [E], largement suffisant),
  gold quotidien, rapport hebdomadaire. **Coût** : ~0 (Actions) puis < 100m CPU, < 256 Mi, quelques Mo de disque.
- **Identité** : jeton GitHub en lecture seule limité au dépôt, livré par OpenBao/ESO (ADR-0014) ; jamais dans Git.

## Catalogue de métriques
Dimensions communes : `agent` (déduit de l'auteur de PR / co-auteur Claude/Codex / mention de session),
`class` (AUTONOME/REVUE/MANDAT, lue dans l'en-tête de la PR ou du ticket), `app`, `cluster`, `env`.
Fenêtres : 7 j et 30 j glissants. Un chiffre sans effectif (`n`) n'est pas publié ; sous n < 5, afficher « insuffisant ».

### A. DORA adaptée aux agents (DORA 2024 : lead time, fréquence, taux d'échec, temps de reprise, + rework rate) [E]
| Id | Métrique | Formule | Source |
|---|---|---|---|
| D1 | Fréquence de déploiement | nb de merges sur `apps/**` ou `platform/**` avec sync Argo Synced+Healthy / jour | GitHub merges + historique Argo |
| D2 | Lead time des changements | médiane (sync Healthy − 1er commit de la PR) | commits PR + Argo |
| D3 | Taux d'échec de changement | (merges suivis d'un revert, d'un `FAIL` runtime ou d'un hotfix < 24 h) / merges | GitHub + app-status.v1 |
| D4 | MTTR (reprise après échec) | médiane (revert Healthy − détection FAIL) | app-status.v1 + Argo |
| D5 | Rework rate | PR de correction d'une PR de l'agent < 7 j / PR fusionnées | GitHub (liens, titres `fix:`) |
| D6 | Intention → PASS | médiane (1er message d'intention − 1er statut RUNTIME=PASS) ; part des intentions PASS sans humain | tickets/sessions + app-status.v1 |
| D7 | Autonomie réelle | PR fusionnées sans revue humaine / PR fusionnées, par classe (cible ADR-0002) | GitHub reviews + CODEOWNERS |
| D8 | Boucle CI | médiane durée `ci-ok` ; taux de CI rouge au 1er essai ; nb d'allers-retours | GitHub Actions |
| D9 | Coût par changement réussi | (jetons × tarif) / merges PASS, par agent | journaux d'usage LLM [E : à instrumenter] |
Piège : le déploiement n'est pas le merge (le merge n'est pas une preuve, AGENTS.md). Un changement est « réussi »
seulement avec une preuve runtime datée. Les PR d'`INTERDIT`/`MANDAT` sont comptées à part (D7).

### B. Maturité sécurité
| Id | Métrique | Formule | Source |
|---|---|---|---|
| S1 | OpenSSF Scorecard | score global et par check (Branch-Protection, Code-Review, Pinned-Dependencies, Token-Permissions, SAST, Dependency-Update-Tool, Vulnerabilities) | `scorecard-action` ou API publique [E] |
| S2 | Couverture ADR-0006 | primitives avec preuve runtime fraîche (< 30 j) / 8 ; une ligne par primitive : pod durci, PSA, default-deny, digest, secrets, rien cluster-scoped, admission, exceptions | `tests/vap`, `tests/kyverno`, app-status |
| S3 | Niveau SLSA du build | 0-3 : provenance générée (L1), signée par l'hébergeur (L2), build isolé non falsifiable (L3) | attestations GitHub (`gh attestation verify`) [E] |
| S4 | Images par digest | images `tag@sha256` / images déployées | manifestes `generated/` |
| S5 | Exceptions actives | nb de `securityExceptions`, ancienneté médiane | `apps/*/app.yaml` |
| S6 | Délai de correction CVE | médiane (fix mergé − alerte) par gravité | Dependabot/Renovate + GitHub |
| S7 | Secrets exposés | alertes secret scanning ouvertes (cible 0) | API GitHub |
| S8 | Noyau protégé | `CODEOWNERS` = liste ADR-0002 (T-007) ; PR touchant le noyau fusionnées sans Paul (cible 0) | GitHub |
| S9 | Tentatives refusées | refus VAP/Kyverno par règle, par agent | audit admission [E : à exposer] |

### C. Maturité cloud native (grille automatisable, niveaux CNCF Build→Adapt)
Chaque ligne = un check binaire daté, rattaché à un niveau (numéro `technology.md`) et à une dimension ; le niveau d'une
app = plus haut niveau dont **tous** les checks passent ; le niveau de la plateforme = médiane des apps, plancher exclu.
| Niveau | Checks automatisables (exemples) | Source |
|---|---|---|
| 1 Build | IaC versionnée ; CI verte ; images dans registre avec digest ; sondes live/ready ; smoke test | repo, CI, app-status |
| 2 Operate | GitOps (Argo Synced) ; secrets via ESO ; admission active ; scan d'images + SBOM ; métriques Prometheus ; quotas | Argo, Kyverno, Grafana |
| 3 Scale | policy-as-code en Enforce ; deux data planes ; SLSA ≥ 1 ; alerting + traces ; FinOps (requests vs usage) | Argo, T-020, Grafana |
| 4 Improve | Crossplane/IaC central ; SLSA ≥ 2 ; audit d'exécution (Falco) ; drill de restauration frais (ADR-0008) | T-027, T-029 |
| 5 Adapt | anti-dérive GitOps ; déploiement continu ; reprise automatique prouvée ; coûts alloués par app | Argo, T-065 |
Dimensions People/Policy/Business Outcomes : peu automatisables ; trois indicateurs seulement : D7 (autonomie),
S8 (noyau tenu), D6 (valeur livrée). Le reste est marqué [E] dans le rapport et ne compte pas pour le niveau.
Honnêteté : k3d ≠ OKE, donc un check porte son `cluster` ; une preuve k3d ne valide pas un niveau pour OKE.

## Gouvernance des données
| Jeu | Contenu | Classe (ADR-0008) | Rétention |
|---|---|---|---|
| bronze | réponses API filtrées, sans corps de PR ni logs | `rebuildable` (refetch possible) | 90 j |
| silver | événements normalisés (id, horodatage, agent, classe) | `rebuildable` | 400 j |
| gold | métriques agrégées | `useful` (historique non reconstructible exactement) | 5 ans, copie chiffrée R2 |
| coûts LLM | jetons et coûts par agent/jour | `useful` | 400 j |
Règles : aucune donnée personnelle ni secret ni contenu de prompt ; identifiants d'agent pseudonymes stables ; noms
de personnes absents des gold ; suppression de silver/bronze = autorisée (reconstructible), gold = MANDAT. Publication
statique sans noms d'apps privées si le dépôt est public. Déclaré dans `app.yaml` (`data.class`) comme toute app.

## Proposition d'ADR-0015 — Data platform légère et mesure de la plateforme
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0006, ADR-0008, ADR-0011, ADR-0012

### Contexte
- Paul veut à terme une data platform sur le homelab, légère en calcul, fondée sur des fichiers en bucket, dont le
  premier usage est d'évaluer la plateforme agentique (DORA, sécurité, maturité cloud native).
- Les ADR fixent des cibles (délai issue → merge, part de PR sans humain, preuves datées) sans instrument pour les mesurer.
- OKE est serré en CPU (ADR-0003) ; le homelab porte les données. Grafana Cloud existe déjà (kube-ops).

### Décision
1. **Une pile fichiers** : Parquet partitionné dans un stockage objet S3 (Garage sur homelab) + DuckDB ; aucun format
   de table ni moteur serveur tant qu'un besoin d'écritures concurrentes ou de time travel n'est pas prouvé.
2. **Mesure d'abord, plateforme ensuite** : le catalogue de métriques (A, B, C) est le périmètre initial ; toute
   nouvelle source passe par un ticket avec formule, source et classe de donnée.
3. **Démarrage sans cluster** (GitHub Actions planifié), puis déplacement sur le homelab comme une app du golden
   path (archétype D) ; jamais sur OKE.
4. **Les métriques sont des faits calculés** à partir de sources déjà publiées (GitHub, Argo, app-status.v1) ;
   aucune saisie manuelle ; aucun chiffre sans effectif ni sans fenêtre.
5. **Restitution** : fichiers statiques versionnés (lus par les agents) ; Grafana Cloud reçoit des jauges bornées
   (budget de séries) pour l'alerte uniquement.
6. **Maturité** : grille de checks PASS/FAIL/NOT_TESTED datés, par application et par cluster ; jamais une note déclarative.
7. **Données** : classes et rétentions du tableau ci-dessus ; ni secret, ni prompt, ni donnée personnelle.
8. **Les agents ne s'évaluent pas eux-mêmes** : le calcul et ses formules sont hors du pouvoir d'écriture des agents
   qu'ils mesurent (`tools/metrics/` en REVUE ; seuils d'objectif dans `docs/adr/`).

### Conséquences
- Ticket(s) : ingestion, formules testées, Garage, restitution, grille CNCF (voir `backlog/proposals/data-platform.yaml`).
- Coût : ~0 en phase 0 ; en phase 1 un volume Longhorn et un CronJob ; dépendance à T-030, T-011, T-072, T-023.
- Risque : loi de Goodhart, car des agents optimisent ce qu'on mesure (merges triviaux, revert rapides). Compensé par
  D3/D5 couplés à D1 et par l'exigence de preuve runtime.

### Alternatives écartées
- **Iceberg/Delta + catalogue** : surdimensionné pour quelques Mo, ajoute un service ; à revoir si volumétrie × 1000.
- **ClickHouse/Postgres/Prometheus seul** : un serveur de plus ; Prometheus ne porte pas bien PR/lead time.
- **MinIO / SeaweedFS** : MinIO en maintenance [E], SeaweedFS plus lourd ; Garage suffit.
- **Tout dans Grafana Cloud** : plafond de séries, pas de relecture facile par les agents, dépendance externe.
- **Outil DORA clé en main (Four Keys, Backstage)** : modèle de données imposé, pas de notion d'agent ni de classe.

### Vérification
- Rejeu : les gold recalculés depuis bronze sont identiques (test déterministe) ; jeu de test synthétique avec valeurs
  attendues pour chaque formule.
- Preuve runtime datée : le CronJob publie un `metrics.json` de moins de 26 h ; alerte sinon.
- Les cibles d'ADR-0002 (délai médian issue → merge, part de PR sans humain) sortent du rapport hebdomadaire.

### Références
cncf/cartografos `reference/v4beta1` ; CNCF TAG App Delivery Platform Engineering Maturity Model ; DORA ; OpenSSF
Scorecard ; SLSA ; DuckDB ; Garage ; `docs/research/IDP-AGENTIC-BEST-PRACTICES.md` ; kube-ops `observability-for-agents.md`.
