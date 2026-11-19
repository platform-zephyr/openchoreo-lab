# Orchestration parallèle du labo (T-509)

Pour tout orchestrateur Claude : neuf, après compactage ou sur le Mac de Paul. Procédure pas à pas : skill
`orchestrate-backlog`. Usine : `docs/AGENT-RUNNERS.md`. k3d : `docs/CI-K3D.md`. Mesures datées du 2026-11-19, niveau
`USER` (observées par l'orchestrateur cloud) sauf mention contraire. Aucun identifiant de session dans ce dépôt.

## 1. Principes de Paul (ils priment sur ce document)

| Principe | Conséquence pour l'orchestrateur |
|---|---|
| Maintenabilité > richesse | Pas de contrat, d'outil ni de règle ajoutés pour un seul cas. Supprimer avant d'ajouter. |
| Primitives natives d'OpenChoreo | Un couloir qui déforme l'amont s'arrête ; le journal `docs/research/FIDELITE-JOURNAL.md` mesure l'écart. |
| Aucun développement sur kube-ops | Un manque du bras K est une mesure, pas un ticket. |
| Vitesse ; OKE jetable | Paralléliser par défaut ; recréer OKE plutôt que réparer à la main. |
| Arrêt anticipé du banc | Dès que la certitude est là, arrêter la comparaison et passer à l'implémentation. |
| Questions précises | Une série groupée (`mattpocock-grilling`) ; chaque question a des liens (PR, fichiers) et une recommandation (« oui » suffit). |

## 2. Topologie cible

Un seul orchestrateur, sur le Mac de Paul (appareil de confiance, bastion OKE, Docker/Colima). Il dispatche, intègre,
remonte les blocages et ferme la boucle jusqu'à la preuve OKE. Il ne code pas les tickets.

| Rôle | Moyen | Parallélisme | Écrit | Ne fait jamais |
|---|---|---|---|---|
| Orchestrateur | Session Claude Code locale sur le Mac | 1 | PR de coordination, fusion, OKE | Coder un ticket |
| Couloir de développement | Session cloud (`create_session`, ou `claude --cloud` depuis le Mac) | 4 à 8 | Sa branche `claude/t-NNN-*`, sa PR | Écrire sur OKE, toucher un fichier hors périmètre |
| Sous-agent | Outil Agent, `isolation: worktree` | 3 à 7 | Sa branche locale (l'orchestrateur pousse) | Pousser vers un autre dépôt |
| Usine | `claude-agent.yml`, `workflow_dispatch` | 3 (`max-parallel`) | Branche `claude/issue-<n>-*` et PR | Accès cluster ; Sonnet/Haiku 45 min, Opus 90 min |
| Suites k3d | `k3d-integration.yml`, `workflow_dispatch` | 1 run à la fois | Artefacts de preuve | Preuve OKE |
| Opérateur cluster | L'orchestrateur lui-même, bastion de 3 h | 1 (seul écrivain OKE) | `tools/oke/install.sh`, preuves datées | Déléguer l'écriture OKE |

Choix du moyen : couloir cloud pour un ticket long ou sur un autre dépôt cloné ; sous-agent pour un ticket court sur
ce dépôt ; usine pour un lot d'issues sans interaction ; jamais deux moyens sur le même ticket.

## 3. Cycle d'un ticket

`BACKLOG → CLAIM → DÉVELOPPEMENT → PR → CI → REVUE → FUSION → PREUVE OKE → DONE`

| Étape | Entrée exigée | Sortie | Propriétaire |
|---|---|---|---|
| BACKLOG | Fichier `backlog/T-NNN-*.md` complet, périmètre en chemins précis | Score `tools/backlog/priority.py` | Orchestrateur |
| CLAIM | Dépendances `done`, `overlap.py` code 0 avec les couloirs actifs | Branche `claude/t-NNN-<sujet>` créée | Un seul couloir |
| DÉVELOPPEMENT | Brief standard (§6) | Commits avec trailer `Ticket: T-NNN` | Le couloir |
| PR | `tools/dev/check --static --changed` lancé, verdict copié tel quel | PR en brouillon, gabarit complet | Le couloir (ou l'orchestrateur pour un sous-agent) |
| CI | `ci-ok` sur la TÊTE COURANTE (`actions/runs?head_sha=`) | Vert, ou correctif sur la même branche | Le couloir |
| REVUE | Classe AUTONOME ou REVUE (mode dev : fusion après `ci-ok`) ; MANDAT = geste de Paul | Brouillon levé | Orchestrateur |
| FUSION | `ci-ok` vert ; k3d dispatché si `platform/`, `tools/appgen/` ou fixtures changent (§5) | Squash par la file de fusion | Orchestrateur |
| PREUVE OKE | Section « Preuve OKE demandée » de la PR | Preuve datée dans `backlog/evidence/` | Orchestrateur (seul écrivain OKE) |
| DONE | Toutes les cases cochées, PR fusionnée | Statut dérivé `done` (`tools/backlog/derive.py`) | Calculé |

Règles : un ticket = un propriétaire = une branche = une PR. Branche `claude/t-NNN-*`, jamais `claude/issue-*` hors
usine (`agent-trailers` exige alors les trailers de l'usine). Fusionné n'est pas déployé ; `CI PASS` n'est pas
`RUNTIME`. Un ticket sans effet sur OKE saute PREUVE OKE et le dit.

Section de PR exigée quand le ticket a un effet sur le cluster :

```
## Preuve OKE demandée
- Commandes (lecture seule, dans l'ordre) : <commande 1> ; <commande 2>
- Critère PASS : <sortie attendue, chiffrée>
- Critère FAIL : <sortie qui invalide>
- Prérequis : <étape d'install.sh, Application Argo, secret attendu par son nom>
```

## 4. Découper pour paralléliser massivement

| Règle | Comment |
|---|---|
| Périmètres disjoints | Un couloir = des fichiers précis ; `python3 tools/factory/overlap.py --tickets T-a,T-b,...` avant tout lot (code 4 = recoupement, 3 = périmètre inexploitable). |
| Numéros attribués d'avance | L'orchestrateur crée les fichiers de tickets (ou réserve les numéros) avant de lancer : deux couloirs ne choisissent jamais le même `T-NNN`. |
| Séquence par `depends_on` | Un maillon dépendant se prépare en Git pendant que le précédent s'exécute ; il part quand la dépendance est fusionnée. |
| Fichiers chauds | `ci.yaml`, `tools/dev/check`, `ci-map.tsv`, `CODEOWNERS`, `AGENTS.md`, `STATE.md`, `ROADMAP.md` : un seul couloir à la fois. |
| `tests/registry.yaml` | Chaque couloir n'ajoute ou ne retire qu'UNE ligne (la sienne) ; conflit = garder l'union. |
| `generated/` | Jamais à la main ; un seul couloir lance `tools/appgen` par app. |
| `docs/adr/` | Noyau (Opus) ; un couloir par ADR ; l'acceptation d'un ADR est une PR seule. |
| `backlog/README.md`, `NEXT.md` | Orchestrateur seulement. |

Nombre d'agents : il se déduit du travail défini, pas l'inverse. Lancer autant de couloirs qu'il existe de tickets
prêts, disjoints et à critères vérifiables (4 à 8 en pratique). Critère d'arrêt d'un lot : plus aucun ticket prêt et
disjoint, ou le chemin critique attend Paul ou OKE. Ne pas inventer de ticket pour occuper un couloir.

## 5. Capacités et limites mesurées (2026-11-19)

| Capacité | Mesure | Conséquence |
|---|---|---|
| `create_session` | Paramètres utiles : `model`, `source_url` (+ `source_revision`), `extra_allowed_tools` (bornés par ceux du parent), `permission_mode` (jamais `plan` sans humain), `tags` | Taguer chaque couloir `t-NNN` ; le modèle suit le champ `model:` du ticket. |
| `send_message` cloud → cloud | OK | Pilotage direct des couloirs depuis un orchestrateur cloud. |
| `send_message` vers une session limitée aux appareils de confiance | Refusé : `elevated_session_untrusted_device` | Un orchestrateur Mac ne reçoit pas de messages des couloirs : il TIRE (`list_sessions`, `list_events`, `subscribe_pr_activity`). |
| Approbation de `send_message` depuis le Mac en mode par défaut | Bloquée (invite d'approbation sans réponse) | Préférer le mode tirer ; pré-autoriser l'outil si Paul le décide. |
| `add_repo` depuis une session cloud vers un autre dépôt | Refusé (classifieur) | Le sous-agent de l'orchestrateur lit les clones déjà attachés. |
| `subscribe_pr_activity` | OK ; un seul abonné par PR | S'abonner à chaque PR de couloir ; se désabonner à la fusion. |
| `send_later`, routines | Cloud : 1 h minimum entre deux déclenchements | Pas de polling serré par routine ; réveil horaire au plus. |
| Workflows dynamiques | Dans une seule session | Ne remplacent pas des couloirs séparés. |
| Remote Control | Le Mac sert un dossier à une session cloud si Paul l'active | « not_available » observé côté cloud : ne pas compter dessus. |
| Téléport | Cloud → local seulement | Reprendre un couloir cloud sur le Mac, pas l'inverse. |
| `claude --cloud` | Lance une session cloud depuis le Mac | Équivalent de `create_session` pour l'orchestrateur Mac. |
| Classifieur de permissions | Refus constatés : écrire une « autorisation de Paul » dans le dépôt ; amend avec push forcé ; `add_repo` | Ne jamais rédiger une autorisation à la place de Paul ; nouveau commit plutôt qu'amend. |
| k3d sur `merge_group` | Suites `skipped` tant que `K3D_REQUIRED` n'est pas posée | Fusion ≠ preuve k3d : dispatcher `k3d-integration` quand `platform/`, `tools/appgen/` ou les fixtures changent. |
| Quota API GitHub | Atteint une fois par une session locale | Pas de boucle `gh api` ; suivre par `git fetch` et abonnement aux PR. |
| Bastion OKE | 3 h de validité | Grouper les écritures OKE ; noter l'heure d'expiration au début. |
| Coût | Couloir Sonnet ≈ 2 USD (`get_session`) | Budget d'un lot = nombre de couloirs × 2 USD ; Opus pour le noyau seulement. |

## 6. Recettes

Prompt standard d'un couloir = préambule commun + mission + périmètre exclusif :

```
Tu es l'agent T-NNN du labo OpenChoreo (platform-zephyr/openchoreo-lab). Réponses en français, STE80, conclusion
d'abord. Branche OBLIGATOIRE claude/t-NNN-<sujet>. Lis AGENTS.md, puis backlog/T-NNN-*.md. Charge prior-art.
Aucun secret, OCID, IP ni hôte interne. Durée visée ≤ 60 min.
Mission : <intention et critères du ticket>.
PÉRIMÈTRE EXCLUSIF : <fichiers>. Rien d'autre.
Avant de pousser : PYTHONDONTWRITEBYTECODE=1 tools/dev/check --static --changed ; verdict tel quel.
Pousse sur ta branche, PR en brouillon avec « Preuve OKE demandée » si le cluster est concerné. Rapport ≤ 12 lignes.
```

| Recette | Étapes |
|---|---|
| Lancer N couloirs | `overlap.py` code 0 → un `create_session` par ticket (tag `t-NNN`, modèle du ticket, prompt ci-dessus) → `subscribe_pr_activity` dès que la PR existe. |
| Lire leur état | `list_sessions` (`status_bucket`) ; pour un couloir précis `list_events` avec `kinds: ["result"]` ; coût par `get_session`. Toutes les 15 à 30 min, pas plus. |
| Relancer | Vérifier d'abord les effets de la tentative (branche, PR, run). Puis `send_message` (cloud) ou nouvelle session qui reprend la branche existante. |
| Archiver | Après fusion ou abandon : `archive_session` ; se désabonner de la PR. |
| Blocage | Le couloir écrit `BLOCKED` et la cause ; l'orchestrateur classe : technique (nouveau ticket ou correctif), geste de Paul (série de questions groupée), garde refusée (signaler, jamais contourner). |
| Réaffectation (cas T-504) | `interrupt_session` → lire `list_events` → `archive_session` → nouvelle session sur la MÊME branche, prompt qui dit ce qui est déjà poussé. Jamais deux sessions vivantes sur un ticket. |
| Tableau de suivi | Une ligne par couloir : ticket, session (hors dépôt), branche, PR, `ci-ok` tête, statut, coût, prochaine action. Tenu dans le contexte de l'orchestrateur, pas dans le dépôt. |
| CI rouge sur `main` | Arrêter les fusions ; lire le job ; si une PR fusionnée l'a cassé, `git revert` par PR ; sinon un couloir unique répare. Un run rouge de niveau ≤ L2 est un défaut de l'environnement local à corriger aussi. |

## 7. Anti-patterns constatés

| Anti-pattern | Remède |
|---|---|
| Annoncer « vert » sur un run dont les suites sont `skipped` | Lire le statut de chaque suite ; `skipped` = `NOT_TESTED`. |
| Ajouter du contrat pour un seul cas | Mesurer l'écart dans le journal de fidélité ; adapter l'app ou accepter la limite. |
| Deux écrivains sur un même fichier | `overlap.py` avant chaque lot ; fichiers partagés selon §4. |
| Polling serré | Abonnement aux PR, `git fetch`, relevé toutes les 15 à 30 min. |
| Confirmer un niveau de confiance sans en dire les conséquences | Avant de passer une session en « appareils de confiance », dire qu'elle ne reçoit plus de messages des sessions cloud. |
| `ci-ok` lu sur un vieux SHA | Toujours la tête courante de la PR. |
| `__pycache__` laissés avant `tools/dev/check` | `PYTHONDONTWRITEBYTECODE=1` et suppression ; sinon `leak-guard` échoue. |
