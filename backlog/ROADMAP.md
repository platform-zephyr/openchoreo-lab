# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus avec la revue adverse** (`docs/review/CONSENSUS.md`, 2026-11-18). Objectif de Paul : finir le
plus vite possible avec un maximum d'agents en parallèle ; ce qui accélère passe devant.

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** (ADR-0020), puis des **incréments** (I1 → I8) dont un
   ou deux sont ouverts à la fois. Une étape peut démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : plafond de 4 agents (abonnement, T-145) ; au plus 2 par couloir, 1 sur `contrat-appgen` avant T-214.
4. **Gestes de Paul par lot** : une fois par étape (liste ci-dessous). Les agents préparent les PR et les demandes exactes.
5. **MVP** = une app A sur le homelab, en prod, livrée à partir d'une phrase, avec preuve datée sans coordinateur.

## Gestes de Paul par étape

- **S0** : [T-001](T-001-integrer-pr8-security-bundle.md) (REVUE) ; [T-002](T-002-ci-k3d.md) (REVUE) ; [T-008](T-008-lint-backlog.md) (REVUE) ; [T-041](T-041-context-engineering.md) (REVUE) ; [T-061](T-061-aligner-mission-adr.md) (MANDAT) ; [T-215](T-215-pack-identite.md) (MANDAT) ; [T-007](T-007-test-noyau-codeowners.md) (REVUE) ; [T-217](T-217-vap-default-deny.md) (REVUE) ; [T-210](T-210-dispatcher-agents.md) (REVUE)
- **S1** : [T-005](T-005-preuve-runtime-auto.md) (AUTONOME + REVUE + MANDAT) ; [T-216](T-216-ci-registre.md) (REVUE)
- **S2** : [T-030](T-030-dataplane-homelab.md) (REVUE + MANDAT) ; [T-062](T-062-lab-platform-auto.md) (REVUE) ; [T-145](T-145-cost-6.md) (REVUE + MANDAT) ; [T-213](T-213-argo-unique-oke.md) (REVUE + MANDAT)
- **S3** : [T-070](T-070-garde-contrat.md) (REVUE) ; [T-031](T-031-placement-coupure.md) (AUTONOME + MANDAT)
- **PORTE** : [T-211](T-211-porte-openchoreo.md) (MANDAT)
- **I1** : [T-026](T-026-sauvegardes.md) (AUTONOME + MANDAT) ; [T-069](T-069-vap-data-class.md) (REVUE)
- **I2** : [T-022](T-022-spike-openbao.md) (AUTONOME + MANDAT) ; [T-060](T-060-residu-kgateway.md) (REVUE) ; [T-164](T-164-ai-5.md) (REVUE + MANDAT) ; [T-183](T-183-ids-4.md) (AUTONOME + REVUE) ; [T-185](T-185-ids-6.md) (MANDAT) ; [T-184](T-184-ids-5.md) (AUTONOME + REVUE) ; [T-186](T-186-ids-7.md) (REVUE) ; [T-023](T-023-secrets-generate-provided.md) (AUTONOME + REVUE + MANDAT) ; [T-189](T-189-ids-10.md) (REVUE) ; [T-218](T-218-acter-adr-0014-0019.md) (MANDAT)
- **I3** : [T-021](T-021-reseau-egress-imds.md) (AUTONOME + MANDAT)
- **I4** : [T-106](T-106-obs-6.md) (REVUE + MANDAT) ; [T-107](T-107-obs-7.md) (AUTONOME + MANDAT) ; [T-065](T-065-sante-periodique-alertes.md) (AUTONOME + MANDAT) ; [T-109](T-109-obs-9.md) (AUTONOME + MANDAT) ; [T-147](T-147-cost-8.md) (AUTONOME + MANDAT)
- **I5** : [T-120](T-120-upg-1.md) (REVUE) ; [T-121](T-121-upg-2.md) (REVUE + MANDAT) ; [T-122](T-122-upg-3.md) (AUTONOME + REVUE) ; [T-132](T-132-upg-13.md) (AUTONOME + MANDAT) ; [T-124](T-124-upg-5.md) (AUTONOME + REVUE)
- **I6** : [T-181](T-181-ids-2.md) (MANDAT) ; [T-194](T-194-ids-15.md) (MANDAT) ; [T-195](T-195-ids-16.md) (AUTONOME + MANDAT) ; [T-193](T-193-ids-14.md) (MANDAT)
- **I7** : [T-160](T-160-ai-1.md) (AUTONOME + MANDAT) ; [T-161](T-161-ai-2.md) (REVUE) ; [T-166](T-166-ai-7.md) (REVUE) ; [T-163](T-163-ai-4.md) (REVUE) ; [T-171](T-171-ai-12.md) (AUTONOME + MANDAT)
- **I8** : [T-201](T-201-data-2.md) (REVUE)

## S0 — MVP — socle de confiance (9 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | 0 | socle-oke | REVUE | oui | 59 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | 0 | ci | REVUE | oui | 50 |
| [T-215](T-215-pack-identite.md) | Pack identité : compte agent (rôle Write) et GitHub App plateforme | 0 | gouvernance | MANDAT | oui | 34 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | 0 | connaissance | REVUE | oui | 4 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` | 0 | ci | REVUE | oui | 2 |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR 0001-0006, 0010-0013 et 0020, réaligner MISSION sur le homelab | 0 | gouvernance | MANDAT |  | 80 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | 1 | ci | REVUE | oui | 2 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | 1 | securite | REVUE |  | 0 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher : tickets prêts → un agent par ticket, en parallèle par couloir | 2 | ci | REVUE | oui | 0 |

## S1 — MVP — preuve automatique (4 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | 1 | preuve | AUTONOME | oui | 35 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | 1 | contrat-appgen | AUTONOME | oui | 30 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | 2 | preuve | AUTONOME + REVUE + MANDAT | oui | 28 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | 2 | ci | REVUE | oui | 0 |

## S2 — MVP — deux moteurs en parallèle (OpenChoreo et plain) (6 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | 1 | contrat-appgen | AUTONOME | oui | 3 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | 1 | socle-oke | REVUE | oui | 0 |
| [T-145](T-145-cost-6.md) | Plafond LLM : concurrence des agents, tours, durée et consommation par PR | 1 | agents | REVUE + MANDAT | oui | 0 |
| [T-030](T-030-dataplane-homelab.md) | Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4) | 1 | hybride | REVUE + MANDAT |  | 20 |
| [T-213](T-213-argo-unique-oke.md) | Un seul Argo CD sur OKE et nomenclature OKE figée (D4) | 1 | socle-oke | REVUE + MANDAT |  | 2 |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | 2 | moteur-plain | AUTONOME |  | 2 |

## S3 — MVP — golden path et intentions (10 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | 1 | contrat-appgen | AUTONOME | oui | 13 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | 1 | ci | REVUE | oui | 0 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | 1 | coût | AUTONOME |  | 6 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | 1 | migration | AUTONOME |  | 0 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | 2 | intention | AUTONOME |  | 7 |
| [T-031](T-031-placement-coupure.md) | Règle de placement et test de coupure du homelab | 2 | hybride | AUTONOME + MANDAT |  | 5 |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | 2 | contrat-appgen | AUTONOME |  | 1 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | 3 | intention | AUTONOME | oui | 8 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | 3 | apps | AUTONOME |  | 7 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | 4 | intention | AUTONOME |  | 3 |

## PORTE — Porte d'adoption OpenChoreo (2026-12-04) (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04) | 5 | gouvernance | MANDAT |  | 1 |

## I1 — Données (7 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | 1 | contrat-appgen | AUTONOME |  | 10 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | 2 | donnees | AUTONOME + MANDAT |  | 7 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | 2 | donnees | AUTONOME |  | 5 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | 2 | securite | REVUE |  | 0 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | 3 | contrat-appgen | AUTONOME |  | 5 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | 3 | contrat-appgen | AUTONOME |  | 0 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | 4 | donnees | AUTONOME |  | 4 |

## I1bis — Archétypes D et E (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | 2 | contrat-appgen | AUTONOME |  | 0 |

## I2 — Secrets et identité (12 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | 1 | identité-secrets/authentik | MANDAT | oui | 6 |
| [T-022](T-022-spike-openbao.md) | Spike OpenBao : placement, stockage, déscellement, sauvegarde | 1 | secrets | AUTONOME + MANDAT |  | 21 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | 1 | socle-oke | REVUE |  | 10 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | 1 | identité-secrets/inventaire | AUTONOME + REVUE |  | 10 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | 1 | identité-agents | REVUE + MANDAT |  | 6 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | 1 | contrat-appgen | AUTONOME |  | 5 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | 2 | identité-secrets/openbao | AUTONOME + REVUE | oui | 9 |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | 2 | identité-secrets/utilisateurs | REVUE |  | 0 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | 3 | identité-secrets/apps | REVUE | oui | 4 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | 3 | secrets | AUTONOME + REVUE + MANDAT |  | 9 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | 4 | intention | AUTONOME |  | 0 |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | 6 | gouvernance | MANDAT |  | 0 |

## I3 — Exposition, admission, première app familiale (4 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | 2 | securite | AUTONOME |  | 7 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | 2 | securite | AUTONOME + MANDAT |  | 3 |
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | 4 | exposition | AUTONOME |  | 0 |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | 5 | apps | AUTONOME |  | 2 |

## I4 — Exploitation : observabilité, remédiation, ntfy (8 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-100](T-100-obs-0.md) | Contrat d'alerte, règles génériques et runbooks lisibles par agent | 2 | observabilité | AUTONOME | oui | 4 |
| [T-101](T-101-obs-1.md) | Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath | 2 | observabilité | AUTONOME |  | 0 |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | 3 | remédiation | REVUE + MANDAT | oui | 1 |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | 3 | remédiation | AUTONOME + MANDAT |  | 2 |
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | 4 | preuve | AUTONOME + MANDAT |  | 2 |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | 4 | plateforme-santé | AUTONOME + MANDAT |  | 0 |
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | 4 | remédiation | AUTONOME |  | 0 |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | 5 | alertes | AUTONOME + MANDAT |  | 0 |

## I5 — Montées de version (8 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | 1 | renovate | REVUE | oui | 6 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | 2 | porte | AUTONOME + REVUE | oui | 4 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | 2 | renovate | REVUE + MANDAT | oui | 0 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | 2 | k8s-os | AUTONOME + MANDAT |  | 0 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | 3 | porte | AUTONOME + REVUE | oui | 1 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | 3 | supply-chain | AUTONOME |  | 0 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | 4 | porte | AUTONOME |  | 0 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | 5 | stateful | AUTONOME |  | 0 |

## I6 — Migration Doppler, rotation, audit (6 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | 3 | identité-secrets/migration | AUTONOME |  | 4 |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | 4 | identité-secrets/migration | MANDAT |  | 3 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | 5 | identité-secrets/rotation | MANDAT |  | 0 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | 5 | identité-secrets/audit | AUTONOME + MANDAT |  | 0 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | 6 | identité-secrets/migration | AUTONOME |  | 1 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | 7 | identité-secrets/doppler | MANDAT |  | 0 |

## I7 — Services IA (homelab) (9 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-160](T-160-ai-1.md) | Spike gVisor sur Talos (homelab) : runsc réellement utilisé | 2 | sandbox | AUTONOME + MANDAT |  | 3 |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | 4 | ai-gateway | REVUE | oui | 7 |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | 5 | appgen | AUTONOME | oui | 3 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | 5 | mcp | REVUE |  | 2 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | 5 | observabilité-ia | AUTONOME |  | 1 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | 6 | admission | REVUE |  | 2 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | 6 | contexte | AUTONOME |  | 0 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | 7 | sandbox | AUTONOME |  | 0 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | 7 | apps-ia | AUTONOME + MANDAT |  | 0 |

## I8 — Mesure (DORA, maturité) (3 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |
|---|---|---|---|---|---|---|
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | 1 | données | REVUE | oui | 2 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | 2 | données | AUTONOME |  | 0 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | 3 | données | AUTONOME |  | 0 |

## Gelés jusqu'à la porte ou bloqués par un déclencheur (26)

[T-006](T-006-mcp-cloudflare-access.md) (deferred), [T-013](T-013-overrides-dependances.md) (deferred), [T-014](T-014-archetype-e-helm-durci.md) (deferred), [T-029](T-029-spike-crossplane.md) (blocked), [T-042](T-042-atlas-route-intent.md) (deferred), [T-052](T-052-retrait-kube-ops.md) (deferred), [T-063](T-063-dr-plateforme.md) (deferred), [T-073](T-073-dependances-apps.md) (deferred), [T-076](T-076-access-par-app.md) (blocked), [T-077](T-077-banc-intentions-complet.md) (deferred), [T-126](T-126-upg-7.md) (deferred), [T-127](T-127-upg-8.md) (deferred), [T-128](T-128-upg-9.md) (deferred), [T-129](T-129-upg-10.md) (deferred), [T-130](T-130-upg-11.md) (deferred), [T-133](T-133-upg-14.md) (deferred), [T-134](T-134-upg-15.md) (deferred), [T-135](T-135-upg-16.md) (deferred), [T-136](T-136-upg-17.md) (deferred), [T-137](T-137-upg-18.md) (deferred), [T-138](T-138-upg-19.md) (deferred), [T-205](T-205-data-6.md) (deferred), [T-206](T-206-data-7.md) (deferred), [T-207](T-207-data-8.md) (deferred), [T-208](T-208-data-9.md) (deferred), [T-209](T-209-data-10.md) (deferred)


## Absorbés ou supprimés (24)

[T-009](T-009-budget-oke-mesure.md), [T-024](T-024-identite-oidc-declaree.md), [T-064](T-064-mises-a-jour.md), [T-066](T-066-rotation-secrets.md), [T-068](T-068-securite-agents.md), [T-102](T-102-obs-2.md), [T-103](T-103-obs-3.md), [T-104](T-104-obs-4.md), [T-105](T-105-obs-5.md), [T-108](T-108-obs-8.md), [T-110](T-110-obs-10.md), [T-112](T-112-obs-12.md), [T-141](T-141-cost-2.md), [T-142](T-142-cost-3.md), [T-143](T-143-cost-4.md), [T-144](T-144-cost-5.md), [T-146](T-146-cost-7.md), [T-169](T-169-ai-10.md), [T-170](T-170-ai-11.md), [T-182](T-182-ids-3.md), [T-187](T-187-ids-8.md), [T-188](T-188-ids-9.md), [T-191](T-191-ids-12.md), [T-202](T-202-data-3.md)
