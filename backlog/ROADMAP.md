# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus avec la revue adverse** (`docs/review/CONSENSUS.md`) et de l'**intégration 2**
(`backlog/INTEGRATION-2.md`, 2026-11-18 soir). Objectif de Paul : finir le plus vite possible avec un maximum d'agents en
parallèle ; ce qui accélère passe devant (harness, dispatcher, identité, garde de fuite en S0/S1).

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** (ADR-0020), puis des **incréments** (I1 → I9) dont un
   ou deux sont ouverts à la fois. Une étape peut démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : plafond de départ 4 agents (T-210), relevé par la mesure du pilote (T-322) ; au plus 2 par couloir,
   1 sur `contrat-appgen` avant T-214 ; aucun chevauchement de périmètre (T-210).
4. **Modèle** : colonne « Modèle » = `model/effort` de l'en-tête, issu de la première règle de routage qui s'applique
   (`backlog/proposals/model-routing.yaml`, ADR-0023 proposé) ; un modèle proposé ne fait que monter au-dessus du plancher.
5. **Gestes de Paul par lot** : une séance par étape (liste ci-dessous, assistant T-325). Les agents préparent les PR et les demandes exactes.
6. **MVP** = une app A sur le homelab (VM lab), en prod, livrée à partir d'une phrase, avec preuve datée sans coordinateur.

## Gestes de Paul

MANDAT = geste de Paul (accès, identité, dépense, VM) ; REVUE = approbation d'une PR du noyau. Ordre = vague.

| Étape | Gestes (MANDAT) | Approbations (REVUE) |
|---|---|---|
| S0 | [T-061](T-061-aligner-mission-adr.md), [T-215](T-215-pack-identite.md), [T-300](T-300-rendre-le-depot-prive-le-temps.md), [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md), [T-311](T-311-gouverneur-de-quota-ledger-5-h.md), [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md), [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md), [T-301](T-301-reecriture-de-l-historique-et-purge.md), [T-362](T-362-isolation-reseau-de-la-vm-lab.md) | [T-001](T-001-integrer-pr8-security-bundle.md), [T-002](T-002-ci-k3d.md), [T-008](T-008-lint-backlog.md), [T-041](T-041-context-engineering.md), [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md), [T-007](T-007-test-noyau-codeowners.md), [T-217](T-217-vap-default-deny.md), [T-302](T-302-corrections-de-l-arbre-detail-residuel.md), [T-330](T-330-reglages-de-projet-claude-settings-json.md), [T-382](T-382-route-py-regles-backlog-routing-yaml.md), [T-210](T-210-dispatcher-agents.md), [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md), [T-313](T-313-executant-claude-agent-yml-par-workflow.md) |
| S1 | [T-363](T-363-socle-de-la-plateforme-sur-la.md), [T-322](T-322-calibrage-du-quota-pilote-24-h.md), [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md), [T-005](T-005-preuve-runtime-auto.md), [T-315](T-315-merge-automatique-sous-conditions-app-de.md), [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) | [T-337](T-337-definition-of-done-executable-verify-par.md), [T-216](T-216-ci-registre.md), [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md), [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md), [T-314](T-314-dispatcher-planifie-cron-15-min-et.md), [T-321](T-321-revue-independante-automatique-avant-merge-model.md) |
| S2 | [T-388](T-388-registre-des-modeles-et-tarifs-docs.md), [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md), [T-342](T-342-spike-3-jours-cluster-dev-homelab.md), [T-343](T-343-spike-runners-homelab-pour-le-depot.md), [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md) | [T-062](T-062-lab-platform-auto.md), [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) |
| S3 | [T-140](T-140-cost-1.md), [T-031](T-031-placement-coupure.md) | [T-070](T-070-garde-contrat.md), [T-368](T-368-garde-fous-de-capacite-du-homelab.md) |
| PORTE | [T-211](T-211-porte-openchoreo.md) |  |
| I1 | [T-026](T-026-sauvegardes.md) | [T-069](T-069-vap-data-class.md), [T-348](T-348-previews-par-pr-sur-le-cluster.md) |
| I2 | [T-022](T-022-spike-openbao.md), [T-164](T-164-ai-5.md), [T-185](T-185-ids-6.md), [T-319](T-319-pool-remote-control-sur-le-homelab.md), [T-023](T-023-secrets-generate-provided.md), [T-218](T-218-acter-adr-0014-0019.md) | [T-060](T-060-residu-kgateway.md), [T-183](T-183-ids-4.md), [T-184](T-184-ids-5.md), [T-186](T-186-ids-7.md), [T-189](T-189-ids-10.md) |
| I3 | [T-021](T-021-reseau-egress-imds.md) |  |
| I4 | [T-107](T-107-obs-7.md), [T-109](T-109-obs-9.md), [T-106](T-106-obs-6.md), [T-065](T-065-sante-periodique-alertes.md), [T-147](T-147-cost-8.md) |  |
| I5 | [T-121](T-121-upg-2.md), [T-132](T-132-upg-13.md) | [T-120](T-120-upg-1.md), [T-122](T-122-upg-3.md), [T-124](T-124-upg-5.md), [T-349](T-349-canari-du-harness-banc-reduit-nocturne.md) |
| I6 | [T-181](T-181-ids-2.md), [T-194](T-194-ids-15.md), [T-195](T-195-ids-16.md), [T-193](T-193-ids-14.md) |  |
| I7 | [T-160](T-160-ai-1.md), [T-389](T-389-agentgateway-fournisseur-deepseek-cles-virtuelle.md), [T-350](T-350-voie-deepseek-spike-de-compatibilite-et.md), [T-171](T-171-ai-12.md) | [T-161](T-161-ai-2.md), [T-166](T-166-ai-7.md), [T-163](T-163-ai-4.md), [T-390](T-390-garde-de-confidentialite-aucun-log-de.md) |
| I8 |  | [T-201](T-201-data-2.md) |

Gestes purement humains (aucun agent) : [T-300](T-300-rendre-le-depot-prive-le-temps.md) Rendre le dépôt privé le temps de la purge (geste de Paul, réversible)

## Lancement 24/7

Pilote de **24 h à N=3** en dispatch manuel ([T-322](T-322-calibrage-du-quota-pilote-24-h.md)) : mesure du coût par ticket, du % de quota 5 h et hebdomadaire, de la concurrence cloud ; puis N=6, puis 8-10 si le quota hebdomadaire reste sous 70 % au jour 3. Prérequis (ordre de vague) :

| Ticket | Titre | Vague | Classe | Modèle |
|---|---|---|---|---|
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | 0 | REVUE | sonnet/high |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR 0001-0006, 0010-0013, 0020-0023 (+ amendements homelab), réaligner MISSION sur le homelab | 0 | MANDAT | opus/high |
| [T-215](T-215-pack-identite.md) | Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1 | 0 | REVUE + MANDAT | opus/high |
| [T-300](T-300-rendre-le-depot-prive-le-temps.md) | Rendre le dépôt privé le temps de la purge (geste de Paul, réversible) | 0 | MANDAT | humain/none |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | 0 | REVUE | sonnet/high |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | 1 | REVUE | sonnet/high |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | 1 | REVUE | opus/high |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur de quota : ledger 5 h et hebdomadaire, seuils, disjoncteur, kill-switch PAUSE | 1 | REVUE + MANDAT | sonnet/high |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher (cerveau) : next.py et admission — prêts, classe recalculée, couloirs, ressources exclusives, chevauchement de périmètres | 2 | REVUE | sonnet/high |
| [T-301](T-301-reecriture-de-l-historique-et-purge.md) | Réécriture de l'historique et purge des refs de PR (mailmap, détail de faille, identifiants) | 2 | MANDAT | opus/high |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml : workflow_dispatch(ticket, modèle, effort), outils étroits, journal JSON, mission-result.v1 | 3 | REVUE | sonnet/high |
| [T-322](T-322-calibrage-du-quota-pilote-24-h.md) | Calibrage du quota : pilote 24 h à N=3, puis 6, puis 8-10, et décision Max/Ultra | 4 | AUTONOME + MANDAT | sonnet/high |

Après le pilote (cron, merge armé, ntfy, reprise, revue, trieur, travailleur homelab, tableau de bord) : [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) (S1), [T-321](T-321-revue-independante-automatique-avant-merge-model.md) (S1), [T-315](T-315-merge-automatique-sous-conditions-app-de.md) (S1), [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) (S1), [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) (S1), [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md) (S2), [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md) (S2), [T-323](T-323-observabilite-de-l-usine-indicateurs-tableau.md) (S3).

## Chemin critique (11 vagues)

[T-061](T-061-aligner-mission-adr.md) → [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) → [T-362](T-362-isolation-reseau-de-la-vm-lab.md) → [T-363](T-363-socle-de-la-plateforme-sur-la.md) → [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) → [T-005](T-005-preuve-runtime-auto.md) → [T-023](T-023-secrets-generate-provided.md) → [T-161](T-161-ai-2.md) → [T-162](T-162-ai-3.md) → [T-163](T-163-ai-4.md) → [T-168](T-168-ai-9.md)

Jusqu'à la porte (9 vagues) : [T-061](T-061-aligner-mission-adr.md) → [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) → [T-362](T-362-isolation-reseau-de-la-vm-lab.md) → [T-363](T-363-socle-de-la-plateforme-sur-la.md) → [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) → [T-005](T-005-preuve-runtime-auto.md) → [T-015](T-015-golden-path-ntfy.md) → [T-044](T-044-banc-intentions.md) → [T-211](T-211-porte-openchoreo.md)

## Répartition des modèles (tickets `todo`)

| Étape | haiku | sonnet | opus | humain |
|---|---|---|---|---|
| S0 | 0 | 18 | 5 | 1 |
| S1 | 0 | 14 | 5 | 0 |
| S2 | 1 | 5 | 3 | 0 |
| S3 | 0 | 13 | 3 | 0 |
| PORTE | 0 | 0 | 1 | 0 |
| I1 | 0 | 6 | 2 | 0 |
| I1bis | 0 | 1 | 0 | 0 |
| I2 | 0 | 6 | 7 | 0 |
| I3 | 0 | 2 | 2 | 0 |
| I4 | 0 | 7 | 1 | 0 |
| I5 | 0 | 5 | 4 | 0 |
| I6 | 0 | 0 | 6 | 0 |
| I7 | 0 | 6 | 6 | 0 |
| I8 | 0 | 3 | 0 | 0 |
| I9 | 1 | 0 | 0 | 0 |

## S0 — MVP — socle de confiance, purge, identité, harness et usine (dispatch manuel) (24 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-001](T-001-integrer-pr8-security-bundle.md) | Fusionner la PR #8 (installation fail-closed avec le security bundle) | 0 | socle-oke | REVUE | sonnet/high | oui | 70 |
| [T-002](T-002-ci-k3d.md) | CI k3d jetable sur runners GitHub (PR #36) avec les 4 corrections de revue | 0 | ci | REVUE | sonnet/high | oui | 68 |
| [T-215](T-215-pack-identite.md) | Pack identité et mandat de lot : compte agent, GitHub App (dispatch, merge sous conditions), mandate.v1 | 0 | gouvernance | REVUE + MANDAT | opus/high | oui | 57 |
| [T-360](T-360-mesures-du-homelab-avant-dimensionnement-lecture.md) | Mesures du homelab avant dimensionnement (lecture seule) | 0 | hybride | AUTONOME + MANDAT | sonnet/high | oui | 56 |
| [T-008](T-008-lint-backlog.md) | Check CI des tickets `backlog/` : en-tête, graphe, étapes, champs `model` et `effort` | 0 | ci | REVUE | sonnet/high | oui | 25 |
| [T-332](T-332-commande-unique-tools-dev-check-static.md) | Commande unique `tools/dev/check` (--static, --k3d) et liste d'outils partagée | 0 | dev-factory | AUTONOME | sonnet/high | oui | 16 |
| [T-303](T-303-garde-ci-de-donnees-sensibles-gitleaks.md) | Garde CI de données sensibles (gitleaks + règles OCID, IP, e-mail, chemins, hôtes internes) | 0 | ci | REVUE | sonnet/high | oui | 12 |
| [T-041](T-041-context-engineering.md) | Context engineering : contexte en couches, AGENTS.md court, checks de fraîcheur | 0 | connaissance | REVUE | sonnet/medium | oui | 6 |
| [T-061](T-061-aligner-mission-adr.md) | Acter les ADR 0001-0006, 0010-0013, 0020-0023 (+ amendements homelab), réaligner MISSION sur le homelab | 0 | gouvernance | MANDAT | opus/high |  | 119 |
| [T-300](T-300-rendre-le-depot-prive-le-temps.md) | Rendre le dépôt privé le temps de la purge (geste de Paul, réversible) | 0 | gouvernance | MANDAT | humain/none |  | 10 |
| [T-007](T-007-test-noyau-codeowners.md) | Test CI : le noyau de `CODEOWNERS` correspond à ADR-0002 | 1 | ci | REVUE | sonnet/high | oui | 22 |
| [T-311](T-311-gouverneur-de-quota-ledger-5-h.md) | Gouverneur de quota : ledger 5 h et hebdomadaire, seuils, disjoncteur, kill-switch PAUSE | 1 | agents | REVUE + MANDAT | sonnet/high | oui | 18 |
| [T-330](T-330-reglages-de-projet-claude-settings-json.md) | Réglages de projet `.claude/settings.json` : permissions deny, mode dontAsk, sandbox, plafonds de sortie | 1 | agents-harness | REVUE | sonnet/high | oui | 4 |
| [T-382](T-382-route-py-regles-backlog-routing-yaml.md) | route.py : règles backlog/routing.yaml et résolution d'un modèle par ticket | 1 | ci | REVUE | sonnet/high | oui | 3 |
| [T-325](T-325-assistant-des-gestes-humains-une-seance.md) | Assistant des gestes humains : une séance par étape, généré depuis les tickets MANDAT | 1 | connaissance | AUTONOME | sonnet/medium | oui | 0 |
| [T-334](T-334-environnement-claude-code-cloud-openchoreo-lab.md) | Environnement Claude Code cloud « openchoreo-lab-agent » : script d'installation, réseau, secrets réseau | 1 | agents-harness | AUTONOME + MANDAT | sonnet/high | oui | 0 |
| [T-361](T-361-vm-talos-lab-dediee-sur-proxmox.md) | VM Talos « lab » dédiée sur Proxmox (cluster séparé de kube-ops) | 1 | hybride | MANDAT | sonnet/high |  | 53 |
| [T-302](T-302-corrections-de-l-arbre-detail-residuel.md) | Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets | 1 | gouvernance | REVUE | opus/high |  | 10 |
| [T-217](T-217-vap-default-deny.md) | VAP : refus d'un namespace de cellule sans NetworkPolicy default-deny | 1 | securite | REVUE | opus/high |  | 0 |
| [T-210](T-210-dispatcher-agents.md) | Dispatcher (cerveau) : next.py et admission — prêts, classe recalculée, couloirs, ressources exclusives, chevauchement de périmètres | 2 | ci | REVUE | sonnet/high | oui | 16 |
| [T-331](T-331-hooks-deterministes-garde-de-perimetre-garde.md) | Hooks déterministes : garde de périmètre, garde Bash, lint après édition, hook Stop | 2 | agents-harness | REVUE | sonnet/high | oui | 0 |
| [T-362](T-362-isolation-reseau-de-la-vm-lab.md) | Isolation réseau de la VM lab (UniFi, pare-feu) | 2 | hybride | MANDAT | sonnet/high |  | 52 |
| [T-301](T-301-reecriture-de-l-historique-et-purge.md) | Réécriture de l'historique et purge des refs de PR (mailmap, détail de faille, identifiants) | 2 | gouvernance | MANDAT | opus/high |  | 9 |
| [T-313](T-313-executant-claude-agent-yml-par-workflow.md) | Exécutant claude-agent.yml : workflow_dispatch(ticket, modèle, effort), outils étroits, journal JSON, mission-result.v1 | 3 | ci | REVUE | sonnet/high | oui | 13 |

## S1 — MVP — preuve automatique, usine en marche, moteur OpenChoreo sur la VM lab (19 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-214](T-214-appgen-modulaire.md) | Découper appgen en modules (avant le couloir contrat) | 1 | contrat-appgen | AUTONOME | sonnet/high | oui | 47 |
| [T-072](T-072-app-status-schema.md) | Schéma `app-status.v1` et `_checks` en sortie JSON stable | 1 | preuve | AUTONOME | sonnet/medium | oui | 40 |
| [T-003](T-003-env-development-promotion.md) | Environment `development`, promotion vers `production`, pins de release par environnement | 1 | contrat-appgen | AUTONOME | sonnet/high | oui | 35 |
| [T-337](T-337-definition-of-done-executable-verify-par.md) | Definition of done exécutable : `verify:` par critère et `done.py` avec preuve datée | 1 | backlog-outils | REVUE | sonnet/high | oui | 10 |
| [T-338](T-338-pack-de-fixtures-et-donnees-synthetiques.md) | Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo) | 1 | tests-fixtures | AUTONOME | sonnet/high | oui | 8 |
| [T-365](T-365-capacites-du-cluster-homelab-clusters-homelab.md) | Capacités du cluster homelab (clusters/homelab/capabilities.yaml) : arch, availability, gvisor, stockage, Kyverno | 2 | contrat-appgen | AUTONOME | sonnet/high | oui | 44 |
| [T-216](T-216-ci-registre.md) | CI extensible par registre de suites | 2 | ci | REVUE | sonnet/high | oui | 9 |
| [T-341](T-341-sous-agents-de-projet-reviewer-lecture.md) | Sous-agents de projet : `reviewer` (lecture seule) et `ci-triager` | 2 | agents-harness | REVUE | sonnet/high | oui | 1 |
| [T-363](T-363-socle-de-la-plateforme-sur-la.md) | Socle de la plateforme sur la VM lab (Cilium, Gateway API, cert-manager, ESO, Kyverno, Argo, stockage) | 3 | socle-lab | REVUE + MANDAT | opus/high | oui | 51 |
| [T-339](T-339-bibliotheque-tools-dev-cluster-k3d-ephemere.md) | Bibliothèque `tools/dev/cluster` (k3d éphémère) et job PR k3d choisi par chemins | 3 | ci | AUTONOME + REVUE | sonnet/high | oui | 8 |
| [T-340](T-340-protocole-d-echec-et-de-reprise.md) | Protocole d'échec et de reprise : journal de PR, WIP poussé, classes d'échec, skill `resume-ticket` | 3 | agents-harness | AUTONOME | opus/high | oui | 1 |
| [T-364](T-364-openchoreo-cp-dp-co-localises-sur.md) | OpenChoreo CP + DP co-localisés sur la VM lab et ClusterDataPlane homelab | 4 | hybride | REVUE + MANDAT | opus/high | oui | 43 |
| [T-314](T-314-dispatcher-planifie-cron-15-min-et.md) | Dispatcher planifié : cron 15 min et sur merge, file par couloir, boucle d'admission | 4 | ci | REVUE | sonnet/high | oui | 7 |
| [T-321](T-321-revue-independante-automatique-avant-merge-model.md) | Revue indépendante automatique avant merge (modèle différent, lecture seule) | 4 | ci | REVUE | opus/high | oui | 1 |
| [T-322](T-322-calibrage-du-quota-pilote-24-h.md) | Calibrage du quota : pilote 24 h à N=3, puis 6, puis 8-10, et décision Max/Ultra | 4 | agents | AUTONOME + MANDAT | sonnet/high | oui | 0 |
| [T-005](T-005-preuve-runtime-auto.md) | Preuve runtime automatique après sync (Job PostSync + publication) | 5 | preuve | AUTONOME + REVUE + MANDAT | sonnet/high | oui | 33 |
| [T-315](T-315-merge-automatique-sous-conditions-app-de.md) | Merge automatique sous conditions (App de merge) et merge armé pour le noyau | 5 | gouvernance | REVUE + MANDAT | opus/high | oui | 0 |
| [T-317](T-317-reprise-automatique-max-attempts-tickets-bloques.md) | Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle | 5 | agents | AUTONOME | sonnet/high | oui | 0 |
| [T-316](T-316-ntfy-seulement-si-necessaire-et-resume.md) | ntfy seulement si nécessaire et résumé quotidien unique | 5 | observabilité | AUTONOME + MANDAT | sonnet/high |  | 1 |

## S2 — MVP — second moteur (plain), travailleur homelab, mesures (9 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-388](T-388-registre-des-modeles-et-tarifs-docs.md) | Registre des modèles et tarifs : docs/state/model-prices.yaml avec date de lecture et lint à 90 jours (sources DeepSeek déjà lues) | 1 | veille | AUTONOME + MANDAT | haiku/low |  | 4 |
| [T-345](T-345-agent-dans-un-conteneur-durci-devcontainer.md) | Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité | 2 | dev-factory | AUTONOME | sonnet/high |  | 0 |
| [T-062](T-062-lab-platform-auto.md) | `lab-platform` en synchronisation automatique (hors lab-pg) | 4 | socle-oke | REVUE | sonnet/high | oui | 1 |
| [T-318](T-318-travailleur-homelab-en-tirage-sortant-claude.md) | Travailleur homelab en tirage sortant (claude -p) sur VM isolée, sans runner GitHub ni secret | 4 | hybride | REVUE + MANDAT | opus/high | oui | 1 |
| [T-342](T-342-spike-3-jours-cluster-dev-homelab.md) | Spike (3 jours) : cluster dev homelab pour agents (vcluster, VM dédiée ou namespaces) | 4 | hybride | AUTONOME + MANDAT | opus/high |  | 3 |
| [T-212](T-212-backend-plain.md) | Backend « plain » d'appgen (spike 3 jours) : chart commun + Argo par cluster | 4 | moteur-plain | AUTONOME | sonnet/high |  | 2 |
| [T-344](T-344-supprimer-le-point-chaud-lab-apps.md) | Supprimer le point chaud `lab-apps.yaml` (ApplicationSet par répertoire) et file de fusion pour PR d'agents | 5 | socle-oke | REVUE | opus/high | oui | 0 |
| [T-343](T-343-spike-runners-homelab-pour-le-depot.md) | Spike runners homelab pour le dépôt public : ARC JIT sans secret limité à `main`, ou aucun runner (preuve par Job PostSync) | 5 | hybride | REVUE + MANDAT | sonnet/high |  | 2 |
| [T-320](T-320-trieur-quotidien-tache-planifiee-cloud-en.md) | Trieur quotidien : tâche planifiée cloud en lecture seule + issue de résumé | 6 | agents | AUTONOME + MANDAT | sonnet/high |  | 0 |

## S3 — MVP — golden path, intentions, banc et étalonnage (16 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-010](T-010-probes-quota.md) | Probes depuis `healthPath` (G2) et quota de cellule dérivé (G4) | 1 | contrat-appgen | AUTONOME | opus/high | oui | 15 |
| [T-070](T-070-garde-contrat.md) | Garde du contrat : compatibilité du schéma et aucun objet Kubernetes hors `apps/`/`generated/` | 1 | ci | REVUE | sonnet/high | oui | 0 |
| [T-140](T-140-cost-1.md) | Registre des limites free tier (valeur, date, source) et lint de péremption | 1 | coût | AUTONOME + MANDAT | sonnet/medium |  | 6 |
| [T-050](T-050-verdicts-kube-ops.md) | Verdict A-F pour chaque app de kube-ops | 1 | migration | AUTONOME | sonnet/high |  | 0 |
| [T-040](T-040-recettes-apps.md) | Catalogue de recettes d'apps homelab vérifiées | 2 | intention | AUTONOME | sonnet/high |  | 9 |
| [T-004](T-004-garde-frugalite-dev.md) | Check CI de frugalité du dev | 2 | contrat-appgen | AUTONOME | sonnet/high |  | 2 |
| [T-346](T-346-banc-d-essai-des-taches-de.md) | Banc d'essai des tâches de développement (20-30 tâches, graders par code) et runner de banc | 4 | banc | AUTONOME | sonnet/high | oui | 7 |
| [T-368](T-368-garde-fous-de-capacite-du-homelab.md) | Garde-fous de capacité du homelab : quotas lab-*, alertes RAM/NVMe/Tctl, budget versionné | 4 | coût | AUTONOME + REVUE | sonnet/high |  | 0 |
| [T-347](T-347-skills-du-harness-fix-ci-new.md) | Skills du harness : `fix-ci`, `new-fixture`, `run-bench` | 5 | agents-harness | AUTONOME | opus/high | oui | 0 |
| [T-031](T-031-placement-coupure.md) | Test de reprise du cluster lab (critère C4 révisé) | 5 | hybride | AUTONOME + MANDAT | sonnet/high |  | 5 |
| [T-323](T-323-observabilite-de-l-usine-indicateurs-tableau.md) | Observabilité de l'usine : indicateurs, rapport hebdomadaire par (type de tâche, modèle), écart banc/réel, drill de panne | 5 | observabilité | AUTONOME | sonnet/high |  | 3 |
| [T-352](T-352-boucle-d-amelioration-du-harness-journal.md) | Boucle d'amélioration du harness : journal d'échecs, règle « deux fois = hook ou test », revue mensuelle | 5 | agents-harness | AUTONOME | sonnet/high |  | 0 |
| [T-043](T-043-plan-compte-rendu.md) | Gabarits de plan et de compte rendu dans `add-app` | 6 | intention | AUTONOME | opus/high | oui | 10 |
| [T-015](T-015-golden-path-ntfy.md) | Golden path n°2 (ntfy interne) : development puis production | 6 | apps | AUTONOME | sonnet/high |  | 9 |
| [T-044](T-044-banc-intentions.md) | Banc d'essai de 5 intentions A (MVP) | 7 | intention | AUTONOME | sonnet/high |  | 5 |
| [T-386](T-386-etalonnage-matrice-haiku-sonnet-opus-sur.md) | Étalonnage : matrice Haiku / Sonnet / Opus sur le banc d'intentions et sur 30 tickets rejoués | 8 | intention | AUTONOME | sonnet/high |  | 1 |

## PORTE — Porte d'adoption OpenChoreo (2026-12-04) (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-211](T-211-porte-openchoreo.md) | Porte d'adoption OpenChoreo : mesurer C1-C5 et décision de Paul (2026-12-04) | 8 | gouvernance | MANDAT | opus/high |  | 1 |

## I1 — Données (8 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-025](T-025-classe-donnees.md) | Classe de donnée dans le contrat et labels `data-class` (G8) | 1 | contrat-appgen | AUTONOME | sonnet/high |  | 11 |
| [T-069](T-069-vap-data-class.md) | VAP : refus de DELETE des données `irreplaceable` (G8) | 2 | securite | REVUE | opus/high |  | 0 |
| [T-026](T-026-sauvegardes.md) | Sauvegarde des bases : CNPG → R2 par préfixe | 5 | donnees | AUTONOME + MANDAT | sonnet/high |  | 7 |
| [T-075](T-075-sauvegarde-volumes.md) | Sauvegarde des volumes : spike VolSync/restic vs Velero/Kopia | 5 | donnees | AUTONOME | sonnet/high |  | 5 |
| [T-348](T-348-previews-par-pr-sur-le-cluster.md) | Previews par PR sur le cluster dev homelab (TTL, frugalité, preuve publiée) | 6 | hybride | AUTONOME + REVUE | sonnet/high | oui | 0 |
| [T-012](T-012-verify-contrat.md) | `spec.verify` : vérification fonctionnelle déclarée (G10) | 6 | contrat-appgen | AUTONOME | sonnet/high |  | 5 |
| [T-067](T-067-retrait-app.md) | `appgen retire` : retrait d'une app avec export des données | 6 | contrat-appgen | AUTONOME | opus/high |  | 0 |
| [T-027](T-027-drill-restauration-auto.md) | Drill de restauration automatique et `restore-evidence` | 7 | donnees | AUTONOME | sonnet/high |  | 4 |

## I1bis — Archétypes D et E (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-011](T-011-archetype-d-worker-cron.md) | Archétype D : `spec.kind: worker | cronjob` (G1) | 2 | contrat-appgen | AUTONOME | sonnet/high |  | 0 |

## I2 — Secrets et identité (13 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-185](T-185-ids-6.md) | Transport des blueprints vers l'Authentik de production (ConfigMap dédié) | 1 | identité-secrets/authentik | MANDAT | opus/high | oui | 6 |
| [T-022](T-022-spike-openbao.md) | OpenBao sur le cluster lab : stockage, déscellement, sauvegarde hors site, drill | 1 | secrets | AUTONOME + MANDAT | sonnet/high |  | 23 |
| [T-060](T-060-residu-kgateway.md) | Résidu kgateway : SA avec lecture des Secrets cluster-wide (B6-sa-effective FAIL) | 1 | socle-oke | REVUE | sonnet/high |  | 12 |
| [T-183](T-183-ids-4.md) | Matrice identité × secrets exécutable et inventaire des identités | 1 | identité-secrets/inventaire | AUTONOME + REVUE | opus/high |  | 10 |
| [T-164](T-164-ai-5.md) | Identité des agents : client Authentik par agent, inventaire et coupe-circuit | 1 | identité-agents | REVUE + MANDAT | opus/high |  | 7 |
| [T-074](T-074-retrait-thunderid.md) | Retirer ThunderID du contrat et des capacités ; Authentik seul | 1 | contrat-appgen | AUTONOME | sonnet/high |  | 5 |
| [T-184](T-184-ids-5.md) | OpenBao : politiques, rôles et auth as code, tests de moindre privilège | 2 | identité-secrets/openbao | AUTONOME + REVUE | opus/high | oui | 9 |
| [T-186](T-186-ids-7.md) | Golden path utilisateur : arrivée et départ (users/<id>.yaml) | 2 | identité-secrets/utilisateurs | REVUE | opus/high |  | 0 |
| [T-189](T-189-ids-10.md) | `identity.mode: oidc | proxy | none` avec client OIDC généré et secret dans OpenBao | 3 | identité-secrets/apps | REVUE | opus/high | oui | 4 |
| [T-319](T-319-pool-remote-control-sur-le-homelab.md) | Pool Remote Control sur le homelab pour les tâches à ressources locales | 5 | hybride | AUTONOME + MANDAT | sonnet/high |  | 0 |
| [T-023](T-023-secrets-generate-provided.md) | Secrets `generate` et `provided` via OpenBao + ESO, statut `secret-missing` | 6 | secrets | AUTONOME + REVUE + MANDAT | sonnet/high |  | 11 |
| [T-071](T-071-doc-utilisateur.md) | Guide utilisateur : demander, suivre, annuler, déposer un secret | 7 | intention | AUTONOME | sonnet/medium |  | 0 |
| [T-218](T-218-acter-adr-0014-0019.md) | Acter les ADR 0014-0019 après le MVP | 9 | gouvernance | MANDAT | opus/high |  | 0 |

## I3 — Exposition, admission, première app familiale (4 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-028](T-028-exposition-publique.md) | Exposition `private | internal | public` : route par hôte (G6) et refus « public sans auth » | 4 | exposition | AUTONOME | sonnet/high |  | 0 |
| [T-020](T-020-kyverno-enforce.md) | Kyverno en Enforce sur le golden path, exceptions générées | 5 | securite | AUTONOME | opus/high |  | 7 |
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

## I5 — Montées de version (9 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-120](T-120-upg-1.md) | Renovate durci : catégories, âge minimal, limites de PR, dashboard, labels | 1 | renovate | REVUE | sonnet/high | oui | 7 |
| [T-122](T-122-upg-3.md) | upgrade-gate : classification exécutable des PR de montée | 2 | porte | AUTONOME + REVUE | opus/high | oui | 4 |
| [T-121](T-121-upg-2.md) | Renovate auto-hébergé avec GitHub App (CI déclenchée, postUpgradeTasks) | 2 | renovate | REVUE + MANDAT | sonnet/high | oui | 0 |
| [T-132](T-132-upg-13.md) | Runbook et preflight de montée Kubernetes OKE (nœud unique) | 2 | k8s-os | AUTONOME + MANDAT | sonnet/high |  | 0 |
| [T-123](T-123-upg-4.md) | Garde d'image : arm64, registre autorisé, signature cosign, provenance | 3 | supply-chain | AUTONOME | opus/high |  | 0 |
| [T-124](T-124-upg-5.md) | Porte de merge des apps : dev, preuve PASS, promotion automatique, revert automatique | 6 | porte | AUTONOME + REVUE | opus/high | oui | 1 |
| [T-349](T-349-canari-du-harness-banc-reduit-nocturne.md) | Canari du harness : banc réduit nocturne sur main et montées épinglées de Claude Code et de l'action | 6 | renovate | REVUE | sonnet/high |  | 0 |
| [T-125](T-125-upg-6.md) | File sérialisée des montées en development et garde de budget | 7 | porte | AUTONOME | opus/high |  | 0 |
| [T-131](T-131-upg-12.md) | Montées stateful : précondition de sauvegarde fraîche et restauration prouvée | 8 | stateful | AUTONOME | sonnet/high |  | 0 |

## I6 — Migration Doppler, rotation, audit (6 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-190](T-190-ids-11.md) | `tools/secrets-migrate` : script idempotent Doppler → OpenBao sans affichage de valeur | 3 | identité-secrets/migration | AUTONOME | opus/high |  | 4 |
| [T-181](T-181-ids-2.md) | Séance de migration Doppler : inventaire, cible (1 projet, 7 jetons), injection dans OpenBao | 4 | identité-secrets/migration | MANDAT | opus/high |  | 3 |
| [T-194](T-194-ids-15.md) | Rotation et échéances : jetons Doppler, clés d'agents, secrets OIDC, clé de seal | 5 | identité-secrets/rotation | MANDAT | opus/high |  | 0 |
| [T-195](T-195-ids-16.md) | Audit : OpenBao, Doppler, Authentik ; rapport « qui a lu quoi » et alertes | 8 | identité-secrets/audit | AUTONOME + MANDAT | opus/high |  | 0 |
| [T-192](T-192-ids-13.md) | Bascule ESO vers OpenBao app par app (ombre, puis PR par app) | 9 | identité-secrets/migration | AUTONOME | opus/high |  | 1 |
| [T-193](T-193-ids-14.md) | Nettoyage Doppler : clés obsolètes, jetons orphelins, projets vides, liste fermée en CI | 10 | identité-secrets/doppler | MANDAT | opus/high |  | 0 |

## I7 — Services IA (homelab) (12 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-160](T-160-ai-1.md) | gVisor et vcluster jetables pour les agents sur le cluster lab | 5 | sandbox | AUTONOME + MANDAT | opus/high |  | 3 |
| [T-161](T-161-ai-2.md) | Composant plateforme ai-gateway (agentgateway) sur k3d avec fournisseur factice | 7 | ai-gateway | REVUE | sonnet/high | oui | 9 |
| [T-162](T-162-ai-3.md) | Schéma et appgen : déclaration ai {models, mcp, budget} et clé virtuelle | 8 | appgen | AUTONOME | sonnet/high | oui | 3 |
| [T-166](T-166-ai-7.md) | Allowlist MCP et gateway MCP : authz par outil, épinglage, lecture seule | 8 | mcp | REVUE | opus/high |  | 2 |
| [T-165](T-165-ai-6.md) | Audit des IA : journal gateway corrélé (qui, outil, coût) | 8 | observabilité-ia | AUTONOME | sonnet/high |  | 1 |
| [T-389](T-389-agentgateway-fournisseur-deepseek-cles-virtuelle.md) | agentgateway : fournisseur DeepSeek, clés virtuelles par usage, budget bloquant (fournisseur factice d'abord) | 8 | ai-gateway | REVUE + MANDAT | sonnet/high |  | 1 |
| [T-163](T-163-ai-4.md) | Admission : sandbox gVisor et egress gateway obligatoires pour ai=true | 9 | admission | REVUE | opus/high |  | 2 |
| [T-167](T-167-ai-8.md) | Règles et banc d'injection de prompt : skills et contexte externes | 9 | contexte | AUTONOME | opus/high |  | 0 |
| [T-350](T-350-voie-deepseek-spike-de-compatibilite-et.md) | Voie DeepSeek : spike de compatibilité et critère d'admission par le banc | 9 | agents | REVUE + MANDAT | sonnet/high |  | 0 |
| [T-390](T-390-garde-de-confidentialite-aucun-log-de.md) | Garde de confidentialité : aucun log de production ni secret vers un fournisseur autre qu'Anthropic | 9 | admission | REVUE | opus/high |  | 0 |
| [T-168](T-168-ai-9.md) | Bac d'exécution éphémère (agent-sandbox) pour le code lancé par les agents | 10 | sandbox | AUTONOME | opus/high |  | 0 |
| [T-171](T-171-ai-12.md) | Premier service IA de référence (LibreChat ou équivalent) de bout en bout | 10 | apps-ia | AUTONOME + MANDAT | sonnet/high |  | 0 |

## I8 — Mesure (DORA, maturité) (3 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-201](T-201-data-2.md) | Ingestion GitHub vers Parquet et métriques DORA par agent | 1 | données | REVUE | sonnet/high | oui | 2 |
| [T-204](T-204-data-5.md) | Grille de maturité cloud native CNCF automatisée (niveaux 1-5) | 2 | données | AUTONOME | sonnet/medium |  | 0 |
| [T-203](T-203-data-4.md) | Métriques sécurité (Scorecard, SLSA, couverture ADR-0006, CVE, secrets) | 6 | données | AUTONOME | sonnet/high |  | 0 |

## I9 — Divers (1 tickets)

| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |
|---|---|---|---|---|---|---|---|
| [T-392](T-392-revue-trimestrielle-du-routage-retraits-de.md) | Revue trimestrielle du routage : retraits de modèles, nouveaux modèles, dérive des tarifs | 6 | veille | AUTONOME | haiku/low |  | 0 |

## Gelés jusqu'à la porte ou bloqués par un déclencheur (29)

[T-006](T-006-mcp-cloudflare-access.md) (deferred), [T-013](T-013-overrides-dependances.md) (deferred), [T-014](T-014-archetype-e-helm-durci.md) (deferred), [T-029](T-029-spike-crossplane.md) (blocked), [T-030](T-030-dataplane-homelab.md) (deferred), [T-042](T-042-atlas-route-intent.md) (deferred), [T-052](T-052-retrait-kube-ops.md) (deferred), [T-063](T-063-dr-plateforme.md) (deferred), [T-073](T-073-dependances-apps.md) (deferred), [T-076](T-076-access-par-app.md) (blocked), [T-077](T-077-banc-intentions-complet.md) (deferred), [T-126](T-126-upg-7.md) (deferred), [T-127](T-127-upg-8.md) (deferred), [T-128](T-128-upg-9.md) (deferred), [T-129](T-129-upg-10.md) (deferred), [T-130](T-130-upg-11.md) (deferred), [T-133](T-133-upg-14.md) (deferred), [T-134](T-134-upg-15.md) (deferred), [T-135](T-135-upg-16.md) (deferred), [T-136](T-136-upg-17.md) (deferred), [T-137](T-137-upg-18.md) (deferred), [T-138](T-138-upg-19.md) (deferred), [T-205](T-205-data-6.md) (deferred), [T-206](T-206-data-7.md) (deferred), [T-207](T-207-data-8.md) (deferred), [T-208](T-208-data-9.md) (deferred), [T-213](T-213-argo-unique-oke.md) (deferred), [T-367](T-367-runners-arc-sur-le-cluster-lab.md) (blocked), [T-372](T-372-plan-oke-a-deux-nuds-2.md) (blocked)


## Absorbés ou supprimés (26)

[T-009](T-009-budget-oke-mesure.md), [T-024](T-024-identite-oidc-declaree.md), [T-064](T-064-mises-a-jour.md), [T-066](T-066-rotation-secrets.md), [T-068](T-068-securite-agents.md), [T-102](T-102-obs-2.md), [T-103](T-103-obs-3.md), [T-104](T-104-obs-4.md), [T-105](T-105-obs-5.md), [T-108](T-108-obs-8.md), [T-110](T-110-obs-10.md), [T-112](T-112-obs-12.md), [T-141](T-141-cost-2.md), [T-142](T-142-cost-3.md), [T-143](T-143-cost-4.md), [T-144](T-144-cost-5.md), [T-145](T-145-cost-6.md), [T-146](T-146-cost-7.md), [T-169](T-169-ai-10.md), [T-170](T-170-ai-11.md), [T-182](T-182-ids-3.md), [T-187](T-187-ids-8.md), [T-188](T-188-ids-9.md), [T-191](T-191-ids-12.md), [T-202](T-202-data-3.md), [T-209](T-209-data-10.md)
