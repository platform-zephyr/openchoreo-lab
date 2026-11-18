# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus n°2 et des arbitrages de Paul** (`docs/review/CONSENSUS-2.md`, 2026-11-18 ; résumé :
`backlog/INTEGRATION-3.md`), après le consensus n°1 (`docs/review/CONSENSUS.md`) et l'intégration 2. Objectif de Paul : finir
vite avec un maximum d'agents en parallèle ; la sécurité de développement est réduite, **seule la sécurité finale compte**
(étape FINAL).

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** en mono-cluster (ADR-0020 amendé), puis des
   **incréments** (I1 → I8), puis le **durcissement final** (FINAL) avant de déclarer la plateforme finie. Une étape peut
   démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : pilote à N=3 sur une liste figée de 20 tickets ; paliers 3 → 6 → 10 décidés par Paul (ADR-0021) ; au plus
   2 agents par couloir, 1 sur `contrat-appgen` avant T-214 ; aucun chevauchement de périmètre (T-314).
4. **Modèle** (ADR-0023, 3 règles) : noyau (chemins CODEOWNERS, `docs/adr/`, `docs/review/`) → opus/high ; texte hors noyau →
   haiku/medium + revue Sonnet ; reste → sonnet/high. Le dispatcher recalcule depuis les chemins et ignore un `model:` sous le plancher.
5. **Règle d'usine** (ADR-0021) : avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
6. **MVP** = une app A sur le homelab (VM lab, CP OpenChoreo sur le homelab), en prod, livrée à partir d'une phrase, avec
   preuve datée sans coordinateur. DeepSeek : après le chantier.

## Gestes de Paul

MANDAT = geste de Paul (accès, identité, dépense, VM) ; REVUE = approbation d'une PR du noyau. Ordre = vague.

| Étape | Gestes (MANDAT) | Approbations (REVUE) |
|---|---|---|
| S0 | [T-061](T-061-aligner-mission-adr.md), [T-061b](T-061b-acter-autres-adr.md), [T-301](T-301-reecriture-de-l-historique-et-purge.md) | [T-008](T-008-lint-backlog.md), [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md), [T-210](T-210-dispatcher-agents.md), [T-302](T-302-corrections-de-l-arbre-detail-residuel.md), [T-311](T-311-gouverneur-de-quota-ledger-5-h.md), [T-330](T-330-reglages-de-projet-claude-settings-json.md), [T-313](T-313-executant-claude-agent-yml-par-workflow.md) |
| S1 | [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md), [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md), [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md), [T-366](T-366-bundle-multi-arch-installateur-lab.md), [T-362](T-362-isolation-reseau-de-la-vm-lab.md), [T-322](T-322-calibrage-du-quota-pilote-24-h.md), [T-363](T-363-socle-de-la-plateforme-sur-la.md), [T-315](T-315-merge-automatique-sous-conditions-app-de.md), [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md), [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md), [T-005](T-005-preuve-runtime-auto.md), [T-006](T-006-mcp-cloudflare-access.md) | [T-001](T-001-integrer-pr8-security-bundle.md), [T-002](T-002-ci-k3d.md), [T-041](T-041-context-engineering.md), [T-216](T-216-ci-registre.md), [T-217](T-217-vap-default-deny.md), [T-337](T-337-definition-of-done-executable-verify-par.md), [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md), [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md), [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md), [T-314](T-314-dispatcher-planifie-cron-15-min-et.md), [T-321](T-321-revue-independante-automatique-avant-merge-model.md), [T-326](T-326-ledger-quota-disjoncteur.md) |
| S2 |  | [T-062](T-062-lab-platform-auto.md), [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) |
| S3 | [T-140](T-140-cost-1.md), [T-031](T-031-placement-coupure.md) | [T-070](T-070-garde-contrat.md), [T-368](T-368-garde-fous-de-capacite-du-homelab.md) |
| PORTE | [T-211](T-211-porte-openchoreo.md) |  |
| I1 | [T-026](T-026-sauvegardes.md) | [T-069](T-069-vap-data-class.md) |
| I2 | [T-022](T-022-spike-openbao.md), [T-164](T-164-ai-5.md), [T-185](T-185-ids-6.md), [T-023](T-023-secrets-generate-provided.md), [T-218](T-218-acter-adr-0014-0019.md) | [T-060](T-060-residu-kgateway.md), [T-183](T-183-ids-4.md), [T-184](T-184-ids-5.md), [T-186](T-186-ids-7.md), [T-189](T-189-ids-10.md) |
| I3 | [T-021](T-021-reseau-egress-imds.md) |  |
| I4 | [T-107](T-107-obs-7.md), [T-109](T-109-obs-9.md), [T-106](T-106-obs-6.md), [T-065](T-065-sante-periodique-alertes.md), [T-147](T-147-cost-8.md) |  |
| I5 | [T-132](T-132-upg-13.md) | [T-120](T-120-upg-1.md), [T-122](T-122-upg-3.md), [T-124](T-124-upg-5.md) |
| I6 | [T-181](T-181-ids-2.md), [T-194](T-194-ids-15.md), [T-195](T-195-ids-16.md), [T-193](T-193-ids-14.md) |  |
| I7 | [T-160](T-160-ai-1.md), [T-171](T-171-ai-12.md) | [T-161](T-161-ai-2.md), [T-166](T-166-ai-7.md), [T-163](T-163-ai-4.md) |
| I8 |  | [T-201](T-201-data-2.md) |
| FINAL | [T-215](T-215-pack-identite.md), [T-121](T-121-upg-2.md), [T-400](T-400-retrait-bypass-admin-ruleset.md), [T-401](T-401-revue-securite-finale.md) | [T-007](T-007-test-noyau-codeowners.md) |

Gestes purement humains (aucun agent) : [T-301](T-301-reecriture-de-l-historique-et-purge.md) Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique)

## Lancement 24/7

Pilote de **24 h à N=3** en dispatch manuel ([T-322](T-322-calibrage-du-quota-pilote-24-h.md)) : coût par ticket, % de quota 5 h et hebdomadaire, concurrence cloud ; puis paliers 6 et 10 décidés par Paul. Il ne dépend ni de T-215 ni du ruleset (FINAL), ni de la réécriture de l'historique (T-301, geste de Paul hors chemin critique).

### Prérequis : S0 minimal (8 tickets)

| Ticket | Titre | Vague | Classe | Modèle |
|---|---|---|---|---|
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | 0 | REVUE | opus/high |
| [T-061](T-061-aligner-mission-adr.md) | Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote) | 0 | MANDAT | opus/high |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | 0 | REVUE | opus/high |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins) | 1 | REVUE | opus/high |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | 1 | REVUE | opus/high |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 | 1 | REVUE | opus/high |
| [T-330](T-330-reglages-de-projet-claude-settings-json.md) | Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie | 1 | REVUE | opus/high |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1 | 2 | REVUE | opus/high |

### Liste figée du pilote (20 tickets, aucun autre lancement pendant le pilote)

| Ticket | Titre | Étape | Classe | Modèle | Dépend de (hors S0) |
|---|---|---|---|---|---|
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | S1 | REVUE | opus/high | — |
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | S1 | AUTONOME | sonnet/high | — |
| [T-332](T-332-commande-unique-tools-dev-check-static.md) | Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée | S1 | AUTONOME | opus/high | — |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | S1 | REVUE | opus/high | — |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | S3 | AUTONOME | sonnet/high | — |
| [T-325](T-325-assistant-des-gestes-humains-une-seance.md) | Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT | S1 | AUTONOME | sonnet/high | — |
| [T-326](T-326-ledger-quota-disjoncteur.md) | Ledger de quota 5 h et hebdomadaire, seuils 70/85/100 % et disjoncteur (construit pendant le pilote) | S1 | REVUE | opus/high | — |
| [T-337](T-337-definition-of-done-executable-verify-par.md) | Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée | S1 | REVUE | opus/high | T-332 |
| [T-365](T-365-capacites-du-cluster-homelab-clusters-homelab.md) | Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno | S1 | AUTONOME | sonnet/high | T-214 |
| [T-338](T-338-pack-de-fixtures-et-donnees-synthetiques.md) | Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo) | S1 | AUTONOME | sonnet/high | T-002, T-332 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | S3 | REVUE | opus/high | T-002 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | S1 | REVUE | opus/high | T-002 |
| [T-345](T-345-agent-dans-un-conteneur-durci-devcontainer.md) | Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité | S2 | AUTONOME | sonnet/high | T-332 |
| [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md) | Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop | S1 | REVUE | opus/high | T-332 |
| [T-340](T-340-protocole-d-echec-et-de-reprise.md) | Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket` | S1 | AUTONOME | opus/high | T-337 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | S1 | REVUE | opus/high | T-002 |
| [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md) | Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager` | S1 | REVUE | opus/high | T-337 |
| [T-321](T-321-revue-independante-automatique-avant-merge-model.md) | Revue indépendante automatique avant merge (modèle différent, lecture seule) | S1 | REVUE | opus/high | T-002 |
| [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) | Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission | S1 | REVUE | opus/high | — |
| [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) | Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle | S1 | AUTONOME | sonnet/high | T-314 |

Après le pilote : activation du cron T-314, puis [T-315](T-315-merge-automatique-sous-conditions-app-de.md) (S1), [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) (S1), [T-006](T-006-mcp-cloudflare-access.md) (S1).

## Chemin critique (11 vagues)

[T-061](T-061-aligner-mission-adr.md) → [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) → [T-362](T-362-isolation-reseau-de-la-vm-lab.md) → [T-363](T-363-socle-de-la-plateforme-sur-la.md) → [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) → [T-005](T-005-preuve-runtime-auto.md) → [T-023](T-023-secrets-generate-provided.md) → [T-161](T-161-ai-2.md) → [T-162](T-162-ai-3.md) → [T-163](T-163-ai-4.md) → [T-168](T-168-ai-9.md)

Jusqu'à la porte (9 vagues) : [T-061](T-061-aligner-mission-adr.md) → [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) → [T-362](T-362-isolation-reseau-de-la-vm-lab.md) → [T-363](T-363-socle-de-la-plateforme-sur-la.md) → [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) → [T-005](T-005-preuve-runtime-auto.md) → [T-015](T-015-golden-path-ntfy.md) → [T-044](T-044-banc-intentions.md) → [T-211](T-211-porte-openchoreo.md)

## Répartition des modèles (tickets `todo`)

| Étape | haiku | sonnet | opus | humain |
|---|---|---|---|---|
| S0 | 0 | 0 | 9 | 1 |
| S1 | 0 | 14 | 19 | 0 |
| S2 | 0 | 2 | 2 | 0 |
| S3 | 0 | 6 | 5 | 0 |
| PORTE | 0 | 0 | 1 | 0 |
| I1 | 0 | 5 | 2 | 0 |
| I1bis | 0 | 1 | 0 | 0 |
| I2 | 1 | 3 | 8 | 0 |
| I3 | 0 | 3 | 1 | 0 |
| I4 | 0 | 7 | 1 | 0 |
| I5 | 0 | 2 | 5 | 0 |
| I6 | 0 | 4 | 2 | 0 |
| I7 | 0 | 5 | 4 | 0 |
| I8 | 0 | 0 | 3 | 0 |
| FINAL | 0 | 1 | 5 | 0 |

## S0 — MVP — S0 minimal du pilote 24 h (garde de fuite, ADR, exécutant, dispatcher, PAUSE, réglages) (10 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | 0 | ci | REVUE | opus/high | oui | 14 |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | 0 | ci | REVUE | opus/high | oui | 4 |
| [T-061](T-061-aligner-mission-adr.md) | Acter ADR-0002 et ADR-0021 réduit, aligner MISSION et STATE (T-061a, prérequis du pilote) | 0 | gouvernance | MANDAT | opus/high |  | 109 |
| [T-061b](T-061b-acter-autres-adr.md) | Acter les autres ADR (0001, 0003-0006, 0010-0013, 0020, 0022, 0023) et les amendements du consensus n°2 (T-061b) | 0 | gouvernance | MANDAT | opus/high |  | 89 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher minimal : next.py (prêts, classe et modèle recalculés depuis les chemins) | 1 | ci | REVUE | opus/high | oui | 9 |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur minimal : kill-switch factory/PAUSE et concurrence 3 | 1 | agents | REVUE | opus/high | oui | 8 |
| [T-330](T-330-reglages-de-projet-claude-settings-json.md) | Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie | 1 | agents-harness | REVUE | opus/high | oui | 4 |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | 1 | gouvernance | REVUE | opus/high |  | 2 |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml minimal : workflow_dispatch(ticket, modèle, effort), mission-result.v1 | 2 | ci | REVUE | opus/high | oui | 7 |
| [T-301](T-301-reecriture-de-l-historique-et-purge.md) | Réécriture de l'historique par Paul avec un agent Claude local (hors chemin critique) | 2 | gouvernance | MANDAT | humain/none |  | 0 |

## S1 — MVP — pilote 24 h, VM lab, moteur OpenChoreo (CP sur le homelab), accès des agents cloud (33 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | 0 | socle-oke | REVUE | opus/high | oui | 66 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | 0 | ci | REVUE | opus/high | oui | 57 |
| [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md) | Mesures du homelab avant dimensionnement (lecture seule) | 0 | hybride | AUTONOME + MANDAT | opus/high | oui | 47 |
| [T-332](T-332-commande-unique-tools-dev-check-static.md) | Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée | 0 | dev-factory | AUTONOME | opus/high | oui | 8 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | 0 | connaissance | REVUE | opus/high | oui | 4 |
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | 1 | contrat-appgen | AUTONOME | sonnet/high | oui | 45 |
| [T-366](T-366-bundle-multi-arch-installateur-lab.md) | Bundle de sécurité multi-arch et installateur pour le cluster lab | 1 | socle-lab | REVUE + MANDAT | opus/high | oui | 40 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | 1 | preuve | AUTONOME | sonnet/high | oui | 37 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | 1 | contrat-appgen | AUTONOME | sonnet/high | oui | 30 |
| [T-337](T-337-definition-of-done-executable-verify-par.md) | Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée | 1 | backlog-outils | REVUE | opus/high | oui | 2 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | 1 | ci | REVUE | opus/high | oui | 1 |
| [T-325](T-325-assistant-des-gestes-humains-une-seance.md) | Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT | 1 | connaissance | AUTONOME | sonnet/high | oui | 0 |
| [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md) | Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets réseau | 1 | agents-harness | AUTONOME + MANDAT | sonnet/high | oui | 0 |
| [T-338](T-338-pack-de-fixtures-et-donnees-synthetiques.md) | Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo) | 1 | tests-fixtures | AUTONOME | sonnet/high | oui | 0 |
| [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) | VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops) | 1 | hybride | MANDAT | sonnet/high |  | 46 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | 1 | securite | REVUE | opus/high |  | 0 |
| [T-365](T-365-capacites-du-cluster-homelab-clusters-homelab.md) | Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno | 2 | contrat-appgen | AUTONOME | sonnet/high | oui | 42 |
| [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md) | Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop | 2 | agents-harness | REVUE | opus/high | oui | 0 |
| [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md) | Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins | 2 | ci | AUTONOME + REVUE | opus/high | oui | 0 |
| [T-340](T-340-protocole-d-echec-et-de-reprise.md) | Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket` | 2 | agents-harness | AUTONOME | opus/high | oui | 0 |
| [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md) | Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager` | 2 | agents-harness | REVUE | opus/high | oui | 0 |
| [T-362](T-362-isolation-reseau-de-la-vm-lab.md) | Isolation réseau de la VM lab (UniFi, pare-feu) | 2 | hybride | MANDAT | sonnet/high |  | 45 |
| [T-363](T-363-socle-de-la-plateforme-sur-la.md) | Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stockage) | 3 | socle-lab | REVUE + MANDAT | sonnet/high | oui | 44 |
| [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) | Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission | 3 | ci | REVUE | opus/high | oui | 2 |
| [T-321](T-321-revue-independante-automatique-avant-merge-model.md) | Revue indépendante automatique avant merge (modèle différent, lecture seule) | 3 | ci | REVUE | opus/high | oui | 1 |
| [T-322](T-322-calibrage-du-quota-pilote-24-h.md) | Calibrage du quota : pilote 24 h à N=3, puis 6, puis 8-10, et décision Max/Ultra | 3 | agents | AUTONOME + MANDAT | opus/high | oui | 0 |
| [T-326](T-326-ledger-quota-disjoncteur.md) | Ledger de quota 5 h et hebdomadaire, seuils 70/85/100 % et disjoncteur (construit pendant le pilote) | 3 | agents | REVUE | opus/high |  | 0 |
| [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) | OpenChoreo CP + DP sur la VM lab (CP définitif, D11) et ClusterDataPlane homelab | 4 | hybride | REVUE + MANDAT | sonnet/high | oui | 39 |
| [T-315](T-315-merge-automatique-sous-conditions-app-de.md) | Merge automatique sous conditions : auto-merge natif pendant le dev, App de merge en FINAL | 4 | gouvernance | REVUE + MANDAT | opus/high | oui | 0 |
| [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) | Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle | 4 | agents | AUTONOME | sonnet/high | oui | 0 |
| [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) | ntfy seulement si nécessaire et résumé quotidien unique | 4 | observabilité | AUTONOME + MANDAT | opus/high |  | 0 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | 5 | preuve | AUTONOME + REVUE + MANDAT | sonnet/high | oui | 28 |
| [T-006](T-006-mcp-cloudflare-access.md) | Accès des agents cloud à la plateforme du homelab : lecture MCP/API OpenChoreo et statut des apps (lecture seule) | 5 | acces-mcp | REVUE + MANDAT | sonnet/high |  | 0 |

## S2 — MVP — second moteur (plain), travailleur homelab, mesures (4 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-345](T-345-agent-dans-un-conteneur-durci-devcontainer.md) | Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité | 2 | dev-factory | AUTONOME | sonnet/high |  | 0 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | 4 | socle-oke | REVUE | opus/high | oui | 1 |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | 4 | moteur-plain | AUTONOME | sonnet/high |  | 2 |
| [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) | Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR d'agents | 5 | socle-oke | REVUE | opus/high | oui | 0 |

## S3 — MVP — golden path, intentions, banc et étalonnage (11 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | 1 | contrat-appgen | AUTONOME | opus/high | oui | 13 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | 1 | ci | REVUE | opus/high | oui | 0 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | 1 | coût | AUTONOME + MANDAT | opus/high |  | 6 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | 1 | migration | AUTONOME | sonnet/high |  | 0 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | 2 | intention | AUTONOME | sonnet/high |  | 7 |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | 2 | contrat-appgen | AUTONOME | sonnet/high |  | 1 |
| [T-368](T-368-garde-fous-de-capacite-du-homelab.md) | Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné | 4 | coût | AUTONOME + REVUE | opus/high |  | 0 |
| [T-031](T-031-placement-coupure.md) | Test de reprise du cluster lab (critère C4 révisé) | 5 | hybride | AUTONOME + MANDAT | sonnet/high |  | 5 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | 6 | intention | AUTONOME | opus/high | oui | 8 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | 6 | apps | AUTONOME | sonnet/high |  | 7 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | 7 | intention | AUTONOME | sonnet/high |  | 3 |

## PORTE — Porte d'adoption OpenChoreo (2026-12-04) (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo en mono-cluster : mesurer C1-C5 et décision de Paul (2026-12-04) | 8 | gouvernance | MANDAT | opus/high |  | 1 |

## I1 — Données (7 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | 1 | contrat-appgen | AUTONOME | sonnet/high |  | 10 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | 2 | securite | REVUE | opus/high |  | 0 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | 5 | donnees | AUTONOME + MANDAT | sonnet/high |  | 7 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | 5 | donnees | AUTONOME | sonnet/high |  | 5 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | 6 | contrat-appgen | AUTONOME | sonnet/high |  | 5 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | 6 | contrat-appgen | AUTONOME | opus/high |  | 0 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | 7 | donnees | AUTONOME | sonnet/high |  | 4 |

## I1bis — Archétypes D et E (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | 2 | contrat-appgen | AUTONOME | sonnet/high |  | 0 |

## I2 — Secrets et identité (12 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | 1 | identité-secrets/authentik | MANDAT | opus/high | oui | 6 |
| [T-022](T-022-spike-openbao.md) | OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill | 1 | secrets | AUTONOME + MANDAT | sonnet/high |  | 21 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | 1 | socle-oke | REVUE | opus/high |  | 10 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | 1 | identité-secrets/inventaire | AUTONOME + REVUE | opus/high |  | 10 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | 1 | identité-agents | REVUE + MANDAT | opus/high |  | 6 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | 1 | contrat-appgen | AUTONOME | sonnet/high |  | 5 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | 2 | identité-secrets/openbao | AUTONOME + REVUE | opus/high | oui | 9 |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | 2 | identité-secrets/utilisateurs | REVUE | opus/high |  | 0 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | 3 | identité-secrets/apps | REVUE | opus/high | oui | 4 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | 6 | secrets | AUTONOME + REVUE + MANDAT | sonnet/high |  | 9 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | 7 | intention | AUTONOME | haiku/medium |  | 0 |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | 9 | gouvernance | MANDAT | opus/high |  | 0 |

## I3 — Exposition, admission, première app familiale (4 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | 4 | exposition | AUTONOME | sonnet/high |  | 0 |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | 5 | securite | AUTONOME | sonnet/high |  | 7 |
| [T-021](T-021-reseau-egress-imds.md) | Egress déclaré (FQDN Cilium) et IMDS refusé dans toutes les cellules | 5 | securite | AUTONOME + MANDAT | opus/high |  | 3 |
| [T-051](T-051-premiere-app-familiale.md) | Première app familiale complète (OIDC + base + sauvegarde) sur le homelab | 8 | apps | AUTONOME | sonnet/high |  | 2 |

## I4 — Exploitation : observabilité, remédiation, ntfy (8 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-100](T-100-obs-0.md) | Contrat d'alerte, règles génériques et runbooks lisibles par agent | 2 | observabilité | AUTONOME | sonnet/high | oui | 4 |
| [T-101](T-101-obs-1.md) | Collecte : Alloy de kube-ops réutilisé, budget de séries, sondes depuis healthPath | 2 | observabilité | AUTONOME | sonnet/high |  | 0 |
| [T-107](T-107-obs-7.md) | Escalade ntfy : contact points, script de notification, route différée | 3 | remédiation | AUTONOME + MANDAT | sonnet/high |  | 2 |
| [T-109](T-109-obs-9.md) | Santé de la plateforme : control plane, Argo, OpenBao, ESO, CNPG, agents de data plane | 5 | plateforme-santé | AUTONOME + MANDAT | sonnet/high |  | 0 |
| [T-106](T-106-obs-6.md) | Pont alerte -> agent : workflow remediate, dédoublonnage, budget, disjoncteur | 6 | remédiation | REVUE + MANDAT | opus/high | oui | 1 |
| [T-065](T-065-sante-periodique-alertes.md) | CronJob de statut périodique (réduit : sondes → T-103, revert → T-106, ntfy → T-107) | 7 | preuve | AUTONOME + MANDAT | sonnet/high |  | 2 |
| [T-111](T-111-obs-11.md) | Drill de bout en bout : échec d'app -> alerte -> agent -> PR ou ntfy | 7 | remédiation | AUTONOME | sonnet/high |  | 0 |
| [T-147](T-147-cost-8.md) | Alertes de coût : relier billing_cost_eur et cost-evidence à ntfy, règle de fraîcheur | 8 | alertes | AUTONOME + MANDAT | sonnet/high |  | 0 |

## I5 — Montées de version (7 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | 1 | renovate | REVUE | opus/high | oui | 8 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | 2 | porte | AUTONOME + REVUE | opus/high | oui | 6 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | 2 | k8s-os | AUTONOME + MANDAT | opus/high |  | 0 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | 3 | supply-chain | AUTONOME | sonnet/high |  | 2 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | 6 | porte | AUTONOME + REVUE | opus/high | oui | 1 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | 7 | porte | AUTONOME | opus/high |  | 0 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | 8 | stateful | AUTONOME | sonnet/high |  | 0 |

## I6 — Migration Doppler, rotation, audit (6 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | 3 | identité-secrets/migration | AUTONOME | sonnet/high |  | 4 |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | 4 | identité-secrets/migration | MANDAT | sonnet/high |  | 3 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | 5 | identité-secrets/rotation | MANDAT | opus/high |  | 0 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | 8 | identité-secrets/audit | AUTONOME + MANDAT | opus/high |  | 0 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | 9 | identité-secrets/migration | AUTONOME | sonnet/high |  | 1 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | 10 | identité-secrets/doppler | MANDAT | sonnet/high |  | 0 |

## I7 — Services IA (homelab) (9 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-160](T-160-ai-1.md) | gVisor et vcluster jetables pour les agents sur le cluster lab | 5 | sandbox | AUTONOME + MANDAT | sonnet/high |  | 3 |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | 7 | ai-gateway | REVUE | opus/high | oui | 7 |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | 8 | appgen | AUTONOME | sonnet/high | oui | 3 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | 8 | mcp | REVUE | sonnet/high |  | 2 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | 8 | observabilité-ia | AUTONOME | sonnet/high |  | 1 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | 9 | admission | REVUE | opus/high |  | 2 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | 9 | contexte | AUTONOME | opus/high |  | 0 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | 10 | sandbox | AUTONOME | opus/high |  | 0 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | 10 | apps-ia | AUTONOME + MANDAT | sonnet/high |  | 0 |

## I8 — Mesure (DORA, maturité) (3 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | 1 | données | REVUE | opus/high | oui | 2 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | 2 | données | AUTONOME | opus/high |  | 0 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | 6 | données | AUTONOME | opus/high |  | 0 |

## FINAL — Durcissement final (obligatoire avant « plateforme finie ») (6 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-215](T-215-pack-identite.md) | Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1 | 1 | gouvernance | REVUE + MANDAT | opus/high | oui | 4 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | 2 | ci | REVUE | opus/high | oui | 2 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | 2 | renovate | REVUE + MANDAT | opus/high | oui | 0 |
| [T-400](T-400-retrait-bypass-admin-ruleset.md) | Retirer le contournement admin du ruleset (bypass_actors) et écrire la procédure de réactivation ponctuelle | 3 | gouvernance | REVUE + MANDAT | opus/high |  | 1 |
| [T-402](T-402-garde-image-multi-arch.md) | Garde d'image multi-arch pour les apps éligibles aux deux clusters (homelab x86_64, OKE arm64) | 4 | contrat-appgen | AUTONOME | sonnet/high |  | 1 |
| [T-401](T-401-revue-securite-finale.md) | Revue de sécurité finale de la plateforme (prérequis de « plateforme finie ») | 5 | gouvernance | MANDAT | opus/high |  | 0 |

## Gelés jusqu'à la porte ou bloqués par un déclencheur (46)

[T-013](T-013-overrides-dependances.md) (deferred), [T-014](T-014-archetype-e-helm-durci.md) (deferred), [T-029](T-029-spike-crossplane.md) (blocked), [T-030](T-030-dataplane-homelab.md) (deferred), [T-042](T-042-atlas-route-intent.md) (deferred), [T-052](T-052-retrait-kube-ops.md) (deferred), [T-063](T-063-dr-plateforme.md) (deferred), [T-073](T-073-dependances-apps.md) (deferred), [T-076](T-076-access-par-app.md) (blocked), [T-077](T-077-banc-intentions-complet.md) (deferred), [T-126](T-126-upg-7.md) (deferred), [T-127](T-127-upg-8.md) (deferred), [T-128](T-128-upg-9.md) (deferred), [T-129](T-129-upg-10.md) (deferred), [T-130](T-130-upg-11.md) (deferred), [T-133](T-133-upg-14.md) (deferred), [T-134](T-134-upg-15.md) (deferred), [T-135](T-135-upg-16.md) (deferred), [T-136](T-136-upg-17.md) (deferred), [T-137](T-137-upg-18.md) (deferred), [T-138](T-138-upg-19.md) (deferred), [T-205](T-205-data-6.md) (deferred), [T-206](T-206-data-7.md) (deferred), [T-207](T-207-data-8.md) (deferred), [T-208](T-208-data-9.md) (deferred), [T-213](T-213-argo-unique-oke.md) (deferred), [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md) (deferred), [T-319](T-319-pool-remote-control-sur-le-homelab.md) (deferred), [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md) (deferred), [T-323](T-323-observabilite-de-l-usine-indicateurs-tableau.md) (deferred), [T-342](T-342-spike-3-jours-cluster-dev-homelab.md) (deferred), [T-343](T-343-spike-runners-homelab-pour-le-depot.md) (deferred), [T-346](T-346-banc-d-essai-des-taches-de.md) (deferred), [T-347](T-347-skills-du-harness-fix-ci-new.md) (deferred), [T-348](T-348-previews-par-pr-sur-le-cluster.md) (deferred), [T-349](T-349-canari-du-harness-banc-reduit-nocturne.md) (deferred), [T-350](T-350-voie-deepseek-spike-de-compatibilite-et.md) (deferred), [T-352](T-352-boucle-d-amelioration-du-harness-journal.md) (deferred), [T-367](T-367-runners-arc-sur-le-cluster-lab.md) (blocked), [T-372](T-372-plan-oke-a-deux-nuds-2.md) (blocked), [T-382](T-382-route-py-regles-backlog-routing-yaml.md) (deferred), [T-386](T-386-etalonnage-matrice-haiku-sonnet-opus-sur.md) (deferred), [T-388](T-388-registre-des-modeles-et-tarifs-docs.md) (deferred), [T-389](T-389-agentgateway-fournisseur-deepseek-cles-virtuelle.md) (deferred), [T-390](T-390-garde-de-confidentialite-aucun-log-de.md) (deferred), [T-392](T-392-revue-trimestrielle-du-routage-retraits-de.md) (deferred)


## Absorbés ou supprimés (27)

[T-009](T-009-budget-oke-mesure.md), [T-024](T-024-identite-oidc-declaree.md), [T-064](T-064-mises-a-jour.md), [T-066](T-066-rotation-secrets.md), [T-068](T-068-securite-agents.md), [T-102](T-102-obs-2.md), [T-103](T-103-obs-3.md), [T-104](T-104-obs-4.md), [T-105](T-105-obs-5.md), [T-108](T-108-obs-8.md), [T-110](T-110-obs-10.md), [T-112](T-112-obs-12.md), [T-141](T-141-cost-2.md), [T-142](T-142-cost-3.md), [T-143](T-143-cost-4.md), [T-144](T-144-cost-5.md), [T-145](T-145-cost-6.md), [T-146](T-146-cost-7.md), [T-169](T-169-ai-10.md), [T-170](T-170-ai-11.md), [T-182](T-182-ids-3.md), [T-187](T-187-ids-8.md), [T-188](T-188-ids-9.md), [T-191](T-191-ids-12.md), [T-202](T-202-data-3.md), [T-209](T-209-data-10.md), [T-300](T-300-rendre-le-depot-prive-le-temps.md)
