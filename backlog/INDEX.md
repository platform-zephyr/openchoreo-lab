# Index du backlog (généré)

Généré à partir des en-têtes ; ne pas éditer à la main.

### P0 — Fondations : débloquer l'autonomie

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | — | REVUE | claude-opus-5-5 | 0002 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | — | REVUE | claude-sonnet-5-5 | 0002, 0004 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | T-001, T-002, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0004 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | T-003, T-061, T-061b, T-072, T-364 | AUTONOME + REVUE + MANDAT | claude-sonnet-5-5 | 0011 |
| [T-006](T-006-mcp-cloudflare-access.md) | Accès des agents cloud au statut des apps du homelab : statut publié dans GitHub, lu par l'API GitHub (lecture seule) | T-005 | AUTONOME | claude-sonnet-5-5 | 0010, 0007 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | — | REVUE | claude-sonnet-5-5 | 0012 |
| [T-009](T-009-budget-oke-mesure.md) | Estimer le budget OKE et tenir le registre des quotas gratuits | T-001 | AUTONOME | — | 0003, 0004 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | — | REVUE | claude-sonnet-5-5 | 0012 |
| [T-061](T-061-aligner-mission-adr.md) | Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote) | — | MANDAT | claude-sonnet-5-5 | 0002, 0021 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | — | AUTONOME | claude-sonnet-5-5 | 0011 |
| [T-141](T-141-cost-2.md) | Estimation du budget OKE et contrôle périodique des quotas gratuits (cost-evidence.v1) | T-001, T-140 | AUTONOME + MANDAT | — | 0003, 0004, 0017 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins) | T-008 | REVUE | claude-sonnet-5-5 | 0002, 0012, 0013 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | T-002 | REVUE | claude-opus-5-5 | 0006, 0002 |
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | — | AUTONOME | claude-sonnet-5-5 | 0001, 0005 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | T-002 | REVUE | claude-sonnet-5-5 | 0002 |
| [T-300](T-300-rendre-le-depot-prive-le-temps.md) | Rendre le dépôt privé le temps de la purge (geste de Paul, réversible) | — | MANDAT | human | 0002 |
| [T-301](T-301-reecriture-de-l-historique-et-purge.md) | Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique) | T-302, T-303 | MANDAT | human | 0002 |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | T-303 | REVUE | claude-opus-5-5 | 0002 |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | — | REVUE | claude-sonnet-5-5 | 0002, 0006 |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 réelle (max-parallel ou groupes par couloir) | — | REVUE | claude-sonnet-5-5 | 0017, 0021 |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1 | T-210, T-311 | REVUE | claude-sonnet-5-5 | 0002, 0013, 0021 |
| [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) | Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission | T-210, T-311, T-313 | REVUE | claude-sonnet-5-5 | 0021 |
| [T-315](T-315-merge-automatique-sous-conditions-app-de.md) | Merge automatique sous conditions : auto-merge natif pendant le dev, App de merge en FINAL | T-061, T-061b, T-210, T-321 | REVUE + MANDAT | claude-sonnet-5-5 | 0002, 0021 |
| [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) | ntfy seulement si nécessaire et résumé quotidien unique | T-061, T-061b, T-314 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0015, 0021 |
| [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) | Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle | T-314 | AUTONOME | claude-sonnet-5-5 | 0021 |
| [T-321](T-321-revue-independante-automatique-avant-merge-model.md) | Revue indépendante automatique avant merge (modèle différent, lecture seule) | T-002, T-313 | REVUE | claude-sonnet-5-5 | 0002, 0021 |
| [T-322](T-322-calibrage-du-quota-pilote-24-h.md) | Calibrage du quota : pilote 24 h à N=3, paliers décidés par Paul, et décision Max/Ultra | T-008, T-302, T-303, T-304, T-305, T-306, T-311, T-313, T-326, T-330 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0017, 0021 |
| [T-325](T-325-assistant-des-gestes-humains-une-seance.md) | Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT | T-008 | AUTONOME | claude-sonnet-5-5 | 0013, 0021 |
| [T-330](T-330-reglages-de-projet-claude-settings-json.md) | Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie | — | REVUE | claude-sonnet-5-5 | 0022 |
| [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md) | Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop | T-303, T-330, T-332 | REVUE | claude-sonnet-5-5 | 0022 |
| [T-332](T-332-commande-unique-tools-dev-check-static.md) | Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée | — | AUTONOME | claude-sonnet-5-5 | 0022 |
| [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md) | Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets réseau | T-061, T-061b, T-332 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0022 |
| [T-337](T-337-definition-of-done-executable-verify-par.md) | Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée | T-008, T-332 | REVUE | claude-sonnet-5-5 | 0012, 0022 |
| [T-338](T-338-pack-de-fixtures-et-donnees-synthetiques.md) | Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo) | T-002, T-332 | AUTONOME | claude-sonnet-5-5 | 0022 |
| [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md) | Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins | T-002, T-061, T-061b, T-216, T-332 | AUTONOME + REVUE | claude-sonnet-5-5 | 0002, 0022 |
| [T-340](T-340-protocole-d-echec-et-de-reprise.md) | Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket` | T-210, T-337 | AUTONOME | claude-sonnet-5-5 | 0022 |
| [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md) | Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager` | T-330, T-337 | REVUE | claude-sonnet-5-5 | 0022 |
| [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md) | Mesures du homelab avant dimensionnement (lecture seule) | — | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003, 0017 |
| [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) | VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops) | T-061, T-061b, T-360 | MANDAT | claude-sonnet-5-5 | 0003 |
| [T-362](T-362-isolation-reseau-de-la-vm-lab.md) | Isolation réseau de la VM lab (UniFi, pare-feu) | T-061, T-061b, T-361 | MANDAT | claude-sonnet-5-5 | 0003 |
| [T-363](T-363-socle-de-la-plateforme-sur-la.md) | Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stockage) | T-001, T-061, T-061b, T-361, T-362 | REVUE + MANDAT | claude-sonnet-5-5 | 0003, 0014 |
| [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) | OpenChoreo CP + DP sur la VM lab (CP définitif, D11) et ClusterDataPlane homelab | T-001, T-061, T-061b, T-360, T-363, T-365, T-366 | REVUE + MANDAT | claude-sonnet-5-5 | 0003, 0020 |
| [T-365](T-365-capacites-du-cluster-homelab-clusters-homelab.md) | Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno | T-214 | AUTONOME | claude-sonnet-5-5 | 0003 |
| [T-061b](T-061b-acter-autres-adr.md) | Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023) et les amendements du consensus n°2 (T-061b) | — | MANDAT | claude-sonnet-5-5 | 0003, 0020, 0022, 0023 |
| [T-326](T-326-ledger-quota-disjoncteur.md) | Ledger minimal de quota et disjoncteur « limit » (prérequis du pilote) | T-311, T-313 | REVUE | claude-sonnet-5-5 | 0017, 0021 |
| [T-366](T-366-bundle-multi-arch-installateur-lab.md) | Bundle de sécurité multi-arch et installateur pour le cluster lab | T-001, T-061, T-061b | REVUE + MANDAT | claude-opus-5-5 | 0003, 0020 |
| [T-306](T-306-registre-identites.md) | Registre des identités et secrets `docs/state/identities.yaml` (noms, rôles, dates, jamais de valeur) | — | REVUE | claude-sonnet-5-5 | 0002, 0022 |
| [T-304](T-304-essai-reel-executant.md) | Essai réel de l'exécutant avant l'heure 0 : push d'un workflow, check.py sur runner, auto-merge, identité `workflows` | T-008, T-210, T-306, T-311, T-313 | REVUE + MANDAT | claude-sonnet-5-5 | 0002, 0021 |
| [T-305](T-305-tag-core-baseline.md) | Tag `core-baseline` du noyau avant le pilote | T-302, T-303, T-304, T-326, T-330 | MANDAT | claude-sonnet-5-5 | 0002 |

### P1 — Golden path complet

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | T-003, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0004 |
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | T-001, T-002, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0005 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | T-003, T-005, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0004, 0011 |
| [T-031](T-031-placement-coupure.md) | Test de reprise et « jour 2 » du cluster lab (critère C4 révisé) | T-061, T-061b, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | T-010, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0013 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | T-005, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0013 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | T-015, T-040, T-041, T-043, T-061, T-061b, T-212 | AUTONOME | claude-sonnet-5-5 | 0013 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | T-008 | AUTONOME | claude-sonnet-5-5 | 0005 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | T-001, T-002, T-061, T-061b, T-363 | REVUE | claude-opus-5-5 | 0002 |
| [T-064](T-064-mises-a-jour.md) | Mises à jour : Renovate (digests), montée OpenChoreo, montée OKE/K8s | T-003, T-005 | REVUE | — | 0006, 0004, 0012 |
| [T-068](T-068-securite-agents.md) | Sécurité et attribution des agents | T-001 | REVUE + MANDAT | — | 0002, 0011 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | T-002, T-061 | REVUE | claude-sonnet-5-5 | 0001, 0005 |
| [T-102](T-102-obs-2.md) | Alloy OKE : collecte filtrée lab-*/dp-*/openchoreo-*, plafonds et récepteur de statut | T-001, T-101 | REVUE + MANDAT | — | 0003, 0015 |
| [T-103](T-103-obs-3.md) | Sondes blackbox intégrées à Alloy, générées depuis healthPath (G5) | T-010, T-101 | AUTONOME | — | 0005, 0015 |
| [T-104](T-104-obs-4.md) | Règles d'alerte génériques par label (app, déploiement, plateforme) en OpenTofu | T-100, T-101 | REVUE + MANDAT | — | 0011, 0015 |
| [T-105](T-105-obs-5.md) | Statut d'app publié comme métrique lab_app_status | T-005, T-072, T-101 | AUTONOME | — | 0011, 0015 |
| [T-108](T-108-obs-8.md) | Runbooks initiaux lisibles par agent | T-100 | AUTONOME | — | 0011, 0015 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | T-001, T-061, T-061b | AUTONOME + MANDAT | claude-sonnet-5-5 | 0017 |
| [T-142](T-142-cost-3.md) | Refus CI de tout ce qui sort du free tier (volume sur OKE, LB, IP, hors région) | T-004, T-030, T-140 | AUTONOME | — | 0003, 0004, 0017 |
| [T-144](T-144-cost-5.md) | Compteur de minutes CI et garde « dépôt public » | T-002, T-140 | REVUE | — | 0002, 0017 |
| [T-145](T-145-cost-6.md) | Plafond LLM : concurrence des agents, tours, durée et consommation par PR | T-061, T-215 | REVUE + MANDAT | — | 0002, 0017 |
| [T-202](T-202-data-3.md) | Métriques DORA par agent et par classe (D1-D8) avec tests de formules | T-072, T-201 | REVUE | — | 0002, 0011, 0019 |
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo en mono-cluster : mesurer C1-C7 et décision de Paul (2026-12-04) | T-031, T-044, T-050, T-061, T-061b, T-212, T-364 | MANDAT | claude-opus-5-5 | 0020 |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | T-061, T-061b, T-214, T-363 | AUTONOME | claude-sonnet-5-5 | 0001, 0020 |
| [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) | Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR d'agents | T-061, T-061b, T-062, T-214 | REVUE | claude-opus-5-5 | 0001, 0022 |
| [T-345](T-345-agent-dans-un-conteneur-durci-devcontainer.md) | Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité | T-330, T-332 | AUTONOME | claude-sonnet-5-5 | 0018, 0022 |
| [T-368](T-368-garde-fous-de-capacite-du-homelab.md) | Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné | T-061, T-061b, T-360, T-363 | AUTONOME + REVUE | claude-sonnet-5-5 | 0017 |

### P2 — Primitives (sécurité, secrets, identité, données, exposition)

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | T-010, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0005 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | T-005, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0011, 0013 |
| [T-014](T-014-archetype-e-helm-durci.md) | Archétype E : chart Helm tiers encapsulé dans une cellule durcie (G7) | T-010 | AUTONOME | claude-sonnet-5-5 | 0005, 0006 |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | T-002, T-061, T-061b, T-364 | AUTONOME | claude-sonnet-5-5 | 0006 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | T-002, T-061, T-061b, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0006, 0003 |
| [T-022](T-022-spike-openbao.md) | OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill | T-061, T-061b, T-404 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0014 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | T-005, T-022, T-060, T-061, T-061b | AUTONOME + REVUE + MANDAT | claude-sonnet-5-5 | 0014, 0011 |
| [T-024](T-024-identite-oidc-declaree.md) | Identité déclarée : `identity.mode: oidc | proxy | none` | T-023, T-061, T-074 | REVUE | — | 0007 |
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | T-002, T-072, T-214 | AUTONOME | claude-sonnet-5-5 | 0008 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | T-025, T-061, T-061b, T-364, T-404 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0008, 0009 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | T-005, T-012, T-026, T-061, T-061b, T-075 | AUTONOME | claude-sonnet-5-5 | 0008, 0011 |
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | T-061, T-061b, T-189, T-404 | AUTONOME | claude-sonnet-5-5 | 0010, 0009 |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | T-020, T-021, T-027, T-031, T-040, T-043, T-061, T-061b, T-189, T-404 | AUTONOME | claude-sonnet-5-5 | 0007, 0008, 0014, 0003 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | T-001, T-061, T-061b | REVUE | claude-sonnet-5-5 | 0006 |
| [T-066](T-066-rotation-secrets.md) | Rotation et échéances des secrets et jetons racines | T-023 | MANDAT | — | 0014 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | T-025, T-026, T-061, T-061b | AUTONOME | claude-sonnet-5-5 | 0001, 0008, 0013 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | T-025, T-061, T-061b | REVUE | claude-opus-5-5 | 0008, 0006 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | T-023, T-043, T-061, T-061b | AUTONOME | claude-haiku-5-5 | 0013, 0014 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | T-025, T-072, T-365 | AUTONOME | claude-sonnet-5-5 | 0007 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | T-025, T-061, T-061b, T-364 | AUTONOME | claude-sonnet-5-5 | 0008 |
| [T-110](T-110-obs-10.md) | Journal d'incident sans blâme et indicateurs MTTD/MTTR | T-106 | AUTONOME | — | 0011, 0015 |
| [T-143](T-143-cost-4.md) | Mesure R2 : Go, objets et opérations par bucket, alerte avant 10 Go | T-026, T-140 | AUTONOME + MANDAT | — | 0008, 0009, 0017 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | T-061, T-061b, T-404 | REVUE + MANDAT | claude-opus-5-5 | 0002, 0007, 0018 |
| [T-182](T-182-ids-3.md) | Doppler cible : 1 projet, 7 configs, 7 jetons permanents, TTL et références | T-061, T-181 | REVUE + MANDAT | — | 0014 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | T-061, T-061b | AUTONOME + REVUE | claude-opus-5-5 | 0002, 0007, 0014 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | T-022, T-061, T-061b, T-183 | AUTONOME + REVUE | claude-opus-5-5 | 0014 |
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | T-061, T-061b, T-404 | MANDAT | claude-opus-5-5 | 0007 |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | T-061, T-061b, T-185 | REVUE | claude-opus-5-5 | 0007 |
| [T-187](T-187-ids-8.md) | Golden path « retirer un utilisateur » : désactivation, révocation, groupes, données personnelles | T-186 | REVUE | — | 0007, 0008 |
| [T-188](T-188-ids-9.md) | Identité des agents IA : un client par usage × exécutant, jetons 15 min, coupe-circuit | T-164, T-183, T-185 | AUTONOME + MANDAT | — | 0002, 0007 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | T-061, T-061b, T-074, T-184, T-185 | REVUE | claude-opus-5-5 | 0007, 0014 |
| [T-191](T-191-ids-12.md) | Exécution de la migration d'init : injecter dans OpenBao les secrets utiles existants | T-022, T-181, T-190 | MANDAT | — | 0014 |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | T-061, T-061b, T-211 | MANDAT | claude-sonnet-5-5 | 0014, 0015, 0016, 0017, 0018, 0019 |

### P3 — Hybride OKE + homelab

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | T-005, T-015, T-061, T-061b | AUTONOME + MANDAT | claude-sonnet-5-5 | 0011, 0002 |
| [T-100](T-100-obs-0.md) | Contrat d'alerte, règles génériques et runbooks lisibles par agent | T-061, T-061b, T-072 | AUTONOME | claude-sonnet-5-5 | 0015 |
| [T-101](T-101-obs-1.md) | Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath | T-061, T-061b, T-140 | AUTONOME | claude-sonnet-5-5 | 0003, 0015 |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | T-005, T-061, T-061b, T-100, T-164 | REVUE + MANDAT | claude-sonnet-5-5 | 0002, 0013, 0015 |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | T-061, T-061b, T-100 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0015 |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | T-022, T-061, T-061b, T-100, T-107, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003, 0014, 0015 |
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | T-061, T-061b, T-100, T-106, T-107 | AUTONOME | claude-sonnet-5-5 | 0013, 0015 |
| [T-112](T-112-obs-12.md) | Spike optionnel : observability plane OpenChoreo réduit sur le homelab (audit) | T-030, T-101 | AUTONOME | — | 0003, 0015 |
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | T-002, T-061, T-061b | REVUE | claude-sonnet-5-5 | 0016 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | T-002, T-061, T-061b, T-072, T-120 | AUTONOME + REVUE | claude-sonnet-5-5 | 0016 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | T-061, T-061b, T-122 | AUTONOME | claude-sonnet-5-5 | 0006, 0016 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | T-003, T-005, T-061, T-061b, T-122 | AUTONOME + REVUE | claude-sonnet-5-5 | 0004, 0011, 0016 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | T-004, T-061, T-061b, T-124, T-140 | AUTONOME | claude-sonnet-5-5 | 0004, 0016 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | T-026, T-027, T-061, T-061b, T-122 | AUTONOME | claude-sonnet-5-5 | 0008, 0016 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | T-001, T-061, T-061b, T-140 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003, 0004, 0016 |
| [T-146](T-146-cost-7.md) | Coût par app en monnaie de CPU/Go (sans OpenCost) | T-010, T-140 | AUTONOME | — | 0004, 0017 |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | T-026, T-061, T-061b, T-065, T-140 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0011, 0017 |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | T-022, T-061, T-061b, T-190, T-404 | MANDAT | claude-sonnet-5-5 | 0014 |
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | T-061, T-061b, T-184 | AUTONOME | claude-sonnet-5-5 | 0014 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | T-051, T-061, T-061b, T-181 | AUTONOME | claude-sonnet-5-5 | 0014 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | T-061, T-061b, T-181, T-192 | MANDAT | claude-sonnet-5-5 | 0014 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | T-061, T-061b, T-181, T-184 | MANDAT | claude-opus-5-5 | 0014 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | T-061, T-061b, T-065, T-184 | AUTONOME + MANDAT | claude-opus-5-5 | 0011, 0014 |

### P4 — Intention en langage naturel et connaissance

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | T-215 | REVUE | claude-opus-5-5 | 0002 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | T-061, T-061b, T-120, T-215 | REVUE + MANDAT | claude-opus-5-5 | 0016 |
| [T-160](T-160-ai-1.md) | gVisor et vcluster jetables pour les agents sur le cluster lab | T-061, T-061b, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0018 |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | T-002, T-023, T-061, T-061b | REVUE | claude-sonnet-5-5 | 0018 |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | T-010, T-023, T-061, T-061b, T-161 | AUTONOME | claude-sonnet-5-5 | 0005, 0014, 0018 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | T-020, T-061, T-061b, T-160, T-162 | REVUE | claude-opus-5-5 | 0006, 0018 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | T-061, T-061b, T-161, T-164 | AUTONOME | claude-sonnet-5-5 | 0011, 0018 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | T-061, T-061b, T-161, T-164 | REVUE | claude-sonnet-5-5 | 0002, 0018 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | T-044, T-061, T-061b, T-166 | AUTONOME | claude-sonnet-5-5 | 0012, 0018 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | T-061, T-061b, T-160, T-163 | AUTONOME | claude-sonnet-5-5 | 0018 |
| [T-169](T-169-ai-10.md) | Qualification OKE : gVisor sur nœud arm64 géré, sinon repli et placement | T-021, T-140, T-160 | AUTONOME + MANDAT | — | 0003, 0018 |
| [T-170](T-170-ai-11.md) | Agents OpenChoreo (SRE, FinOps, portail) : spike via le gateway, désactivés par défaut | T-030, T-161, T-165 | AUTONOME + MANDAT | — | 0018 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | T-061, T-061b, T-162, T-163, T-165, T-166, T-404 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0013, 0018 |
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | T-061, T-061b | REVUE | claude-sonnet-5-5 | 0019 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | T-020, T-061, T-061b, T-201 | AUTONOME | claude-sonnet-5-5 | 0006, 0019 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | T-061, T-061b, T-072, T-201 | AUTONOME | claude-sonnet-5-5 | 0019 |
| [T-215](T-215-pack-identite.md) | Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1 | T-061, T-061b | REVUE + MANDAT | claude-opus-5-5 | 0002 |
| [T-400](T-400-retrait-bypass-admin-ruleset.md) | Retirer le contournement admin du ruleset (bypass_actors) et écrire la procédure de réactivation ponctuelle | T-007, T-215 | REVUE + MANDAT | claude-opus-5-5 | 0002 |
| [T-401](T-401-revue-securite-finale.md) | Revue de sécurité finale de la plateforme (prérequis de « plateforme finie ») | T-007, T-215, T-400, T-402, T-405 | MANDAT | claude-opus-5-5 | 0002, 0006, 0021, 0022 |
| [T-402](T-402-garde-image-multi-arch.md) | Garde d'image multi-arch pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64) | T-123, T-365 | AUTONOME | claude-opus-5-5 | 0003, 0006 |
| [T-403](T-403-rotation-secrets-dev.md) | Rotation des secrets et identités créés en mode dev (FINAL0) | T-215, T-306 | MANDAT | claude-opus-5-5 | 0002, 0022 |
| [T-404](T-404-jalon-final0.md) | Jalon FINAL0 : identité d'usine, contournement retiré, secrets de dev tournés, revue des code owners réactivée | T-007, T-215, T-400, T-403 | MANDAT | claude-opus-5-5 | 0002 |
| [T-405](T-405-rotation-complete-final.md) | Rotation complète des secrets et identités du registre (FINAL) | T-306, T-404 | MANDAT | claude-opus-5-5 | 0002, 0022 |

### P5 — Migration depuis kube-ops

| Ticket | Titre | Dépend de | Classe | Modèle | ADR |
|---|---|---|---|---|---|
| [T-013](T-013-overrides-dependances.md) | Surcharges par environnement (G12) | T-003 | AUTONOME | claude-sonnet-5-5 | 0005, 0004 |
| [T-029](T-029-spike-crossplane.md) | Spike Crossplane sur le homelab (provider Cloudflare pour Access) | T-061, T-140, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0009 |
| [T-030](T-030-dataplane-homelab.md) | Data plane distant entre le cluster lab et OKE (selon la décision D11) | T-001, T-061 | REVUE + MANDAT | claude-sonnet-5-5 | 0003 |
| [T-042](T-042-atlas-route-intent.md) | Atlas : entrée de catalogue et skill de routage d'intention | T-041 | REVUE + MANDAT | claude-sonnet-5-5 | 0012, 0013 |
| [T-052](T-052-retrait-kube-ops.md) | Retrait progressif des chemins kube-ops, app par app | T-050, T-051 | MANDAT | claude-sonnet-5-5 | 0001, 0008 |
| [T-063](T-063-dr-plateforme.md) | Reprise après sinistre de la plateforme : runbook de reconstruction et drill | T-022, T-062 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0008, 0003 |
| [T-073](T-073-dependances-apps.md) | Dépendances entre apps `dependsOn` (G11) | T-021 | AUTONOME | claude-sonnet-5-5 | 0005 |
| [T-076](T-076-access-par-app.md) | Application Cloudflare Access générée par app (Crossplane) | T-028, T-029 | AUTONOME | claude-sonnet-5-5 | 0010, 0009 |
| [T-077](T-077-banc-intentions-complet.md) | Banc complet de 10 intentions (OIDC, base, publique, worker, supprime) | T-042, T-051, T-067 | AUTONOME | claude-sonnet-5-5 | 0013 |
| [T-126](T-126-upg-7.md) | bump-versions : recalcul de versions.env (digest OCI, sha256) pour les PR Renovate | T-121 | AUTONOME | claude-sonnet-5-5 | 0016 |
| [T-127](T-127-upg-8.md) | Répétition de montée plateforme sur k3d (N-1 vers N) | T-002, T-126 | AUTONOME + REVUE | claude-sonnet-5-5 | 0002, 0016 |
| [T-128](T-128-upg-9.md) | Veille des releases par agent : résumés typés et alerte de fin de support | T-120 | AUTONOME | claude-sonnet-5-5 | 0012, 0016 |
| [T-129](T-129-upg-10.md) | Runbook et répétition de montée OpenChoreo (une mineure, CRD, bundle) | T-001, T-127, T-128 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0016 |
| [T-130](T-130-upg-11.md) | Reconstruction du security bundle par version de chart (procédure et suivi amont) | T-129 | MANDAT | claude-sonnet-5-5 | 0016 |
| [T-133](T-133-upg-14.md) | Runbook et preflight de montée Talos (homelab) | T-132, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003, 0016 |
| [T-134](T-134-upg-15.md) | Fenêtres de maintenance déclaratives (mandat ponctuel de Paul) | T-132, T-133 | REVUE + MANDAT | claude-sonnet-5-5 | 0002, 0016 |
| [T-135](T-135-upg-16.md) | Providers et outils Tofu : plan en artefact et refus des ressources payantes | T-120, T-140 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0009, 0016 |
| [T-136](T-136-upg-17.md) | OpenSSF Scorecard et durcissement des workflows du dépôt | T-120 | REVUE | claude-sonnet-5-5 | 0016 |
| [T-137](T-137-upg-18.md) | Kyverno verifyImages pour les éditeurs qui signent (Audit puis Enforce) | T-020, T-123 | AUTONOME | claude-sonnet-5-5 | 0006, 0016 |
| [T-138](T-138-upg-19.md) | Tableau de dette de versions et indicateurs de l'ADR | T-124, T-128 | AUTONOME | claude-sonnet-5-5 | 0011, 0016 |
| [T-205](T-205-data-6.md) | Spike Garage sur le homelab (objet S3, volume, sauvegarde R2) | T-025, T-026, T-364 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0008, 0019 |
| [T-206](T-206-data-7.md) | Jobs de calcul sur le homelab (CronJob lab-data) et restitution statique | T-011, T-023, T-201, T-205 | AUTONOME | claude-sonnet-5-5 | 0011, 0019 |
| [T-207](T-207-data-8.md) | Jauges bornées vers Grafana Cloud et alertes sur seuils d'objectif | T-065, T-206 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0019 |
| [T-208](T-208-data-9.md) | Gouvernance des données de mesure (classes, rétention, purge, pseudonymes) | T-025, T-061 | AUTONOME | claude-sonnet-5-5 | 0008, 0019 |
| [T-209](T-209-data-10.md) | Instrumenter le coût LLM par agent (jetons, tarif, par changement réussi) | T-164, T-201 | REVUE | — | 0011, 0019 |
| [T-213](T-213-argo-unique-oke.md) | Un seul Argo CD sur OKE et nomenclature OKE figée (D4) | T-001, T-061 | REVUE + MANDAT | claude-opus-5-5 | 0003 |
| [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md) | Travailleur homelab en tirage sortant (claude -p) sur VM isolée, sans runner GitHub ni secret | T-002, T-061, T-313, T-360 | REVUE + MANDAT | claude-sonnet-5-5 | 0003, 0021 |
| [T-319](T-319-pool-remote-control-sur-le-homelab.md) | Pool Remote Control sur le homelab pour les tâches à ressources locales | T-061, T-318 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0021 |
| [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md) | Trieur quotidien : tâche planifiée cloud en lecture seule + issue de résumé | T-061, T-316 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0012, 0021 |
| [T-323](T-323-observabilite-de-l-usine-indicateurs-tableau.md) | Observabilité de l'usine : indicateurs, rapport hebdomadaire par (type de tâche, modèle), écart banc/réel, drill de panne | T-061, T-311, T-313, T-314, T-346 | AUTONOME | claude-sonnet-5-5 | 0019, 0021 |
| [T-342](T-342-spike-3-jours-cluster-dev-homelab.md) | Spike (3 jours) : cluster dev homelab pour agents (vcluster, VM dédiée ou namespaces) | T-061, T-363 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0003, 0022 |
| [T-343](T-343-spike-runners-homelab-pour-le-depot.md) | Runners pour le dépôt public : hébergés par défaut, ARC homelab admis pour push/dispatch de mainteneurs seulement | T-061, T-342 | REVUE + MANDAT | claude-sonnet-5-5 | 0022 |
| [T-346](T-346-banc-d-essai-des-taches-de.md) | Banc d'essai des tâches de développement (20-30 tâches, graders par code) et runner de banc | T-061, T-311, T-332, T-337, T-338, T-339 | AUTONOME | claude-sonnet-5-5 | 0022 |
| [T-347](T-347-skills-du-harness-fix-ci-new.md) | Skills du harness : `fix-ci`, `new-fixture`, `run-bench` | T-061, T-338, T-341, T-346 | AUTONOME | claude-sonnet-5-5 | 0022 |
| [T-348](T-348-previews-par-pr-sur-le-cluster.md) | Previews par PR sur le cluster dev homelab (TTL, frugalité, preuve publiée) | T-004, T-005, T-061, T-342, T-343 | AUTONOME + REVUE | claude-sonnet-5-5 | 0004, 0022 |
| [T-349](T-349-canari-du-harness-banc-reduit-nocturne.md) | Canari du harness : banc réduit nocturne sur main et montées épinglées de Claude Code et de l'action | T-061, T-120, T-343, T-346 | REVUE | claude-sonnet-5-5 | 0016, 0022 |
| [T-350](T-350-voie-deepseek-spike-de-compatibilite-et.md) | Voie DeepSeek : spike de compatibilité et critère d'admission par le banc | T-061, T-164, T-311, T-346, T-386, T-388 | REVUE + MANDAT | claude-sonnet-5-5 | 0018, 0022 |
| [T-352](T-352-boucle-d-amelioration-du-harness-journal.md) | Boucle d'amélioration du harness : journal d'échecs, règle « deux fois = hook ou test », revue mensuelle | T-061, T-340, T-346 | AUTONOME | claude-sonnet-5-5 | 0012, 0022 |
| [T-367](T-367-runners-arc-sur-le-cluster-lab.md) | Runners ARC sur le cluster lab pour la CI du dépôt (sans Docker, éphémères) | T-061, T-215, T-311, T-343, T-363 | REVUE + MANDAT | claude-sonnet-5-5 | 0002, 0017 |
| [T-372](T-372-plan-oke-a-deux-nuds-2.md) | Plan OKE à deux nœuds 2/12 (conditionnel) : pool, volumes, IP de pods | T-061, T-140, T-364 | MANDAT | claude-sonnet-5-5 | 0003, 0017 |
| [T-382](T-382-route-py-regles-backlog-routing-yaml.md) | route.py : règles backlog/routing.yaml et résolution d'un modèle par ticket | T-008, T-061 | REVUE | claude-sonnet-5-5 | 0023 |
| [T-386](T-386-etalonnage-matrice-haiku-sonnet-opus-sur.md) | Étalonnage : matrice Haiku / Sonnet / Opus sur le banc d'intentions et sur 30 tickets rejoués | T-044, T-061, T-323, T-346 | AUTONOME | claude-sonnet-5-5 | 0013, 0023 |
| [T-388](T-388-registre-des-modeles-et-tarifs-docs.md) | Registre des modèles et tarifs : docs/state/model-prices.yaml avec date de lecture et lint à 90 jours (sources DeepSeek déjà lues) | T-061 | AUTONOME + MANDAT | claude-sonnet-5-5 | 0017, 0023 |
| [T-389](T-389-agentgateway-fournisseur-deepseek-cles-virtuelle.md) | agentgateway : fournisseur DeepSeek, clés virtuelles par usage, budget bloquant (fournisseur factice d'abord) | T-023, T-061, T-161, T-388 | REVUE + MANDAT | claude-sonnet-5-5 | 0018, 0023 |
| [T-390](T-390-garde-de-confidentialite-aucun-log-de.md) | Garde de confidentialité : aucun log de production ni secret vers un fournisseur autre qu'Anthropic | T-025, T-061, T-389 | REVUE | claude-opus-5-5 | 0008, 0018, 0023 |
| [T-392](T-392-revue-trimestrielle-du-routage-retraits-de.md) | Revue trimestrielle du routage : retraits de modèles, nouveaux modèles, dérive des tarifs | T-061, T-323, T-388 | AUTONOME | claude-sonnet-5-5 | 0016, 0023 |
