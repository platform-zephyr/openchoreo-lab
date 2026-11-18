# État du backlog (généré)

Généré par `python3 tools/backlog/status.py --write` depuis `backlog/T-*.md` ; ne pas éditer à la main. Aucune date de génération : une date n'est affichée que si le ticket l'écrit dans ses notes. La preuve est la référence citée dans le ticket (fichier `evidence/` ou `PR #n`), pas une vérification runtime. Ordre de travail : [ROADMAP.md](ROADMAP.md) ; prochaines étapes : [NEXT.md](NEXT.md).

## Compteurs

| Statut | Tickets |
|---|---|
| `in-progress` | 16 |
| `todo` | 134 |
| `blocked` | 5 |
| `deferred` | 43 |
| `done` | 23 |
| `dropped` | 27 |
| **Total** | **248** |

## En cours (`in-progress`)

| Ticket | Titre | Critères | Reste | Issue |
|---|---|---|---|---|
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | 3/4 | Reste : critère 4 exige un run GitHub réel (NOT_TESTED, aucun run possible depuis cette session). `development` : le bootstrap ne l'invente plus si `platform/` le fournit (STATIC, yq 4.54.3 testé avec un faux manifeste). `docs/research/GITHUB-CONFIG.md` est a… | — |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins) | 5/7 | Reste à faire : (1) rapport de recoupement (`next.py --overlap-report <ids>`) : sur la liste figée de 20 tickets, 28 paires se recoupent et 21 ne sont pas sérialisées par une dépendance (surtout `tests/` et `docs/` trop larges : T-072, T-050, T-216) ; les sér… | — |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | 4/5 | Premier critère ouvert : (repris de HAR-6) même script en local, en CI et dans le hook Stop (T-331) ; seuls fichier et ligne sont affichés, jamais la valeur | — |
| [T-305](T-305-tag-core-baseline.md) | Tag `core-baseline` du noyau avant le pilote | 3/3 | Reste (2026-11-18) : le ticket reste `in-progress` car le tag précède la fin de S0 (T-303, T-306… encore ouverts à sa pose) et n'est pas signé. Geste de Paul : soit accepter explicitement ce tag comme référence (les PR du noyau d'agents viennent après lui), s… | — |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 réelle (max-parallel ou groupes par… | 1/3 | Premier critère ouvert : factory/PAUSE présent = aucun lancement, aucun merge automatique (test) — STATIC PASS : tests/factory/pause-test.sh (lancement) ; NOT_TESTED : run réel, désarmement d'un auto-merge déjà armé | — |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1 | 5/9 | Premier critère ouvert : lancement manuel avec une liste d'ID : N PR parallèles sur couloirs distincts (preuve datée) | — |
| [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md) | Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop | 4/4 | (ligne « Reste » absente) | — |
| [T-332](T-332-commande-unique-tools-dev-check-static.md) | Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée | 1/3 | Reste aussi : empreintes linux-amd64 dans `toolchain.lock` (VM cloud x86_64) ; les contrôles de T-303, T-306, T-330, T-331 s'activent seuls (NOT_TESTED tant que leur script manque). | — |
| [T-411](T-411-skill-prior-art-gabarit-pr.md) | Skill `prior-art`, 3 lignes dans AGENTS.md et gabarit de PR « Implémentations publiques consultées » | 3/4 | Premier critère ouvert : essai daté : un agent traite un ticket `complet` de test et rend une section valide (preuve STATIC dans la PR) | — |
| [T-451](T-451-ci-speed-csafeloader-alerte-post-merge.md) | CI plus rapide : CSafeLoader dans appgen et argo_guard, alerte des échecs k3d post-merge | 3/5 | Premier critère ouvert : un run `ci` réel montre `platform` et `appgen` sous 30 s, et le premier `hit` du cache des charts de `platform-render` (lien du run) | — |
| [T-452](T-452-reactiver-les-suites-k3d-quand-et-comment.md) | Réactiver les suites k3d : quand et sous quelle forme (étude) | 2/3 | Reste ouvert : critère 3 (le `schedule` nocturne) à la fin de S1. | — |
| [T-458](T-458-ancre-gitops-k3d-obsolete.md) | Réparer l'ancre obsolète de gitops-k3d (correction G1 déjà dans main) | 0/3 | Premier critère ouvert : ancre réparée, la suite va au-delà de T-DEPLOY | — |
| [T-460](T-460-parite-ci-check.md) | Parité ci.yaml ↔ tools/dev/check : ci-map.tsv et test de parité (SL-6) | 2/3 | Reste (critère 2) : forme littérale `--only` (le workflow utilise `CHECK_ONLY=<étapes> tools/dev/check --static --strict`), jobs `hooks` et `quality-coverage` non convertis ; issue 66 à fermer après relecture. | [#66](https://github.com/platform-zephyr/openchoreo-lab/issues/66) |
| [T-466](T-466-durcissement-usine-verdict-prompt.md) | Durcissement de l'usine : plafonds de tours, étape Verdict, trailers always(), branche REST, prompt… | 8/10 | Premier critère ouvert : run réel (RUNTIME, preuve datée) : un dispatch de 2 issues ou plus montre le Verdict, le contrôle des trailers après un échec de l'agent, la branche retrouvée par REST et le commentaire `report` sur… | — |
| [T-467](T-467-garde-de-recouvrement-et-disjoncteur-de-quota.md) | Garde de recouvrement des périmètres et disjoncteur de quota Max pour le planificateur de l'usine | 4/5 | Premier critère ouvert : preuve RUNTIME datée : un dispatch de deux issues en recouvrement s'arrête au job `plan` sans job `dev` ; un | — |
| [T-473](T-473-vue-status-du-backlog.md) | Vue d'état du backlog : fait, en cours, bloqué, prêt (backlog/STATUS.md généré) | 3/5 | Premier critère ouvert : brancher `python3 tools/backlog/status.py --check` dans la CI (job `backlog` de `ci.yaml`, REVUE, point chaud : PR dédiée, sérialisée avec T-460) et dans `tools/dev/check` / `ci-map.tsv` | — |

## Bloqué (`blocked`)

| Ticket | Titre | Blocage | Issue |
|---|---|---|---|
| [T-029](T-029-spike-crossplane.md) | Spike Crossplane sur le homelab (provider Cloudflare pour Access) | Bloqué par : déclencheur ADR-0009 §6 non atteint. | — |
| [T-076](T-076-access-par-app.md) | Application Cloudflare Access générée par app (Crossplane) | Bloqué par : déclencheur ADR-0009 §6 non atteint. | — |
| [T-367](T-367-runners-arc-sur-le-cluster-lab.md) | Runners ARC sur le cluster lab pour la CI du dépôt (sans Docker, éphémères) | Bloqué par : décision (b) de T-343 (runners ARC) ; par défaut (a) aucun runner homelab sur un dépôt public. | — |
| [T-372](T-372-plan-oke-a-deux-nuds-2.md) | Plan OKE à deux nœuds 2/12 (conditionnel) : pool, volumes, IP de pods | Bloqué par : aucune app OKE demandée par Paul. | — |
| [T-462](T-462-devcontainer-multi-arch.md) | Devcontainer multi-architecture et mesure de check --static sous 1 vCPU (SL-8) | Bloqué par : T-470 (fichiers `.devcontainer/` alignés sur le lock), T-471 (mesure sous 1 vCPU / 1 GiB), T-472 (build périodique hors `ci-ok`). T-462 est le ticket parent : il passe `done` quand les trois sont `done`, sans travail propre. | [#67](https://github.com/platform-zephyr/openchoreo-lab/issues/67) |

## À faire, prêts (`todo`, dépendances toutes `done`)

| Ticket | Titre | Critères | Issue |
|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | 0/3 | — |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | 0/3 | — |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | 0/2 | — |
| [T-100](T-100-obs-0.md) | Contrat d'alerte, règles génériques et runbooks lisibles par agent | 0/9 | — |
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | 0/7 | — |
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en paquet de modules à comportement constant (avant le couloir contrat) | 0/4 | — |
| [T-215](T-215-pack-identite.md) | Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1 | 0/9 | — |
| [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md) | Mesures du homelab avant dimensionnement (lecture seule) | 0/3 | — |
| [T-420](T-420-revue-hebdomadaire-maintenabilite.md) | Revue hebdomadaire de maintenabilité par un agent (dette, au plus 3 refactors proposés) | 0/3 | — |
| [T-421](T-421-indicateurs-quality-v1.md) | Indicateurs de maintenabilité `quality.v1` dans la data platform et le rapport de l'usine | 0/2 | — |
| [T-431](T-431-reglages-depot-actions-securite.md) | Réglages du dépôt, d'Actions et de sécurité as-code (repo, actions, security JSON) | 0/5 | — |
| [T-434](T-434-gestes-organisation-paul.md) | Gestes d'organisation de Paul : 2FA, permissions de base, création de dépôts, PAT, Apps tierces, Actions | 0/3 | — |
| [T-469](T-469-triage-echecs-suite-k3d.md) | Triage des cas FAIL préexistants de la suite k3d | 0/4 | — |

## À faire, bloqués par dépendance

| Ticket | Titre | Attend | Issue |
|---|---|---|---|
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | T-001 (todo), T-002 (in-progress) | [#49](https://github.com/platform-zephyr/openchoreo-lab/issues/49) |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | T-003 (todo) | [#50](https://github.com/platform-zephyr/openchoreo-lab/issues/50) |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | T-003 (todo), T-364 (todo) | [#51](https://github.com/platform-zephyr/openchoreo-lab/issues/51) |
| [T-006](T-006-mcp-cloudflare-access.md) | Accès des agents cloud au statut des apps du homelab : statut publié dans GitHub, lu par l'API GitH… | T-005 (todo) | [#52](https://github.com/platform-zephyr/openchoreo-lab/issues/52) |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | T-215 (todo) | — |
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | T-001 (todo), T-002 (in-progress) | — |
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker \| cronjob` (G1) | T-010 (todo) | — |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | T-005 (todo) | — |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | T-003 (todo), T-005 (todo) | [#53](https://github.com/platform-zephyr/openchoreo-lab/issues/53) |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | T-002 (in-progress), T-364 (todo) | — |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | T-002 (in-progress), T-364 (todo) | — |
| [T-022](T-022-spike-openbao.md) | OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill | T-404 (todo) | — |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | T-005 (todo), T-022 (todo), T-060 (todo) | — |
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | T-002 (in-progress), T-214 (todo) | — |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | T-025 (todo), T-364 (todo), T-404 (todo) | — |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | T-005 (todo), T-012 (todo), T-026 (todo), T-075 (todo) | — |
| [T-028](T-028-exposition-publique.md) | Exposition `private \| internal \| public` : route par hôte (G6) et refus « public sans auth » | T-189 (todo), T-404 (todo) | — |
| [T-031](T-031-placement-coupure.md) | Test de reprise et « jour 2 » du cluster lab (critère C4 révisé) | T-364 (todo) | — |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | T-010 (todo) | — |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | T-005 (todo) | — |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | T-015 (todo), T-040 (todo), T-041 (todo), T-043 (todo), T-212 (todo) | — |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | T-020 (todo), T-021 (todo), T-027 (todo), T-031 (todo), T-040 (todo), T-043 (todo), T-189 (todo), T-404 (todo) | — |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | T-001 (todo) | — |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | T-001 (todo), T-002 (in-progress), T-363 (todo) | — |
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | T-005 (todo), T-015 (todo) | — |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | T-025 (todo), T-026 (todo) | — |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | T-025 (todo) | — |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | T-002 (in-progress) | — |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | T-023 (todo), T-043 (todo) | — |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | T-025 (todo), T-365 (todo) | — |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | T-025 (todo), T-364 (todo) | — |
| [T-101](T-101-obs-1.md) | Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath | T-140 (todo) | — |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | T-005 (todo), T-100 (todo), T-164 (todo) | — |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | T-100 (todo) | — |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | T-022 (todo), T-100 (todo), T-107 (todo), T-364 (todo) | — |
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | T-100 (todo), T-106 (todo), T-107 (todo) | — |
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | T-002 (in-progress) | — |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | T-120 (todo), T-215 (todo) | — |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | T-002 (in-progress), T-120 (todo) | — |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | T-122 (todo) | — |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | T-003 (todo), T-005 (todo), T-122 (todo) | — |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | T-004 (todo), T-124 (todo), T-140 (todo) | — |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | T-026 (todo), T-027 (todo), T-122 (todo) | — |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | T-001 (todo), T-140 (todo) | — |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | T-001 (todo) | — |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | T-026 (todo), T-065 (todo), T-140 (todo) | — |
| [T-160](T-160-ai-1.md) | gVisor et vcluster jetables pour les agents sur le cluster lab | T-364 (todo) | — |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | T-002 (in-progress), T-023 (todo) | — |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | T-010 (todo), T-023 (todo), T-161 (todo) | — |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | T-020 (todo), T-160 (todo), T-162 (todo) | — |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | T-404 (todo) | — |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | T-161 (todo), T-164 (todo) | — |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | T-161 (todo), T-164 (todo) | — |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | T-044 (todo), T-166 (todo) | — |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | T-160 (todo), T-163 (todo) | — |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | T-162 (todo), T-163 (todo), T-165 (todo), T-166 (todo), T-404 (todo) | — |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | T-022 (todo), T-190 (todo), T-404 (todo) | — |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | T-022 (todo) | — |
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | T-404 (todo) | — |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | T-185 (todo) | — |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc \| proxy \| none` avec client OIDC généré et secret dans OpenBao | T-074 (todo), T-184 (todo), T-185 (todo) | — |
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | T-184 (todo) | — |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | T-051 (todo), T-181 (todo) | — |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | T-181 (todo), T-192 (todo) | — |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | T-181 (todo), T-184 (todo) | — |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | T-065 (todo), T-184 (todo) | — |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | T-020 (todo), T-201 (todo) | — |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | T-201 (todo) | — |
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo en mono-cluster : mesurer C1-C7 et décision de Paul (2026-12-04) | T-031 (todo), T-044 (todo), T-050 (todo), T-212 (todo), T-364 (todo) | — |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | T-214 (todo), T-363 (todo) | — |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | T-002 (in-progress) | — |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | T-002 (in-progress) | — |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | T-211 (todo) | — |
| [T-301](T-301-reecriture-de-l-historique-et-purge.md) | Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique) | T-303 (in-progress) | — |
| [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) | Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission | T-210 (in-progress), T-311 (in-progress), T-313 (in-progress) | — |
| [T-315](T-315-merge-automatique-sous-conditions-app-de.md) | Merge automatique sous conditions : auto-merge natif pendant le dev, App de merge en FINAL | T-210 (in-progress), T-321 (todo) | — |
| [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) | ntfy seulement si nécessaire et résumé quotidien unique | T-314 (todo) | — |
| [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) | Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjon… | T-314 (todo) | — |
| [T-321](T-321-revue-independante-automatique-avant-merge-model.md) | Revue indépendante automatique avant merge (modèle différent, lecture seule) | T-002 (in-progress), T-313 (in-progress) | — |
| [T-322](T-322-calibrage-du-quota-pilote-24-h.md) | Calibrage du quota : pilote 24 h à N=3, paliers décidés par Paul, et décision Max/Ultra | T-303 (in-progress), T-305 (in-progress), T-311 (in-progress), T-313 (in-progress), T-411 (in-progress) | — |
| [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md) | Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets r… | T-332 (in-progress) | — |
| [T-337](T-337-definition-of-done-executable-verify-par.md) | Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée | T-332 (in-progress) | — |
| [T-338](T-338-pack-de-fixtures-et-donnees-synthetiques.md) | Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenCh… | T-002 (in-progress), T-332 (in-progress) | — |
| [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md) | Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins | T-002 (in-progress), T-216 (todo), T-332 (in-progress) | — |
| [T-340](T-340-protocole-d-echec-et-de-reprise.md) | Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket` | T-210 (in-progress), T-337 (todo) | — |
| [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md) | Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager` | T-337 (todo) | — |
| [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) | Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR… | T-062 (todo), T-214 (todo) | — |
| [T-345](T-345-agent-dans-un-conteneur-durci-devcontainer.md) | Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité | T-332 (in-progress) | — |
| [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) | VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops) | T-360 (todo) | — |
| [T-362](T-362-isolation-reseau-de-la-vm-lab.md) | Isolation réseau de la VM lab (UniFi, pare-feu) | T-361 (todo) | — |
| [T-363](T-363-socle-de-la-plateforme-sur-la.md) | Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stocka… | T-001 (todo), T-361 (todo), T-362 (todo) | — |
| [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) | OpenChoreo CP + DP sur la VM lab (CP définitif, D11) et ClusterDataPlane homelab | T-001 (todo), T-360 (todo), T-363 (todo), T-365 (todo), T-366 (todo) | — |
| [T-365](T-365-capacites-du-cluster-homelab-clusters-homelab.md) | Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, sto… | T-214 (todo) | — |
| [T-366](T-366-bundle-multi-arch-installateur-lab.md) | Bundle de sécurité multi-arch et installateur pour le cluster lab | T-001 (todo) | — |
| [T-368](T-368-garde-fous-de-capacite-du-homelab.md) | Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné | T-360 (todo), T-363 (todo) | — |
| [T-400](T-400-retrait-bypass-admin-ruleset.md) | Retirer le contournement admin du ruleset (bypass_actors) et écrire la procédure de réactivation po… | T-007 (todo), T-215 (todo), T-435 (todo) | — |
| [T-401](T-401-revue-securite-finale.md) | Revue de sécurité finale de la plateforme (prérequis de « plateforme finie ») | T-007 (todo), T-215 (todo), T-400 (todo), T-402 (todo), T-405 (todo), T-437 (todo), T-443 (todo) | — |
| [T-402](T-402-garde-image-multi-arch.md) | Garde d'image multi-arch pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64) | T-123 (todo), T-365 (todo) | — |
| [T-403](T-403-rotation-secrets-dev.md) | Rotation des secrets et identités créés en mode dev (FINAL0) | T-215 (todo) | — |
| [T-404](T-404-jalon-final0.md) | Jalon FINAL0 : identité d'usine, contournement retiré, secrets de dev tournés, revue des code owner… | T-007 (todo), T-215 (todo), T-400 (todo), T-403 (todo) | — |
| [T-405](T-405-rotation-complete-final.md) | Rotation complète des secrets et identités du registre (FINAL) | T-404 (todo) | — |
| [T-412](T-412-verificateur-prior-art-ci.md) | Vérificateur `tools/dev/prior_art.py`, job CI `prior-art` requis dans `ci-ok`, hook Stop | T-411 (in-progress), T-331 (in-progress), T-332 (in-progress) | — |
| [T-415](T-415-sous-agent-prior-art-scout.md) | Sous-agent `prior-art-scout` (lecture seule, budget borné) | T-411 (in-progress), T-341 (todo) | — |
| [T-417](T-417-typage-mypy.md) | Typage : `mypy` sans erreur sur `tools/appgen`, puis `--strict` module par module | T-214 (todo) | — |
| [T-419](T-419-retrait-seed-py.md) | Retirer `tools/backlog/seed.py` (1 201 lignes de données, vestige) et le code mort ≥ 80 % | T-412 (todo), T-415 (todo), T-214 (todo) | — |
| [T-422](T-422-mesure-effet-art-anterieur-pilote.md) | Mesurer l'effet de l'art antérieur sur le pilote 24 h (avec/sans, banc T-346 ensuite) | T-412 (todo), T-322 (todo) | — |
| [T-423](T-423-reduire-complexite-argo-guard.md) | Réduire la complexité de `tools/oke/argo_guard.py` et `psa_check.py` (frontière GitOps) | T-001 (todo) | — |
| [T-432](T-432-security-md.md) | SECURITY.md et politique de signalement privé | T-431 (todo) | — |
| [T-433](T-433-protection-tags.md) | Protection des tags : core-baseline et v* (ruleset de type tag) | T-305 (in-progress) | — |
| [T-435](T-435-k3d-ok-requis.md) | Check k3d requis : déclencheur merge_group et k3d-ok dans le ruleset | T-002 (in-progress) | — |
| [T-436](T-436-labels-formulaires-issues.md) | Labels as-code et formulaires d'issue : issues vides coupées, proposition de ticket | T-431 (todo) | — |
| [T-437](T-437-durcir-executant-environnement.md) | Durcir l'exécutant claude-agent : environnement agent-runner, author_association, politique d'acteu… | T-313 (in-progress), T-431 (todo) | — |
| [T-439](T-439-essai-dependency-review.md) | Essai de dependency review sur ce dépôt (gratuité contradictoire dans la documentation) | T-431 (todo) | — |
| [T-443](T-443-attestations-provenance-releases.md) | Attestations de provenance et releases immuables (quand une image ou une archive est construite) | T-402 (todo), T-400 (todo) | — |
| [T-461](T-461-indicateur-d-evasions.md) | Indicateur d'évasions de la CI : tools/dev/ci-escapes.py et ligne « Preuve locale » (SL-7) | T-460 (in-progress) | [#75](https://github.com/platform-zephyr/openchoreo-lab/issues/75) |
| [T-465](T-465-nuit-check-complet.md) | Contrôle nocturne : check --full --k3d, dérive amont, évasions, alerte (SL-11) | T-461 (todo), T-451 (in-progress), T-452 (in-progress) | — |
| [T-470](T-470-devcontainer-fichiers-alignes-lock.md) | Devcontainer : fichiers alignés sur le lock (sans build) | T-332 (in-progress) | [#74](https://github.com/platform-zephyr/openchoreo-lab/issues/74) |
| [T-471](T-471-mesure-check-static-1vcpu.md) | Mesure de check --static sous 1 vCPU et 1 GiB | T-470 (todo) | — |
| [T-472](T-472-build-periodique-devcontainer.md) | Build périodique du devcontainer hors ci-ok | T-470 (todo) | — |

## Fait (`done`)

| Ticket | Titre | Date | Preuve citée | Issue |
|---|---|---|---|---|
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | 2026-11-18 | — | — |
| [T-061](T-061-aligner-mission-adr.md) | Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote) | 2026-11-18 | `PR #54` | — |
| [T-061b](T-061b-acter-autres-adr.md) | Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023, 0024) et les amendements du consensus n°2 (T-061b) | 2026-11-18 | `PR #54` | — |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | 2026-11-18 | `PR #8` | — |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | 2026-11-18 | — | — |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | 2026-11-18 | — | — |
| [T-304](T-304-essai-reel-executant.md) | Essai réel de l'exécutant avant l'heure 0 : push d'un workflow, check.py sur runner, auto-merge, identité `workflows` | 2026-11-18 | `PR #63`, `backlog/evidence/T-304-essai-executant-2026-11-18.md` | — |
| [T-306](T-306-registre-identites.md) | Registre des identités et secrets `docs/state/identities.yaml` (noms, rôles, dates, jamais de valeur) | 2026-11-18 | — | — |
| [T-325](T-325-assistant-des-gestes-humains-une-seance.md) | Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT | 2026-11-18 | — | — |
| [T-326](T-326-ledger-quota-disjoncteur.md) | Ledger minimal de quota et disjoncteur « limit » (prérequis du pilote) | 2026-11-18 | — | — |
| [T-330](T-330-reglages-de-projet-claude-settings-json.md) | Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie | 2026-11-18 | — | — |
| [T-413](T-413-pyproject-ruff-shellcheck.md) | `pyproject.toml` (ruff, mypy, pytest, coverage), 13 bogues ruff à 0 et shellcheck sur les 59 scripts | 2026-11-18 | — | — |
| [T-414](T-414-cliquet-maintenabilite.md) | Cliquet de maintenabilité `tools/quality/check.py` + `baseline.json` (seuils durs sur le code neuf) | 2026-11-18 | — | — |
| [T-418](T-418-tests-outils-backlog.md) | Tests des outils `tools/backlog/` (check.py, roadmap.py) et `crd2schema.py` (couverture 0 % aujourd'hui) | 2026-11-18 | — | — |
| [T-430](T-430-rulesets-as-code.md) | Rulesets as-code : tools/github/apply.sh (--check/--apply) et main-dev.json alignés sur l'ADR-0002 | 2026-11-18 | — | — |
| [T-450](T-450-nettoyage-gitleaksignore.md) | Nettoyer la dette de .gitleaksignore (129 emplacements) et le vider | 2026-11-18 | — | — |
| [T-453](T-453-combler-ecart-check-static-ci.md) | Combler l'écart check --static ↔ CI (SL-1) | 2026-11-18 | — | — |
| [T-454](T-454-outils-controle-vm-cloud.md) | Outils de contrôle dans la VM cloud : cloud-setup, doctor, empreintes amd64 (SL-2, réalise T-334) | — | — | — |
| [T-455](T-455-check-fast-file-changed-jobs-json-recu.md) | check --fast, --file, --changed, --jobs, --json et reçu (SL-3) | 2026-11-18 | — | — |
| [T-456](T-456-corriger-t12-cle-eso-lab-pg-roles.md) | Corriger T12 : clé ESO lab-pg-roles/<nom> refusée par le provider kubernetes | 2026-11-18 | — | — |
| [T-457](T-457-b09-known-fail-au-niveau-du-cas.md) | Classer B-09 KNOWN_FAIL au niveau du cas dans tests/vap/run.sh | 2026-11-18 | — | — |
| [T-459](T-459-pre-commit-et-setup.md) | Pre-commit et pre-push : .pre-commit-config.yaml et tools/dev/setup (SL-4) | — | — | — |
| [T-463](T-463-spike-politiques-sans-cluster.md) | Spike : tests de politiques Kyverno et VAP sans cluster (SL-9) | 2026-11-18 | — | — |
| [T-464](T-464-regles-d-agent-local-d-abord.md) | Règles d'agent « local d'abord » dans AGENTS.md et les skills (SL-10) | 2026-11-18 | — | — |
| [T-468](T-468-corriger-check-selftest.md) | Corriger le FAIL de check-selftest (test périmé après T-460) | — | — | — |

## Gelés et abandonnés

- `deferred` : [T-013](T-013-overrides-dependances.md), [T-014](T-014-archetype-e-helm-durci.md), [T-030](T-030-dataplane-homelab.md), [T-042](T-042-atlas-route-intent.md), [T-052](T-052-retrait-kube-ops.md), [T-063](T-063-dr-plateforme.md), [T-073](T-073-dependances-apps.md), [T-077](T-077-banc-intentions-complet.md), [T-126](T-126-upg-7.md), [T-127](T-127-upg-8.md), [T-128](T-128-upg-9.md), [T-129](T-129-upg-10.md), [T-130](T-130-upg-11.md), [T-133](T-133-upg-14.md), [T-134](T-134-upg-15.md), [T-135](T-135-upg-16.md), [T-136](T-136-upg-17.md), [T-137](T-137-upg-18.md), [T-138](T-138-upg-19.md), [T-205](T-205-data-6.md), [T-206](T-206-data-7.md), [T-207](T-207-data-8.md), [T-208](T-208-data-9.md), [T-213](T-213-argo-unique-oke.md), [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md), [T-319](T-319-pool-remote-control-sur-le-homelab.md), [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md), [T-323](T-323-observabilite-de-l-usine-indicateurs-tableau.md), [T-342](T-342-spike-3-jours-cluster-dev-homelab.md), [T-343](T-343-spike-runners-homelab-pour-le-depot.md), [T-346](T-346-banc-d-essai-des-taches-de.md), [T-347](T-347-skills-du-harness-fix-ci-new.md), [T-348](T-348-previews-par-pr-sur-le-cluster.md), [T-349](T-349-canari-du-harness-banc-reduit-nocturne.md), [T-350](T-350-voie-deepseek-spike-de-compatibilite-et.md), [T-352](T-352-boucle-d-amelioration-du-harness-journal.md), [T-382](T-382-route-py-regles-backlog-routing-yaml.md), [T-386](T-386-etalonnage-matrice-haiku-sonnet-opus-sur.md), [T-388](T-388-registre-des-modeles-et-tarifs-docs.md), [T-389](T-389-agentgateway-fournisseur-deepseek-cles-virtuelle.md), [T-390](T-390-garde-de-confidentialite-aucun-log-de.md), [T-392](T-392-revue-trimestrielle-du-routage-retraits-de.md), [T-438](T-438-project-v2-miroir-backlog.md)
- `dropped` : [T-009](T-009-budget-oke-mesure.md), [T-024](T-024-identite-oidc-declaree.md), [T-064](T-064-mises-a-jour.md), [T-066](T-066-rotation-secrets.md), [T-068](T-068-securite-agents.md), [T-102](T-102-obs-2.md), [T-103](T-103-obs-3.md), [T-104](T-104-obs-4.md), [T-105](T-105-obs-5.md), [T-108](T-108-obs-8.md), [T-110](T-110-obs-10.md), [T-112](T-112-obs-12.md), [T-141](T-141-cost-2.md), [T-142](T-142-cost-3.md), [T-143](T-143-cost-4.md), [T-144](T-144-cost-5.md), [T-145](T-145-cost-6.md), [T-146](T-146-cost-7.md), [T-169](T-169-ai-10.md), [T-170](T-170-ai-11.md), [T-182](T-182-ids-3.md), [T-187](T-187-ids-8.md), [T-188](T-188-ids-9.md), [T-191](T-191-ids-12.md), [T-202](T-202-data-3.md), [T-209](T-209-data-10.md), [T-300](T-300-rendre-le-depot-prive-le-temps.md)

## Anomalies de lecture

- T-331 : `in-progress` sans ligne « Reste » dans les notes
