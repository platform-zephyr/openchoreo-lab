# Journal des frictions d'orchestration (T-516)

Objet : repérer les problèmes RÉCURRENTS de l'orchestration et n'améliorer que sur preuve de répétition. Principe de
Paul : supprimer avant d'ajouter. Rôle de l'orchestrateur : `docs/ORCHESTRATION.md` § « Rôle de l'orchestrateur ».

## Cadence

Toutes les 2 à 3 h, l'orchestrateur délègue cette revue à un agent, ou la fait sur la base des relevés :

1. Ajouter les nouvelles frictions (une ligne par friction ; la date est celle de la première observation).
2. Regrouper les frictions récurrentes : une friction à 2 occurrences ou plus passe en tête et incrémente sa colonne.
3. Proposer à Paul AU PLUS 3 améliorations (skill, doc, outil ou ticket), chacune avec lien et recommandation.
4. Déléguer les améliorations acceptées (un agent par chantier) ; reporter le ticket et le statut dans la ligne.

Une amélioration qui ajoute du code ou une règle pour un seul cas est refusée : d'abord mesurer la récurrence.

## Journal

Source des lignes du 2026-11-19 : observé par l'orchestrateur cloud, niveau `USER`, sauf mention contraire. La
récurrence compte les occurrences constatées à ce jour. Statuts : `ouvert`, `proposé`, `en cours`, `corrigé`, `écarté`.

| Date | Friction | Réc. | Cause | Correctif proposé (minimal) | Ticket | Statut |
|---|---|---|---|---|---|---|
| 2026-11-19 | Annonce « vert » sur un run k3d dont les suites étaient `skipped` (`K3D_REQUIRED` non posée) | 1 | Un `skipped` lu comme un succès ; la variable n'est pas posée sur `merge_group` | Lire le statut de chaque suite ; `skipped` = `NOT_TESTED` (déjà au § 7 de `docs/ORCHESTRATION.md`) ; poser `K3D_REQUIRED` | T-513 | en cours |
| 2026-11-19 | Confirmation de confiance d'appareil (`confirm_repository_trust`) sans avoir averti de la conséquence : les sessions cloud n'écrivent plus à l'orchestrateur (`elevated_session_untrusted_device`) | 1 | Effet de bord non annoncé | Avant la confirmation, dire la conséquence ; mode « tirer » (déjà au § 5 et § 7) | — | corrigé (doc) |
| 2026-11-19 | `add_repo` refusé aux sessions cloud pour d'autres dépôts (T-504 réaffecté) | 1 | Refus du classifieur de permissions | Ne pas en dépendre : lire les clones déjà attachés ; réaffecter (recette du § 6) | T-504 | corrigé (doc) |
| 2026-11-19 | Approbation de `send_message` bloquée sur les sessions Mac en mode par défaut | 1 | Invite d'approbation sans réponse | Mode « tirer » ; pré-autoriser l'outil seulement si Paul le décide | — | proposé |
| 2026-11-19 | Script d'ouverture du bastion OKE introuvable par un agent neuf (emplacement cité seulement dans un « handoff privé ») | 1 | Pas de renvoi dans la documentation ; le script, lui, est versionné sous `tools/oke/` | Citer son chemin (sans valeur) dans le brief de l'opérateur OKE (fait, `docs/ORCHESTRATION.md`) ; rien d'autre | T-516 | corrigé (doc) |
| 2026-11-19 | Le classifieur de permissions refuse : écrire une « autorisation de Paul » dans le dépôt, un amend avec push forcé, la manipulation d'une clé privée dans le shell (le test d'écriture négatif de l'App `openchoreo-status` reste `NOT_TESTED`) | 3 | Refus attendus et voulus | Ne jamais les contourner ; le test de l'App reste un geste de Paul | T-515 | ouvert |
| 2026-11-19 | Concurrence k3d : un run à la fois ; `argo-escalation` rouge sur `main` pendant plusieurs PR avant correctif | 1 | Suite instable (CRD Cilium manquantes) | Correctif fusionné ; un run k3d à la fois (§ 5) ; pas de nouvelle règle | T-505 | corrigé |
| 2026-11-19 | Quota de l'API GitHub atteint par une session locale | 1 | Boucle d'appels `gh api` | `git fetch` et abonnement aux PR (déjà au § 7) | — | corrigé (doc) |
| 2026-11-19 | Rapports de sous-agents renvoyés en boucle ; agents Opus arrêtés par Paul (coût) | 1 | Pas de borne de rapport ni de choix de modèle suivi | Rapport ≤ 12 lignes dans le prompt standard (fait) ; Opus pour le noyau seulement | — | proposé |
| 2026-11-19 | Orchestrateur Mac qui exécute lui-même au lieu de déléguer | 1 | Rôle non écrit | § « Rôle de l'orchestrateur » et règle STOP | T-516 | corrigé (doc) |
| 2026-11-19 | Tests de contrat ajoutés pour un seul cas (refus du champ `healthProbe`) | 1 | Ajout avant mesure de récurrence | Supprimer ou fusionner dans un test existant ; pas de test sans second cas | — | proposé |

Aucune de ces lignes n'est vérifiable dans l'historique du dépôt, sauf T-505, T-513 et le chemin du script de bastion ;
les autres sont déclaratives (niveau `USER`).
