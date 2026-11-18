# Index du backlog (généré)

Généré à partir des en-têtes ; ne pas éditer à la main.

### P0 — Fondations : débloquer l'autonomie

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | — | REVUE | 0002 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | — | REVUE | 0002, 0004 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | T-001, T-002, T-061 | AUTONOME | 0004 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | T-003, T-061, T-072, T-215 | AUTONOME + REVUE + MANDAT | 0011 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | T-215 | REVUE | 0002 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` | — | REVUE | 0012 |
| [T-009](T-009-budget-oke-mesure.md) | Estimer le budget OKE et tenir le registre des quotas gratuits | T-001 | AUTONOME | 0003, 0004 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | — | REVUE | 0012 |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR 0001-0006, 0010-0013 et 0020, réaligner MISSION sur le homelab | — | MANDAT | 0002, 0012 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | T-001, T-061 | AUTONOME | 0011 |
| [T-141](T-141-cost-2.md) | Estimation du budget OKE et contrôle périodique des quotas gratuits (cost-evidence.v1) | T-001, T-140 | AUTONOME + MANDAT | 0003, 0004, 0017 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir | T-007, T-008, T-061, T-215 | REVUE | 0002, 0012, 0013 |
| [T-215](T-215-pack-identite.md) | Pack identité : compte agent (rôle Write) et GitHub App plateforme | — | MANDAT | 0002 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | T-002 | REVUE | 0006, 0002 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | T-002, T-007, T-061 | REVUE | 0002 |

### P1 — Golden path complet

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | T-003, T-061 | AUTONOME | 0004 |
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | T-001, T-002, T-061 | AUTONOME | 0005 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | T-003, T-005, T-061 | AUTONOME | 0004, 0011 |
| [T-030](T-030-dataplane-homelab.md) | Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4) | T-001, T-061 | REVUE + MANDAT | 0003 |
| [T-031](T-031-placement-coupure.md) | Règle de placement et test de coupure du homelab | T-030, T-061 | AUTONOME + MANDAT | 0003 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | T-010, T-061 | AUTONOME | 0013 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | T-005, T-061 | AUTONOME | 0013 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | T-015, T-040, T-041, T-043, T-061 | AUTONOME | 0013 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | T-008, T-061 | AUTONOME | 0005 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | T-001, T-002, T-061 | REVUE | 0002 |
| [T-064](T-064-mises-a-jour.md) | Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s | T-003, T-005 | REVUE | 0006, 0004, 0012 |
| [T-068](T-068-securite-agents.md) | Sécurité et attribution des agents | T-001 | REVUE + MANDAT | 0002, 0011 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | T-002, T-061 | REVUE | 0001, 0005 |
| [T-102](T-102-obs-2.md) | Alloy OKE : collecte filtrée lab-*/dp-*/openchoreo-*, plafonds et récepteur de statut | T-001, T-101 | REVUE + MANDAT | 0003, 0015 |
| [T-103](T-103-obs-3.md) | Sondes blackbox intégrées à Alloy, générées depuis healthPath (G5) | T-010, T-101 | AUTONOME | 0005, 0015 |
| [T-104](T-104-obs-4.md) | Règles d'alerte génériques par label (app, déploiement, plateforme) en OpenTofu | T-100, T-101 | REVUE + MANDAT | 0011, 0015 |
| [T-105](T-105-obs-5.md) | Statut d'app publié comme métrique lab_app_status | T-005, T-072, T-101 | AUTONOME | 0011, 0015 |
| [T-108](T-108-obs-8.md) | Runbooks initiaux lisibles par agent | T-100 | AUTONOME | 0011, 0015 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | T-001, T-061 | AUTONOME | 0017 |
| [T-142](T-142-cost-3.md) | Refus CI de tout ce qui sort du free tier (volume sur OKE, LB, IP, hors région) | T-004, T-030, T-140 | AUTONOME | 0003, 0004, 0017 |
| [T-144](T-144-cost-5.md) | Compteur de minutes CI et garde « dépôt public » | T-002, T-140 | REVUE | 0002, 0017 |
| [T-145](T-145-cost-6.md) | Plafond LLM : concurrence des agents, tours, durée et consommation par PR | T-061, T-215 | REVUE + MANDAT | 0002, 0017 |
| [T-202](T-202-data-3.md) | Métriques DORA par agent et par classe (D1-D8) avec tests de formules | T-072, T-201 | REVUE | 0002, 0011, 0019 |
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04) | T-031, T-044, T-061, T-140, T-212, T-213 | MANDAT | 0020 |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | T-061, T-214 | AUTONOME | 0001, 0020 |
| [T-213](T-213-argo-unique-oke.md) | Un seul Argo CD sur OKE et nomenclature OKE figée (D4) | T-001, T-061 | REVUE + MANDAT | 0003 |
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | T-061 | AUTONOME | 0001, 0005 |

### P2 — Primitives (sécurité, secrets, identité, données, exposition)

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | T-010, T-061 | AUTONOME | 0005 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | T-005, T-061 | AUTONOME | 0011, 0013 |
| [T-014](T-014-archetype-e-helm-durci.md) | Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7) | T-010 | AUTONOME | 0005, 0006 |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | T-002, T-030, T-061 | AUTONOME | 0006 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | T-002, T-030, T-061 | AUTONOME + MANDAT | 0006, 0003 |
| [T-022](T-022-spike-openbao.md) | Spike OpenBao : placement, stockage, déscellement, sauvegarde | T-061 | AUTONOME + MANDAT | 0014 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | T-005, T-022, T-060, T-061 | AUTONOME + REVUE + MANDAT | 0014, 0011 |
| [T-024](T-024-identite-oidc-declaree.md) | Identité déclarée : `identity.mode: oidc | proxy | none` | T-023, T-061, T-074 | REVUE | 0007 |
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | T-002, T-061 | AUTONOME | 0008 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | T-025, T-030, T-061 | AUTONOME + MANDAT | 0008, 0009 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | T-005, T-012, T-026, T-061, T-075 | AUTONOME | 0008, 0011 |
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | T-061, T-189 | AUTONOME | 0010, 0009 |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | T-020, T-021, T-027, T-031, T-040, T-043, T-061, T-189 | AUTONOME | 0007, 0008, 0014, 0003 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | T-001, T-061 | REVUE | 0006 |
| [T-066](T-066-rotation-secrets.md) | Rotation et échéances des secrets et jetons racines | T-023 | MANDAT | 0014 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | T-025, T-026, T-061 | AUTONOME | 0001, 0008, 0013 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | T-025, T-061 | REVUE | 0008, 0006 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | T-023, T-043, T-061 | AUTONOME | 0013, 0014 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | T-001, T-061 | AUTONOME | 0007 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | T-025, T-030, T-061 | AUTONOME | 0008 |
| [T-110](T-110-obs-10.md) | Journal d'incident sans blâme et indicateurs MTTD/MTTR | T-106 | AUTONOME | 0011, 0015 |
| [T-143](T-143-cost-4.md) | Mesure R2 : Go, objets et opérations par bucket, alerte avant 10 Go | T-026, T-140 | AUTONOME + MANDAT | 0008, 0009, 0017 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | T-061 | REVUE + MANDAT | 0002, 0007, 0018 |
| [T-182](T-182-ids-3.md) | Doppler cible : 1 projet, 7 configs, 7 jetons permanents, TTL et références | T-061, T-181 | REVUE + MANDAT | 0014 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | T-061 | AUTONOME + REVUE | 0002, 0007, 0014 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | T-022, T-061, T-183 | AUTONOME + REVUE | 0014 |
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | T-061 | MANDAT | 0007 |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | T-061, T-185 | REVUE | 0007 |
| [T-187](T-187-ids-8.md) | Golden path « retirer un utilisateur » : désactivation, révocation, groupes, données personnelles | T-186 | REVUE | 0007, 0008 |
| [T-188](T-188-ids-9.md) | Identité des agents IA : un client par usage × exécutant, jetons 15 min, coupe-circuit | T-164, T-183, T-185 | AUTONOME + MANDAT | 0002, 0007 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | T-061, T-074, T-184, T-185 | REVUE | 0007, 0014 |
| [T-191](T-191-ids-12.md) | Exécution de la migration d'init : injecter dans OpenBao les secrets utiles existants | T-022, T-181, T-190 | MANDAT | 0014 |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | T-061, T-211 | MANDAT | 0014, 0015, 0016, 0017, 0018, 0019 |

### P3 — Hybride OKE + homelab

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | T-005, T-015, T-061 | AUTONOME + MANDAT | 0011, 0002 |
| [T-100](T-100-obs-0.md) | Contrat d'alerte, règles génériques et runbooks lisibles par agent | T-061, T-072 | AUTONOME | 0015 |
| [T-101](T-101-obs-1.md) | Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath | T-061, T-140 | AUTONOME | 0003, 0015 |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | T-005, T-061, T-100, T-164, T-215 | REVUE + MANDAT | 0002, 0013, 0015 |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | T-061, T-100 | AUTONOME + MANDAT | 0015 |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | T-022, T-030, T-061, T-100, T-107 | AUTONOME + MANDAT | 0003, 0014, 0015 |
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | T-061, T-100, T-106, T-107 | AUTONOME | 0013, 0015 |
| [T-112](T-112-obs-12.md) | Spike optionnel : observability plane OpenChoreo réduit sur le homelab (audit) | T-030, T-101 | AUTONOME | 0003, 0015 |
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | T-002, T-061 | REVUE | 0016 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | T-061, T-120, T-215 | REVUE + MANDAT | 0016 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | T-002, T-061, T-072, T-120 | AUTONOME + REVUE | 0016 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | T-061, T-122 | AUTONOME | 0006, 0016 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | T-003, T-005, T-061, T-122 | AUTONOME + REVUE | 0004, 0011, 0016 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | T-004, T-061, T-124, T-140 | AUTONOME | 0004, 0016 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | T-026, T-027, T-061, T-122 | AUTONOME | 0008, 0016 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | T-001, T-061, T-140 | AUTONOME + MANDAT | 0003, 0004, 0016 |
| [T-146](T-146-cost-7.md) | Coût par app en monnaie de CPU/Go (sans OpenCost) | T-010, T-140 | AUTONOME | 0004, 0017 |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | T-026, T-061, T-065, T-140 | AUTONOME + MANDAT | 0011, 0017 |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | T-022, T-061, T-190 | MANDAT | 0014 |
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | T-061, T-184 | AUTONOME | 0014 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | T-051, T-061, T-181 | AUTONOME | 0014 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | T-061, T-181, T-192 | MANDAT | 0014 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | T-061, T-181, T-184 | MANDAT | 0014 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | T-061, T-065, T-184 | AUTONOME + MANDAT | 0011, 0014 |

### P4 — Intention en langage naturel et connaissance

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-160](T-160-ai-1.md) | Spike gVisor sur Talos (homelab) : runsc réellement utilisé | T-030, T-061 | AUTONOME + MANDAT | 0018 |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | T-002, T-023, T-061 | REVUE | 0018 |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | T-010, T-023, T-061, T-161 | AUTONOME | 0005, 0014, 0018 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | T-020, T-061, T-160, T-162 | REVUE | 0006, 0018 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | T-061, T-161, T-164 | AUTONOME | 0011, 0018 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | T-061, T-161, T-164 | REVUE | 0002, 0018 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | T-044, T-061, T-166 | AUTONOME | 0012, 0018 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | T-061, T-160, T-163 | AUTONOME | 0018 |
| [T-169](T-169-ai-10.md) | Qualification OKE : gVisor sur nœud arm64 géré, sinon repli et placement | T-021, T-140, T-160 | AUTONOME + MANDAT | 0003, 0018 |
| [T-170](T-170-ai-11.md) | Agents OpenChoreo (SRE, FinOps, portail) : spike via le gateway, désactivés par défaut | T-030, T-161, T-165 | AUTONOME + MANDAT | 0018 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | T-061, T-162, T-163, T-165, T-166 | AUTONOME + MANDAT | 0013, 0018 |
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | T-061 | REVUE | 0019 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | T-020, T-061, T-201 | AUTONOME | 0006, 0019 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | T-061, T-072, T-201 | AUTONOME | 0019 |

### P5 — Migration depuis kube-ops

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-006](T-006-mcp-cloudflare-access.md) | MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz) | T-001, T-060 | REVUE + MANDAT | 0010, 0007 |
| [T-013](T-013-overrides-dependances.md) | Surcharges par environnement (G12) | T-003 | AUTONOME | 0005, 0004 |
| [T-029](T-029-spike-crossplane.md) | Spike Crossplane sur le homelab (provider Cloudflare pour Access) | T-030, T-061, T-140 | AUTONOME + MANDAT | 0009 |
| [T-042](T-042-atlas-route-intent.md) | Atlas : entrée de catalogue et skill de routage d'intention | T-041 | REVUE + MANDAT | 0012, 0013 |
| [T-052](T-052-retrait-kube-ops.md) | Retrait progressif des chemins kube-ops, app par app | T-050, T-051 | MANDAT | 0001, 0008 |
| [T-063](T-063-dr-plateforme.md) | Reprise après sinistre de la plateforme : runbook de reconstruction et drill | T-022, T-062 | AUTONOME + MANDAT | 0008, 0003 |
| [T-073](T-073-dependances-apps.md) | Dépendances entre apps `dependsOn` (G11) | T-021 | AUTONOME | 0005 |
| [T-076](T-076-access-par-app.md) | Application Cloudflare Access générée par app (Crossplane) | T-028, T-029 | AUTONOME | 0010, 0009 |
| [T-077](T-077-banc-intentions-complet.md) | Banc complet de 10 intentions (OIDC, base, publique, worker, supprime) | T-042, T-051, T-067 | AUTONOME | 0013 |
| [T-126](T-126-upg-7.md) | bump-versions : recalcul de versions.env (digest OCI, sha256) pour les PR Renovate | T-121 | AUTONOME | 0016 |
| [T-127](T-127-upg-8.md) | Répétition de montée plateforme sur k3d (N-1 vers N) | T-002, T-126 | AUTONOME + REVUE | 0002, 0016 |
| [T-128](T-128-upg-9.md) | Veille des releases par agent : résumés typés et alerte de fin de support | T-120 | AUTONOME | 0012, 0016 |
| [T-129](T-129-upg-10.md) | Runbook et répétition de montée OpenChoreo (une mineure, CRD, bundle) | T-001, T-127, T-128 | AUTONOME + MANDAT | 0016 |
| [T-130](T-130-upg-11.md) | Reconstruction du security bundle par version de chart (procédure et suivi amont) | T-129 | MANDAT | 0016 |
| [T-133](T-133-upg-14.md) | Runbook et preflight de montée Talos (homelab) | T-030, T-132 | AUTONOME + MANDAT | 0003, 0016 |
| [T-134](T-134-upg-15.md) | Fenêtres de maintenance déclaratives (mandat ponctuel de Paul) | T-132, T-133 | REVUE + MANDAT | 0002, 0016 |
| [T-135](T-135-upg-16.md) | Providers et outils Tofu : plan en artefact et refus des ressources payantes | T-120, T-140 | AUTONOME + MANDAT | 0009, 0016 |
| [T-136](T-136-upg-17.md) | OpenSSF Scorecard et durcissement des workflows du dépôt | T-120 | REVUE | 0016 |
| [T-137](T-137-upg-18.md) | Kyverno verifyImages pour les éditeurs qui signent (Audit puis Enforce) | T-020, T-123 | AUTONOME | 0006, 0016 |
| [T-138](T-138-upg-19.md) | Tableau de dette de versions et indicateurs de l'ADR | T-124, T-128 | AUTONOME | 0011, 0016 |
| [T-205](T-205-data-6.md) | Spike Garage sur le homelab (objet S3, volume, sauvegarde R2) | T-025, T-026, T-030 | AUTONOME + MANDAT | 0008, 0019 |
| [T-206](T-206-data-7.md) | Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique | T-011, T-023, T-201, T-205 | AUTONOME | 0011, 0019 |
| [T-207](T-207-data-8.md) | Jauges bornées vers Grafana Cloud et alertes sur seuils d'objectif | T-065, T-206 | AUTONOME + MANDAT | 0019 |
| [T-208](T-208-data-9.md) | Gouvernance des données de mesure (classes, rétention, purge, pseudonymes) | T-025, T-061 | AUTONOME | 0008, 0019 |
| [T-209](T-209-data-10.md) | Instrumenter le coût LLM par agent (jetons, tarif, par changement réussi) | T-164, T-201 | REVUE | 0011, 0019 |
