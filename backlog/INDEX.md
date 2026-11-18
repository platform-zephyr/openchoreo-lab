# Index du backlog (généré)

Généré à partir des en-têtes ; ne pas éditer à la main.

### P0 — Fondations : débloquer l'autonomie

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | — | REVUE | 0002 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | — | REVUE | 0002, 0004 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | T-001, T-002 | AUTONOME | 0004 |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | T-003 | AUTONOME | 0004 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | T-072, T-003 | AUTONOME + REVUE + MANDAT | 0011 |
| [T-006](T-006-mcp-cloudflare-access.md) | MCP OpenChoreo lisible depuis les sessions cloud (Tunnel + Access + authz) | T-001, T-060 | REVUE + MANDAT | 0010, 0007 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | — | REVUE | 0002 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` | — | REVUE | 0012 |
| [T-009](T-009-budget-oke-mesure.md) | Estimer le budget OKE et tenir le registre des quotas gratuits | T-001 | AUTONOME | 0003, 0004 |
| [T-030](T-030-dataplane-homelab.md) | Enregistrer le homelab comme `ClusterDataPlane` (chemin NetBird L4) | T-001 | REVUE + MANDAT | 0003 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | T-001 | REVUE | 0006 |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR et aligner MISSION, AGENTS, STATE sur ADR-0002/0007/0010/0012/0014 | — | MANDAT | 0002, 0012 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | T-001, T-002 | REVUE | 0002 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | T-001 | AUTONOME | 0011 |

### P1 — Golden path complet

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | T-001, T-002 | AUTONOME | 0005 |
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | T-010 | AUTONOME | 0005 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | T-005 | AUTONOME | 0011, 0013 |
| [T-013](T-013-overrides-dependances.md) | Surcharges par environnement (G12) | T-003 | AUTONOME | 0005, 0004 |
| [T-014](T-014-archetype-e-helm-durci.md) | Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7) | T-010 | AUTONOME | 0005, 0006 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | T-003, T-005 | AUTONOME | 0004, 0011 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | — | REVUE | 0012 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | T-005 | AUTONOME | 0013 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | T-008 | AUTONOME | 0005 |
| [T-064](T-064-mises-a-jour.md) | Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s | T-005, T-003 | REVUE | 0006, 0004, 0012 |
| [T-065](T-065-sante-periodique-alertes.md) | Santé périodique, revert automatique et alertes (+ G5 observabilité) | T-005, T-015 | AUTONOME + MANDAT | 0011, 0002 |
| [T-068](T-068-securite-agents.md) | Sécurité et attribution des agents | T-001 | REVUE + MANDAT | 0002, 0011 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | T-002 | REVUE | 0001, 0005 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | T-001 | AUTONOME | 0007 |

### P2 — Primitives (sécurité, secrets, identité, données, exposition)

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | T-002, T-009, T-030 | AUTONOME | 0006 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | T-002, T-030 | AUTONOME + MANDAT | 0006, 0003 |
| [T-022](T-022-spike-openbao.md) | Spike OpenBao : placement, stockage, déscellement, sauvegarde | T-009 | AUTONOME + MANDAT | 0014 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | T-022, T-005, T-060 | AUTONOME + REVUE + MANDAT | 0014, 0011 |
| [T-024](T-024-identite-oidc-declaree.md) | Identité déclarée : `identity.mode: oidc | proxy | none` | T-023, T-074, T-061 | REVUE | 0007 |
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | T-002 | AUTONOME | 0008 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | T-025, T-023, T-030 | AUTONOME + MANDAT | 0008, 0009 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | T-026, T-005, T-012, T-075 | AUTONOME | 0008, 0011 |
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | T-024, T-061 | AUTONOME | 0010, 0009 |
| [T-029](T-029-spike-crossplane.md) | Spike Crossplane sur le homelab (provider Cloudflare pour Access) | T-030, T-009, T-061 | AUTONOME + MANDAT | 0009 |
| [T-063](T-063-dr-plateforme.md) | Reprise après sinistre de la plateforme : runbook de reconstruction et drill | T-022, T-062 | AUTONOME + MANDAT | 0008, 0003 |
| [T-066](T-066-rotation-secrets.md) | Rotation et échéances des secrets et jetons racines | T-023 | MANDAT | 0014 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | T-025, T-026 | AUTONOME | 0001, 0008, 0013 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | T-025 | REVUE | 0008, 0006 |
| [T-073](T-073-dependances-apps.md) | Dépendances entre apps `dependsOn` (G11) | T-021 | AUTONOME | 0005 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | T-025, T-030 | AUTONOME | 0008 |
| [T-076](T-076-access-par-app.md) | Application Cloudflare Access générée par app (Crossplane) | T-029, T-028 | AUTONOME | 0010, 0009 |

### P3 — Hybride OKE + homelab

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-031](T-031-placement-coupure.md) | Règle de placement et test de coupure du homelab | T-030 | AUTONOME + MANDAT | 0003 |

### P4 — Intention en langage naturel et connaissance

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | T-010 | AUTONOME | 0013 |
| [T-042](T-042-atlas-route-intent.md) | Atlas : entrée de catalogue et skill de routage d'intention | T-041 | REVUE + MANDAT | 0012, 0013 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai initial de 10 intentions (A, répare, promeut) | T-015, T-041, T-043, T-040 | AUTONOME | 0013 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | T-043, T-023 | AUTONOME | 0013, 0014 |

### P5 — Migration depuis kube-ops

| Ticket | Titre | Dépend de | Classe | ADR |
|---|---|---|---|---|
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | T-024, T-027, T-031, T-020, T-021, T-040, T-043 | AUTONOME | 0007, 0008, 0014, 0003 |
| [T-052](T-052-retrait-kube-ops.md) | Retrait progressif des chemins kube-ops, app par app | T-051, T-050 | MANDAT | 0001, 0008 |
| [T-077](T-077-banc-intentions-complet.md) | Banc complet de 10 intentions (OIDC, base, publique, worker, supprime) | T-051, T-042, T-067 | AUTONOME | 0013 |
