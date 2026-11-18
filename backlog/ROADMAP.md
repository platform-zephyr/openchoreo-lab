# Feuille de route (générée depuis `backlog/`)

Ordonnancement du 2026-11-18. **Objectif de Paul : finir le plus vite possible, avec un maximum d'agents en parallèle ; tout
ticket qui accélère les suivants passe devant.** Ce fichier est régénéré à partir des en-têtes des tickets.

## Stratégie
1. **Vagues** : un ticket est dans la vague *n* si sa plus longue chaîne de dépendances fait *n*. Tous les tickets d'une vague
   peuvent avancer en parallèle dès que la vague précédente est terminée (en pratique : dès que **leurs** dépendances le sont).
2. **Priorité dans une vague** : d'abord les tickets `velocity` (outillage, CI, preuve, contexte, dispatch), puis ceux qui
   débloquent le plus de tickets (`débloque`).
3. **Couloirs** : un couloir = une zone de fichiers. Au plus **2 agents par couloir** en même temps (1 pour `contrat-appgen`,
   point chaud de conflits) ; nombre total d'agents borné par le plafond LLM (T-145) et 4 jobs parallèles par défaut sur
   l'abonnement.
4. **Gestes humains en lot** : les tickets REVUE/MANDAT attendent Paul. Pour ne pas bloquer les agents, Paul traite ses gestes
   **par lot, une fois par vague** (liste ci-dessous) ; les agents préparent tout le reste (PR prêtes, demande exacte sans valeur).
5. **Le premier accélérateur est le dispatcher (T-210)** : sans lui, chaque lancement d'agent attend un humain.

## Top accélérateurs

| Ticket | Titre | Vague | Débloque |
|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | 0 | 91 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | 0 | 78 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | 0 | 4 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` | 0 | 3 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | 0 | 0 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | 1 | 50 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | 1 | 43 |
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | 1 | 22 |
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | 1 | 15 |
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | 1 | 10 |
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet (bronze/silver), exécution planifiée Actions | 1 | 6 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | 1 | 1 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | 1 | 0 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir | 1 | 0 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | 2 | 39 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | 2 | 12 |
| [T-100](T-100-obs-0.md) | Contrat d'alerte : labels, charge d'alerte, format de runbook, lint | 2 | 7 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | 2 | 6 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | 2 | 4 |
| [T-128](T-128-upg-9.md) | Veille des releases par agent : résumés typés et alerte de fin de support | 2 | 3 |

## Gestes de Paul par vague (MANDAT = geste ; REVUE = approbation de PR)

- **Vague 0** : [T-001](T-001-integrer-pr8-security-bundle.md) (REVUE) ; [T-002](T-002-ci-k3d.md) (REVUE) ; [T-041](T-041-context-engineering.md) (REVUE) ; [T-008](T-008-lint-backlog.md) (REVUE) ; [T-007](T-007-test-noyau-codeowners.md) (REVUE) ; [T-022](T-022-spike-openbao.md) (AUTONOME + MANDAT) ; [T-061](T-061-aligner-mission-adr.md) (MANDAT) ; [T-164](T-164-ai-5.md) (REVUE + MANDAT) ; [T-181](T-181-ids-2.md) (MANDAT)
- **Vague 1** : [T-120](T-120-upg-1.md) (REVUE) ; [T-185](T-185-ids-6.md) (MANDAT) ; [T-201](T-201-data-2.md) (REVUE) ; [T-062](T-062-lab-platform-auto.md) (REVUE) ; [T-070](T-070-garde-contrat.md) (REVUE) ; [T-210](T-210-dispatcher-agents.md) (REVUE) ; [T-030](T-030-dataplane-homelab.md) (REVUE + MANDAT) ; [T-060](T-060-residu-kgateway.md) (REVUE) ; [T-183](T-183-ids-4.md) (AUTONOME + REVUE) ; [T-182](T-182-ids-3.md) (REVUE + MANDAT) ; [T-042](T-042-atlas-route-intent.md) (REVUE + MANDAT)
- **Vague 2** : [T-005](T-005-preuve-runtime-auto.md) (AUTONOME + REVUE + MANDAT) ; [T-184](T-184-ids-5.md) (AUTONOME + REVUE) ; [T-122](T-122-upg-3.md) (AUTONOME + REVUE) ; [T-121](T-121-upg-2.md) (REVUE + MANDAT) ; [T-141](T-141-cost-2.md) (AUTONOME + MANDAT) ; [T-021](T-021-reseau-egress-imds.md) (AUTONOME + MANDAT) ; [T-031](T-031-placement-coupure.md) (AUTONOME + MANDAT) ; [T-160](T-160-ai-1.md) (AUTONOME + MANDAT) ; [T-202](T-202-data-3.md) (REVUE) ; [T-186](T-186-ids-7.md) (REVUE) ; [T-006](T-006-mcp-cloudflare-access.md) (REVUE + MANDAT) ; [T-063](T-063-dr-plateforme.md) (AUTONOME + MANDAT) ; [T-069](T-069-vap-data-class.md) (REVUE) ; [T-136](T-136-upg-17.md) (REVUE) ; [T-144](T-144-cost-5.md) (REVUE) ; [T-209](T-209-data-10.md) (REVUE)
- **Vague 3** : [T-189](T-189-ids-10.md) (REVUE) ; [T-023](T-023-secrets-generate-provided.md) (AUTONOME + REVUE + MANDAT) ; [T-107](T-107-obs-7.md) (AUTONOME + MANDAT) ; [T-132](T-132-upg-13.md) (AUTONOME + MANDAT) ; [T-029](T-029-spike-crossplane.md) (AUTONOME + MANDAT) ; [T-135](T-135-upg-16.md) (AUTONOME + MANDAT) ; [T-169](T-169-ai-10.md) (AUTONOME + MANDAT) ; [T-187](T-187-ids-8.md) (REVUE) ; [T-194](T-194-ids-15.md) (MANDAT)
- **Vague 4** : [T-161](T-161-ai-2.md) (REVUE) ; [T-127](T-127-upg-8.md) (AUTONOME + REVUE) ; [T-145](T-145-cost-6.md) (REVUE + MANDAT) ; [T-026](T-026-sauvegardes.md) (AUTONOME + MANDAT) ; [T-102](T-102-obs-2.md) (REVUE + MANDAT) ; [T-065](T-065-sante-periodique-alertes.md) (AUTONOME + MANDAT) ; [T-191](T-191-ids-12.md) (MANDAT) ; [T-133](T-133-upg-14.md) (AUTONOME + MANDAT)
- **Vague 5** : [T-124](T-124-upg-5.md) (AUTONOME + REVUE) ; [T-166](T-166-ai-7.md) (REVUE) ; [T-205](T-205-data-6.md) (AUTONOME + MANDAT) ; [T-129](T-129-upg-10.md) (AUTONOME + MANDAT) ; [T-143](T-143-cost-4.md) (AUTONOME + MANDAT) ; [T-134](T-134-upg-15.md) (REVUE + MANDAT) ; [T-195](T-195-ids-16.md) (AUTONOME + MANDAT)
- **Vague 6** : [T-104](T-104-obs-4.md) (REVUE + MANDAT) ; [T-106](T-106-obs-6.md) (REVUE + MANDAT) ; [T-163](T-163-ai-4.md) (REVUE) ; [T-130](T-130-upg-11.md) (MANDAT) ; [T-147](T-147-cost-8.md) (AUTONOME + MANDAT) ; [T-170](T-170-ai-11.md) (AUTONOME + MANDAT)
- **Vague 7** : [T-052](T-052-retrait-kube-ops.md) (MANDAT) ; [T-109](T-109-obs-9.md) (AUTONOME + MANDAT) ; [T-171](T-171-ai-12.md) (AUTONOME + MANDAT) ; [T-207](T-207-data-8.md) (AUTONOME + MANDAT)
- **Vague 8** : [T-193](T-193-ids-14.md) (MANDAT)

## Vague 0 — 9 tickets, 7 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | socle-oke | REVUE | oui | 91 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | ci | REVUE | oui | 78 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | connaissance | REVUE | oui | 4 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` | ci | REVUE | oui | 3 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | ci | REVUE | oui | 0 |
| [T-022](T-022-spike-openbao.md) | Spike OpenBao : placement, stockage, déscellement, sauvegarde | secrets | AUTONOME + MANDAT |  | 35 |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR 0001-0019 (+ amendements identité/secrets) et aligner MISSION, AGENTS, STATE | gouvernance | MANDAT |  | 27 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | identité-agents | REVUE + MANDAT |  | 15 |
| [T-181](T-181-ids-2.md) | Inventaire Doppler par catégorie et par consommateur (noms seulement, hors dépôt) | identité-secrets/migration | MANDAT |  | 6 |

## Vague 1 — 18 tickets, 13 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | preuve | AUTONOME | oui | 50 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | contrat-appgen | AUTONOME | oui | 43 |
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | contrat-appgen | AUTONOME | oui | 22 |
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | renovate | REVUE | oui | 15 |
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | identité-secrets/authentik | MANDAT | oui | 10 |
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet (bronze/silver), exécution planifiée Actions | données | REVUE | oui | 6 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | socle-oke | REVUE | oui | 1 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | ci | REVUE | oui | 0 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir | ci | REVUE | oui | 0 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | coût | AUTONOME |  | 25 |
| [T-030](T-030-dataplane-homelab.md) | Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4) | hybride | REVUE + MANDAT |  | 34 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | socle-oke | REVUE |  | 26 |
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | contrat-appgen | AUTONOME |  | 17 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | identité-secrets/inventaire | AUTONOME + REVUE |  | 13 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | contrat-appgen | AUTONOME |  | 8 |
| [T-182](T-182-ids-3.md) | Doppler cible : 1 projet, 7 configs, 7 jetons permanents, TTL et références | identité-secrets/doppler | REVUE + MANDAT |  | 4 |
| [T-042](T-042-atlas-route-intent.md) | Atlas : entrée de catalogue et skill de routage d'intention | connaissance | REVUE + MANDAT |  | 1 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | migration | AUTONOME |  | 1 |

## Vague 2 — 27 tickets, 19 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | preuve | AUTONOME + REVUE + MANDAT | oui | 39 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | identité-secrets/openbao | AUTONOME + REVUE | oui | 12 |
| [T-100](T-100-obs-0.md) | Contrat d'alerte : labels, charge d'alerte, format de runbook, lint | observabilité | AUTONOME | oui | 7 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | porte | AUTONOME + REVUE | oui | 6 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | renovate | REVUE + MANDAT | oui | 4 |
| [T-128](T-128-upg-9.md) | Veille des releases par agent : résumés typés et alerte de fin de support | veille | AUTONOME | oui | 3 |
| [T-141](T-141-cost-2.md) | Estimation du budget OKE et contrôle périodique des quotas gratuits (cost-evidence.v1) | coût | AUTONOME + MANDAT |  | 21 |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | securite | AUTONOME |  | 10 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | securite | AUTONOME + MANDAT |  | 7 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | intention | AUTONOME |  | 7 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | donnees | AUTONOME |  | 7 |
| [T-031](T-031-placement-coupure.md) | Règle de placement et test de coupure du homelab | hybride | AUTONOME + MANDAT |  | 5 |
| [T-160](T-160-ai-1.md) | Spike gVisor sur Talos (homelab) : runsc réellement utilisé | sandbox | AUTONOME + MANDAT |  | 4 |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | contrat-appgen | AUTONOME |  | 2 |
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | contrat-appgen | AUTONOME |  | 2 |
| [T-202](T-202-data-3.md) | Métriques DORA par agent et par classe (D1-D8) avec tests de formules | données | REVUE |  | 2 |
| [T-186](T-186-ids-7.md) | Golden path « ajouter un utilisateur » : users/<id>.yaml, groups/, usergen | identité-secrets/utilisateurs | REVUE |  | 1 |
| [T-006](T-006-mcp-cloudflare-access.md) | MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz) | acces-mcp | REVUE + MANDAT |  | 0 |
| [T-013](T-013-overrides-dependances.md) | Surcharges par environnement (G12) | contrat-appgen | AUTONOME |  | 0 |
| [T-014](T-014-archetype-e-helm-durci.md) | Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7) | contrat-appgen | AUTONOME |  | 0 |
| [T-063](T-063-dr-plateforme.md) | Reprise après sinistre de la plateforme : runbook de reconstruction et drill | exploitation | AUTONOME + MANDAT |  | 0 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | securite | REVUE |  | 0 |
| [T-136](T-136-upg-17.md) | OpenSSF Scorecard et durcissement des workflows du dépôt | supply-chain | REVUE |  | 0 |
| [T-144](T-144-cost-5.md) | Compteur de minutes CI et garde « dépôt public » | ci | REVUE |  | 0 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | données | AUTONOME |  | 0 |
| [T-208](T-208-data-9.md) | Gouvernance des données de mesure (classes, rétention, purge, pseudonymes) | données | AUTONOME |  | 0 |
| [T-209](T-209-data-10.md) | Instrumenter le coût LLM par agent (jetons, tarif, par changement réussi) | données | REVUE |  | 0 |

## Vague 3 — 20 tickets, 17 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | intention | AUTONOME | oui | 9 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | identité-secrets/apps | REVUE | oui | 7 |
| [T-126](T-126-upg-7.md) | bump-versions : recalcul de versions.env (digest OCI, sha256) pour les PR Renovate | plateforme | AUTONOME | oui | 3 |
| [T-142](T-142-cost-3.md) | Refus CI de tout ce qui sort du free tier (volume sur OKE, LB, IP, hors région) | appgen | AUTONOME | oui | 0 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | secrets | AUTONOME + REVUE + MANDAT |  | 24 |
| [T-101](T-101-obs-1.md) | Mesure du free tier Grafana Cloud et registre de budget de séries | observabilité | AUTONOME |  | 10 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | apps | AUTONOME |  | 9 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | contrat-appgen | AUTONOME |  | 7 |
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | identité-secrets/migration | AUTONOME |  | 3 |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | remédiation | AUTONOME + MANDAT |  | 2 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | k8s-os | AUTONOME + MANDAT |  | 2 |
| [T-029](T-029-spike-crossplane.md) | Spike Crossplane sur le homelab (provider Cloudflare pour Access) | exposition | AUTONOME + MANDAT |  | 1 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | supply-chain | AUTONOME |  | 1 |
| [T-073](T-073-dependances-apps.md) | Dépendances entre apps `dependsOn` (G11) | contrat-appgen | AUTONOME |  | 0 |
| [T-135](T-135-upg-16.md) | Providers et outils Tofu : plan en artefact et refus des ressources payantes | k8s-os | AUTONOME + MANDAT |  | 0 |
| [T-146](T-146-cost-7.md) | Coût par app en monnaie de CPU/Go (sans OpenCost) | observabilité | AUTONOME |  | 0 |
| [T-169](T-169-ai-10.md) | Qualification OKE : gVisor sur nœud arm64 géré, sinon repli et placement | oke-ia | AUTONOME + MANDAT |  | 0 |
| [T-187](T-187-ids-8.md) | Golden path « retirer un utilisateur » : désactivation, révocation, groupes, données personnelles | identité-secrets/utilisateurs | REVUE |  | 0 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | identité-secrets/rotation | MANDAT |  | 0 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | données | AUTONOME |  | 0 |

## Vague 4 — 13 tickets, 12 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | ai-gateway | REVUE | oui | 8 |
| [T-127](T-127-upg-8.md) | Répétition de montée plateforme sur k3d (N-1 vers N) | plateforme | AUTONOME + REVUE | oui | 2 |
| [T-145](T-145-cost-6.md) | Plafond LLM : concurrence des agents, tours, durée et consommation par PR | agents | REVUE + MANDAT | oui | 0 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | donnees | AUTONOME + MANDAT |  | 13 |
| [T-102](T-102-obs-2.md) | Alloy OKE : collecte filtrée lab-*/dp-*/openchoreo-*, plafonds et récepteur de statut | observabilité | REVUE + MANDAT |  | 8 |
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | preuve | AUTONOME + MANDAT |  | 6 |
| [T-191](T-191-ids-12.md) | Exécution de la migration d'init : injecter dans OpenBao les secrets utiles existants | identité-secrets/migration | MANDAT |  | 2 |
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | exposition | AUTONOME |  | 1 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai initial de 10 intentions (A, répare, promeut) | intention | AUTONOME |  | 1 |
| [T-133](T-133-upg-14.md) | Runbook et preflight de montée Talos (homelab) | k8s-os | AUTONOME + MANDAT |  | 1 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | intention | AUTONOME |  | 0 |
| [T-112](T-112-obs-12.md) | Spike optionnel : observability plane OpenChoreo réduit sur le homelab (audit) | plateforme-santé | AUTONOME |  | 0 |
| [T-137](T-137-upg-18.md) | Kyverno verifyImages pour les éditeurs qui signent (Audit puis Enforce) | supply-chain | AUTONOME |  | 0 |

## Vague 5 — 14 tickets, 13 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | appgen | AUTONOME | oui | 3 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | porte | AUTONOME + REVUE | oui | 2 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | donnees | AUTONOME |  | 6 |
| [T-103](T-103-obs-3.md) | Sondes blackbox intégrées à Alloy, générées depuis healthPath (G5) | observabilité | AUTONOME |  | 4 |
| [T-105](T-105-obs-5.md) | Statut d'app publié comme métrique lab_app_status | observabilité | AUTONOME |  | 3 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | observabilité-ia | AUTONOME |  | 2 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | mcp | REVUE |  | 2 |
| [T-205](T-205-data-6.md) | Spike Garage sur le homelab (objet S3, volume, sauvegarde R2) | homelab | AUTONOME + MANDAT |  | 2 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | contrat-appgen | AUTONOME |  | 1 |
| [T-129](T-129-upg-10.md) | Runbook et répétition de montée OpenChoreo (une mineure, CRD, bundle) | openchoreo | AUTONOME + MANDAT |  | 1 |
| [T-143](T-143-cost-4.md) | Mesure R2 : Go, objets et opérations par bucket, alerte avant 10 Go | sauvegardes | AUTONOME + MANDAT |  | 1 |
| [T-076](T-076-access-par-app.md) | Application Cloudflare Access générée par app (Crossplane) | exposition | AUTONOME |  | 0 |
| [T-134](T-134-upg-15.md) | Fenêtres de maintenance déclaratives (mandat ponctuel de Paul) | k8s-os | REVUE + MANDAT |  | 0 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | identité-secrets/audit | AUTONOME + MANDAT |  | 0 |

## Vague 6 — 12 tickets, 12 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-104](T-104-obs-4.md) | Règles d'alerte génériques par label (app, déploiement, plateforme) en OpenTofu | observabilité | REVUE + MANDAT | oui | 3 |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | remédiation | REVUE + MANDAT | oui | 2 |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | apps | AUTONOME |  | 4 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | admission | REVUE |  | 2 |
| [T-206](T-206-data-7.md) | Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique | homelab | AUTONOME |  | 1 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | porte | AUTONOME |  | 0 |
| [T-130](T-130-upg-11.md) | Reconstruction du security bundle par version de chart (procédure et suivi amont) | openchoreo | MANDAT |  | 0 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | stateful | AUTONOME |  | 0 |
| [T-138](T-138-upg-19.md) | Tableau de dette de versions et indicateurs de l'ADR | veille | AUTONOME |  | 0 |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | alertes | AUTONOME + MANDAT |  | 0 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | contexte | AUTONOME |  | 0 |
| [T-170](T-170-ai-11.md) | Agents OpenChoreo (SRE, FinOps, portail) : spike via le gateway, désactivés par défaut | agents-openchoreo | AUTONOME + MANDAT |  | 0 |

## Vague 7 — 9 tickets, 8 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-108](T-108-obs-8.md) | Runbooks initiaux lisibles par agent | observabilité | AUTONOME |  | 1 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | identité-secrets/migration | AUTONOME |  | 1 |
| [T-052](T-052-retrait-kube-ops.md) | Retrait progressif des chemins kube-ops, app par app | migration | MANDAT |  | 0 |
| [T-077](T-077-banc-intentions-complet.md) | Banc complet de 10 intentions (OIDC, base, publique, worker, supprime) | intention | AUTONOME |  | 0 |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | plateforme-santé | AUTONOME + MANDAT |  | 0 |
| [T-110](T-110-obs-10.md) | Journal d'incident sans blâme et indicateurs MTTD/MTTR | remédiation | AUTONOME |  | 0 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | sandbox | AUTONOME |  | 0 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | apps-ia | AUTONOME + MANDAT |  | 0 |
| [T-207](T-207-data-8.md) | Jauges bornées vers Grafana Cloud et alertes sur seuils d'objectif | observabilité | AUTONOME + MANDAT |  | 0 |

## Vague 8 — 2 tickets, 2 couloirs

| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | remédiation | AUTONOME |  | 0 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | identité-secrets/doppler | MANDAT |  | 0 |
