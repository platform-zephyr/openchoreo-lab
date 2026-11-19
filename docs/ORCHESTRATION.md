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

Un seul orchestrateur, sur le Mac de Paul (appareil de confiance, bastion OKE, Docker/Colima). Il DÉLÈGUE
systématiquement : il dispatche, synchronise, remonte les blocages et réfléchit aux frictions. Il ne code pas, ne
diagnostique pas, n'exécute pas. Détail : § « Rôle de l'orchestrateur » ci-dessous.

| Rôle | Moyen | Parallélisme | Écrit | Ne fait jamais |
|---|---|---|---|---|
| Orchestrateur | Session Claude Code locale sur le Mac | 1 | PR de coordination, fusion des PR prêtes | Coder, diagnostiquer, lancer une vérification, poser un Secret, écrire sur OKE |
| Couloir de développement | Session cloud (`create_session`, ou `claude --cloud` depuis le Mac) | 4 à 8 | Sa branche `claude/t-NNN-*`, sa PR | Écrire sur OKE, toucher un fichier hors périmètre |
| Sous-agent | Outil Agent, `isolation: worktree` | 3 à 7 | Sa branche locale (l'orchestrateur pousse) | Pousser vers un autre dépôt |
| Usine | `claude-agent.yml`, `workflow_dispatch` | 3 (`max-parallel`) | Branche `claude/issue-<n>-*` et PR | Accès cluster ; Sonnet/Haiku 45 min, Opus 90 min |
| Suites k3d | `k3d-integration.yml`, `workflow_dispatch` | 1 run à la fois | Artefacts de preuve | Preuve OKE |
| Opérateur OKE | Session locale sur le Mac, lancée par l'orchestrateur (brief du § Rôle) | Lectures : illimité. Écritures : 1 par zone (§ Écritures OKE en parallèle) | Secrets, synchros manuelles, preuves datées dans sa zone ; `tools/oke/install.sh` seulement s'il est le seul « plateforme » | Deux écrivains sur la même zone ; sortir de `openchoreo-*` et `lab-*` |

Choix du moyen : couloir cloud pour un ticket long ou sur un autre dépôt cloné ; sous-agent pour un ticket court sur
ce dépôt ; usine pour un lot d'issues sans interaction ; session locale pour ce qui exige le Mac (opérateur OKE) ;
jamais deux moyens sur le même ticket.

## Rôle de l'orchestrateur

Correction de Paul (2026-11-19) : l'orchestrateur ne fait pas le travail, il le confie. Trois fonctions : dispatcher,
synchroniser, réfléchir.

| Il fait | Il délègue (un agent par chantier) | Il ne fait jamais |
|---|---|---|
| Dispatche : un chantier = un agent, prompt standard (§ 6), ticket, périmètre exclusif | Chercher un script, un fichier, un art antérieur | Coder un ticket |
| Synchronise : PR, notes « Reprise » des tickets, `list_sessions`, `list_events` ; détecte blocages, recouvrements, dépendances ; relance ou réaffecte | Lire un script avant exécution ; lancer `verify.sh` ou toute vérification | Écrire sur OKE (bastion, Secret, `verify.sh --all`, preuves) |
| Fusionne les PR prêtes après `ci-ok` sur la tête courante | Poser un Secret, diagnostiquer une panne, corriger une CI | Contourner une garde ou écrire une autorisation de Paul |
| Remonte à Paul UNE série groupée de blocages et d'actions externes, avec liens et recommandation | Toute action OKE : à un agent « opérateur OKE » local (une zone d'écriture par opérateur) | Deux écrivains sur la même zone |
| Réfléchit aux frictions récurrentes (journal `docs/research/FRICTIONS-ORCHESTRATION.md`) | Les améliorations décidées (skill, doc, outil, ticket) | Annoncer « vert » sans avoir lu le statut de chaque suite |

**Règle STOP.** Si tu t'apprêtes à chercher, lire un script, lancer une vérification, poser un secret, coder ou
diagnostiquer : arrête, lance un agent. Une lecture de PR, de note « Reprise » ou de statut de session reste à toi
(c'est la synchronisation).

### Écritures OKE en parallèle (décision de Paul, 2026-11-19)

Tous les agents locaux partagent le même bastion et le même kubeconfig : la règle « un seul écrivain » est une règle de
cohérence, pas une limite technique. OKE est jetable et la vitesse prime, donc :

| Cas | Règle |
|---|---|
| Lectures (`verify.sh`, mesures, diagnostics, preuves de lecture) | En parallèle, sans limite. |
| Écritures ponctuelles (Secret par tube, synchro manuelle, test de refus) | En parallèle si les ZONES sont disjointes : zone = un namespace ou une famille d'objets (`lab-o-*`, `lab-k-*`, notifications, `lab-secrets`). Un opérateur par zone. |
| Opérations qui touchent toute la plateforme (`tools/oke/install.sh` étapes 0 à 11, Cilium, Argo CD, ESO, kgateway) | UN seul agent « plateforme » ; aucune autre écriture pendant ce temps. |
| Traçabilité | La section « Preuve OKE demandée » de la PR nomme la zone d'écriture ; l'orchestrateur tient la liste des zones occupées et refuse un second écrivain sur la même zone. |
| Durable | Toujours par Git puis Argo CD (`AGENTS.md`) ; une écriture directe n'est jamais un changement durable. |

### Brief type d'un agent « opérateur OKE »

Session locale sur le Mac. Plusieurs opérateurs en parallèle sont admis : lectures sans limite, un seul écrivain par ZONE (voir § Écritures OKE en parallèle).

```
Tu es l'opérateur OKE du labo OpenChoreo (session locale). Réponses en français, STE80, conclusion d'abord.
Écriture dans les namespaces openchoreo-* et lab-* seulement. Aucun secret, OCID, IP ni hôte interne dans le dépôt,
la PR ou ta sortie. Ta ZONE d'écriture est donnée par l'orchestrateur ; si un autre opérateur écrit déjà dans cette zone, arrête-toi et dis-le.
1. Ouvre l'accès : tools/oke/open-oke-access.sh open 10800 (bastion de 3 h) ; note l'heure d'expiration.
2. LIS le script avant de l'exécuter (open-oke-access.sh, verify.sh, install.sh) ; si une commande te surprend, stop.
3. Joue la section « Preuve OKE demandée » de la PR (ou les cases du ticket), dans l'ordre. Pour un contrôle
   d'ensemble : tools/oke/verify.sh --all ; verdict par contrôle, tel quel.
4. Relève l'empreinte : CPU et RAM (requêtes/limites vs allocatable), nombre de pods par nœud (maxPods). Les 33 pods ne sont pas une limite des apps de test (T-518) : relève sans verdict FAIL.
5. Secrets : valeur aléatoire générée par tube, jamais affichée ni écrite ; noms seulement dans les preuves.
6. Archive chaque preuve datée dans backlog/evidence/ (PASS / FAIL / NOT_TESTED / BLOCKED, niveau RUNTIME, date).
7. Ferme l'accès : open-oke-access.sh close.
Rapport final <= 15 lignes : verdicts, chemins des preuves, écarts, blocages, prochaine action.
```

### Cadence

| Activité | Fréquence | Contenu |
|---|---|---|
| Synchronisation | Relevé toutes les 15 à 30 min (pas de boucle serrée) | Tableau de suivi (§ 6) : sessions, PR, `ci-ok` sur la tête, blocages ; fusion des PR prêtes ; relance ou réaffectation |
| Remontée à Paul | À la demande, en série groupée | Blocages et actions externes, liens, recommandation (« oui » suffit) |
| Réflexion | Toutes les 2 à 3 h | Mise à jour de `docs/research/FRICTIONS-ORCHESTRATION.md` ; au plus 3 améliorations proposées à Paul, puis déléguées |

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
| PREUVE OKE | Section « Preuve OKE demandée » de la PR | Preuve datée dans `backlog/evidence/` | Opérateur OKE (délégué par l'orchestrateur ; une zone d'écriture par opérateur) |
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
