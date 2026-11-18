# Observabilité, alerting, exploitation et remédiation automatique

Date : 2026-11-18. Recherche pour un nouvel ADR (proposé en §6) et `backlog/proposals/observability.yaml`. Aucun cluster touché.
Niveaux : **[L]** lu dans ce dépôt / kube-ops / homelab-infra · **[W]** lu sur le web (seule la doc claude-code-action était joignable) · **[E]** connaissance du chercheur, à vérifier avant d'engager un chiffre.
Sources web non joignables (hôte hors liste réseau) : grafana.com, docs.ntfy.sh. Tout chiffre Grafana/ntfy ci-dessous est donc **[E]**.

## 0. Conclusion
1. **Un Alloy par cluster, pas de Prometheus/Loki/Alertmanager locaux, évaluation des alertes dans Grafana Cloud** : c'est déjà le contrat éprouvé de kube-ops et homelab-infra [L] ; l'alerte survit à la perte d'un site et coûte ~40m de CPU sur OKE.
2. **Pas d'observability plane OpenChoreo ni d'agent SRE embarqué** (OpenSearch, clé LLM OpenAI, doublon de notre agent) ; on garde l'option d'un spike homelab pour `query_audit_logs` (OBS-12).
3. **Chaîne de remédiation** : alerte Grafana → `workflow_dispatch` GitHub (jeton limité à Actions) → job qui collecte un contexte **borné et assaini** puis lance l'agent `fix-app` (claude-code-action) → PR ou revert → preuve `app-status.v1`. Aucune issue trouvée, ou garde-fou atteint → **ntfy** (priorité 4) avec lien d'issue, sans secret ni log brut.
4. **Le goulot est la limite de 10 000 séries** [E] partagée par les deux clusters : kube-ops plafonne chaque cluster à 8 000 [L], ce qui dépasse 10 000 au total. Mesurer d'abord (OBS-1).
5. Coût monétaire cible : 0 €. Seul coût réel : quota LLM de l'agent, borné par un budget de dispatch.

## 1. Pratiques communes (sources)
| Pratique | Source | Usage retenu |
|---|---|---|
| Alerter sur les symptômes (utilisateur), pas les causes ; peu d'alertes, toutes actionnables | Google SRE book ch. 6 « Monitoring Distributed Systems » [E] | Règles par signal générique, pas par composant |
| Quatre signaux d'or : latence, trafic, erreurs, saturation ; RED (services) et USE (ressources) | SRE book ch. 6 ; Tom Wilkie RED [E] | `probe_success/duration` par défaut ; HTTP/erreurs seulement si `spec.observability.metrics` |
| SLO + alertes à taux de consommation du budget d'erreur, fenêtres multiples | SRE Workbook ch. 5 « Alerting on SLOs » [E] | Deux seuils (rapide 5 min, lent 1 h), pas de multi-burn-rate complet (trop de séries) |
| Dead man's switch : l'absence de signal est une alerte | Healthchecks.io, Watchdog Alertmanager [E] ; homelab-infra `alert-rules.tf`, `healthchecks.tf` [L] | Reprise telle quelle ; garde de « warm-up » pour le homelab éteint le soir |
| Sondes synthétiques en boîte noire | Grafana Synthetic Monitoring, blackbox_exporter [E] | `prometheus.exporter.blackbox` **intégré à Alloy** (aucun pod de plus), cibles issues de `healthPath` |
| Alertes déclarées en code (OpenTofu), ARC n'applique que create/update | homelab-infra `terraform/grafana-cloud` [L] | Règles et contact points restent dans cette racine ; rotation = escalade Paul |
| Runbook lié à chaque alerte (`runbook_url`) | SRE Workbook ch. 5 ; Grafana annotations [E] | Runbooks à front matter lisible par agent (§4) |
| Revue d'incident sans blâme, actions de suivi mesurables | Etsy « Blameless PostMortems », SRE book ch. 15 [E] ; ADR-0011 §6 [L] | Fiche générée par l'agent dans la PR de correction (OBS-10) |
| Agent de remédiation : périmètre borné, humain en escalade, autonomie progressive | `docs/research/IDP-AGENTIC-BEST-PRACTICES.md` S5, S8, S10 [L] ; ADR-0002 [L] | Classes de `platform-guardrails`, compteur d'essais, disjoncteur |
| claude-code-action : mode automation par `prompt`, `--max-turns`, `--allowedTools` via `claude_args` ; `workflow_dispatch` non documenté sur cette page | github.com/anthropics/claude-code-action `docs/usage.md` [W] | Job dédié, `prompt` construit par le workflow, `--max-turns 40` |

## 2. Collecte
**Alloy unique par cluster** [L : `oracle-a1/observability/alloy-values.yaml`, 25m/128Mi, limites 200m/320Mi, scrape 60 s, `sample_limit 3000`, allowlist de métriques]. Ajouts : `lab_app`/`lab_env`/`cluster` en labels ; blackbox intégré ; `prometheus.receive_http` ClusterIP pour recevoir `lab_app_status` du Job de statut (aucun jeton dans la cellule) ; logs limités à `lab-*`, `dp-*`, `openchoreo-*`, niveau ≥ warn, `limit` par flux.
**Limites free tier Grafana Cloud [E, à confirmer sur la page Usage]** : 10 000 séries actives (moyenne), 50 Go de logs, 50 Go de traces, rétention 14 jours (métriques et logs), 3 utilisateurs, Synthetic Monitoring ~100 000 exécutions/mois, règles gérées par Grafana incluses (plafond de règles non établi). Au-delà, l'ingestion est limitée sans facturation tant qu'aucune carte n'est liée [E] : le risque est une **perte de données**, pas une facture.
**Budget de séries (estimation [S])** : kube-state-metrics filtré ≈ 60/app, sonde ≈ 8/app, plateforme (Argo, CNPG, ESO, cert-manager, OpenBao) ≈ 1 500, homelab socle ≈ 4 500 (mesure kube-ops à reprendre). Cible : homelab 5 000 · OKE 2 500 · apps 1 500 (≈ 20 apps) · marge 1 000. Alerte « série > 80 % » (règle `usage-rules.tf` existante [L]).
**Compute OKE** : Alloy 25m/128Mi [L] + kube-state-metrics ≈ 10m/48Mi [E] ≈ **35–40m, ~180 Mi** soit ~2 % de 1830m ; la marge avant 70 % (~260m, ADR-0003) n'en perd que ~15 %. Aucun nouveau pod pour les sondes.

## 3. Signaux pour un agent
| Niveau | Signal | Qui le lit |
|---|---|---|
| 1 | `app-status.v1` (T-072/T-005) : verdict, niveau, cause typée, révision | l'agent en premier ; seul signal qui sait « l'app fonctionne » (`spec.verify`) |
| 2 | `probe_success`, `probe_duration_seconds` (SLO de disponibilité 99 % / 30 j, seuils rapide/lent) | alerte « app down » |
| 3 | kube-state : restarts, CrashLoop, OOMKilled, Pending, ReadyReplicas ; Argo `argocd_app_info` des `lab-*` | alertes de déploiement |
| 4 | Métriques HTTP/RED de l'app, uniquement si `observability.metrics.enabled` | diagnostic, jamais pour déclencher seul |
Règle : un signal absent est un **trou de collecte**, pas une preuve de santé [L, observability-for-agents.md]. Le homelab est éteint le soir : toute règle applicative porte la garde `warm` de homelab-infra (cluster muet = alerte plateforme `info`, pas de dispatch d'agent).

## 4. Alerting et déclenchement d'un agent
**Choix : Grafana Cloud alerting seul.** Alertmanager local écarté sur OKE (pas de Prometheus local, RAM, meurt avec le site) ; l'Alertmanager kube-prometheus-stack du homelab reste un socle à part [L]. Pas d'inhibition native : les gardes passent dans les requêtes (`and on(cluster) warm`) comme dans homelab-infra [L].
**Routage** (politique de notification, OpenTofu) : `severity=critical` plateforme → ntfy direct, priorité 4-5, **sans agent** (dé-scellement OpenBao, control plane : MANDAT) ; `class=app` → contact point webhook « agent » **et** route ntfy différée de 45 min (si l'alerte vit encore, Paul est prévenu même si l'agent s'est tu) ; `warning` → digest priorité 1 (modèle existant [L]).
**Déclenchement.** Contact point webhook Grafana (charge personnalisée [E]) → `POST /repos/<o>/<r>/actions/workflows/remediate.yml/dispatches` avec `{ref, inputs:{alert, app, env, cluster, fingerprint, runbook}}`. Jeton fine-grained **Actions : write seulement** (ne peut pas pousser de code, contrairement à `repository_dispatch` qui exige Contents : write) [E] ; stocké dans Grafana, MANDAT. Alternative écartée : relais Cloudflare Worker (composant de plus).
**Job `remediate`** (`.github/` = noyau ADR-0002, REVUE) en deux étapes :
1. *collecte sans agent* : jeton Viewer Grafana (modèle `agent-read` [L]) disponible **uniquement ici** ; requêtes bornées (`tools/observe`, fenêtre ≤ 1 h, `limit` ≤ 50, agrégats) → `context.json` typé et assaini (le dépôt est public, journaux publics [L]) ;
2. *agent* : claude-code-action, **sans jeton Grafana ni secret**, `prompt` = skill `fix-app` + `context.json` + fichier runbook ; `--max-turns 40`, `timeout 30 min`, branche `claude/*`.
Les lignes de logs sont des **entrées non fiables** (injection) : c'est pourquoi l'agent ne détient aucun secret et ne reçoit pas de log brut.
**Garde-fous** : dédoublonnage par issue `incident:<app>:<env>` (une issue ouverte = commentaire, pas de nouveau job) ; `concurrency` par app ; max 2 essais/app/24 h, 6 dispatches/jour au total (compteur = issues du jour) ; **disjoncteur** : 2 échecs → label `agent:gave-up`, ntfy, plus aucun dispatch jusqu'à retrait du label par Paul ; l'agent ne touche ni règles d'alerte, ni `.github/`, ni silences (noyau) ; une PR de revert compte comme un essai ; pas de dispatch tant que l'app a une PR de correction ouverte (anti-boucle alerte → PR → sync → alerte).
**Issues possibles** : revert (AUTONOME), correctif `app.yaml` (selon classe), « rien à faire » (alerte transitoire, résolue) ; hors périmètre (donnée, secret absent → `secret-missing`, quota Oracle, exposition) → escalade immédiate.
**Escalade ntfy** : topic aléatoire secret (modèle `ntfy.sh` + `random_password` [L]), secret GitHub `NTFY_TOPIC`. Contenu : app, env, cluster, cause typée, essais, lien issue/PR, action attendue (« décider », « débloquer »). Jamais de secret, valeur, log ni nom de topic. Priorité 4 (app) / 5 (plateforme indisponible) ; succès de l'agent : priorité 2, ou rien. Limite ntfy.sh ~250 messages/jour [E] : agrégation par groupe. Le ntfy interne (T-015) n'est **pas** le canal d'alerte : il tomberait avec le site surveillé [L, homelab-infra `notifications.tf`].
**Runbooks lisibles par agent** : `docs/runbooks/<alertname>.md`, front matter `alert`, `severity`, `class` (AUTONOME/REVUE/MANDAT), `signals`, `checks` (commandes lecture seule), `allowed_actions`, `escalate_when` ; lint CI : chaque règle a un runbook (OBS-0).

## 5. OpenChoreo observability plane et SRE agent
Ne pas déployer (OpenSearch + Observer + collecteurs, `observability.md` [L] ; RCA exige une clé OpenAI). Les `query_*` du MCP restent indisponibles ; l'agent s'appuie sur `app-status.v1` et `tools/observe` (Grafana). Réexaminer seulement en spike homelab (OBS-12) pour l'audit `query_audit_logs` (beta).
**Santé de la plateforme** : sondes `/readyz` du control plane (OKE) ; Argo (`argocd_app_info`, contrôleur up) ; OpenBao `sys/health` (scellé = 503, route 5, jamais d'auto-fix) ; ESO (`externalsecret_status_condition`) ; CNPG et sauvegardes (règles existantes [L]) ; agents de data plane : pod up + disponibilité du `ClusterDataPlane` (**[S]** : métrique exacte de connexion de l'agent non vérifiée) ; Healthchecks.io en dead man's switch externe [L].
**Journal d'incident** : `docs/incidents/AAAA-MM-JJ-<app>-<slug>.md` (chronologie, détection, cause prouvée, correctif, test ajouté, ce qui a bien marché) sans noms propres de décision ; MTTD/MTTR = horodatages alerte → issue → PR → PASS.

## 6. Proposition d'ADR
```markdown
# ADR-0015 — Observabilité, alerting et remédiation automatique
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0011, ADR-0013, D-2026-11-15-05 et D-2026-11-13-02 (homelab-infra)

## Contexte
- Paul veut qu'un échec d'application déclenche un agent de remédiation et que, sans issue, il soit prévenu sur son téléphone.
- OKE : 1830m / 8,4 GiB, budget CPU à 70 % ; Grafana Cloud gratuit (≈ 10 000 séries partagées, 14 jours) est déjà la cible
  et l'export Alloy existe sur les deux clusters. Le homelab est éteint certains soirs. Le dépôt est public (journaux publics).
- ADR-0011 fournit `app-status.v1` et la preuve runtime ; il rejette l'observability plane OpenChoreo, sans fixer l'alerting.

## Décision
1. **Collecte** : un Alloy par cluster, métriques en liste blanche et logs filtrés (`lab-*`, `dp-*`, `openchoreo-*`), sondes
   blackbox intégrées ; pas de Prometheus, Loki ni Alertmanager locaux pour le lab. Budget de séries tenu par un registre mesuré.
2. **Alerting** : règles et politique de notification évaluées dans Grafana Cloud, déclarées en OpenTofu ; une règle = un
   runbook ; garde de warm-up pour le homelab éteint.
3. **Remédiation** : une alerte d'application déclenche, par `workflow_dispatch` (jeton limité à Actions), un job qui collecte
   un contexte assaini sans l'agent, puis lance l'agent `fix-app` sans secret. Il agit par PR ou revert, selon les classes
   de `platform-guardrails`. Il ne modifie jamais règles d'alerte, silences, CI ni noyau (ADR-0002).
4. **Garde-fous** : une issue d'incident par (app, env) ; 2 essais/app/24 h ; 6 dispatches/jour ; disjoncteur `agent:gave-up`.
5. **Escalade** : sans issue ou garde-fou atteint, ntfy externe (topic secret), priorité 4 ; plateforme indisponible : priorité 5,
   sans agent. Le contenu ne porte ni secret ni log brut. Le canal d'alerte est hors des sites surveillés.
6. **OpenChoreo observability plane et SRE agent non déployés** ; à réexaminer sur preuve de besoin, hors OKE.
7. Chaque incident produit une fiche sans blâme et, si possible, un test ou une règle.

## Conséquences
- Contrat : labels `lab_app/lab_env/cluster`, schéma de charge d'alerte, format de runbook, `cause.type` dans `app-status.v1`.
- Un workflow `.github/` (noyau, REVUE) et deux jetons (Actions-only, Viewer) créés par Paul (MANDAT).
- Coût : ≈ 40m / 180 Mi sur OKE, 0 € ; quota LLM de l'agent borné par les compteurs.
- Risque accepté : un agent peut ouvrir une PR erronée ; compensé par `ci-ok`, preuve runtime et revert.

## Alternatives écartées
- Alertmanager local : meurt avec le site, RAM, doublon. Observability plane OpenChoreo : trop lourd, clé LLM tierce.
- `repository_dispatch` : exige Contents:write. Agent avec accès cluster : identifiants dans la session, injection par logs.
- ntfy interne comme canal d'alerte : indisponible quand le site tombe.

## Vérification
- Drill daté : app cassée en dev → alerte → issue → PR/revert → PASS ; second cas sans issue → ntfy reçu.
- Test CI : chaque règle d'alerte a un runbook ; le workflow n'expose pas de secret à l'étape agent.
- Indicateurs : MTTD, MTTR, part d'incidents clos sans humain, séries utilisées / 10 000.

## Références
`docs/research/OBSERVABILITY-OPERATIONS.md`, `docs/reference/openchoreo/observability.md`, homelab-infra `terraform/grafana-cloud`.
```

## 7. Budget estimé (récapitulatif)
| Poste | Estimation | Niveau |
|---|---|---|
| CPU/RAM OKE | ~40m, ~180 Mi (Alloy + kube-state) | [L]+[E] |
| Séries Grafana | ≈ 9 000 / 10 000 avec marge 1 000 | [S] |
| Logs | < 5 Go/mois avec filtres (limite 50 Go) | [S] |
| Sondes | 20 apps × 1/min = 0,9 M ex./mois si Synthetic Monitoring ; **hors quota** car blackbox via Alloy | [E] |
| GitHub Actions | 0 € (dépôt public, runners arm64) ; ≤ 6 jobs/jour × 30 min | [L] |
| LLM agent | quota Max partagé ; plafond 6 runs/jour ; mesurer en OBS-11 | [S] |
| ntfy.sh | 0 € ; < 250 messages/jour | [E] |

## 8. Contradictions et trous
- Plafonds 8 000 + 8 000 séries (kube-ops) contre 10 000 (offre) : arbitrage OBS-1.
- `docs/AGENT-RUNNERS.md` limite le déclencheur à l'acteur `SmadjaPaul` : un dispatch par jeton Actions n'est pas ce cas ; amender la condition (`.github/`, REVUE).
- ADR-0014 (OpenBao) : où vit le jeton Alloy sur OKE (ESO + OpenBao ou Doppler) reste à trancher avant OBS-2.
- Non vérifié : plafond de règles gérées, comportement exact au-delà du free tier, charge personnalisée des webhooks Grafana Cloud, métrique de connexion de l'agent de data plane.
