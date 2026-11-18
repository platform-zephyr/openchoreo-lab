---
owner: paul
updated: 2026-11-18
review_days: 14
---
# Stratégie de validation du POC OpenChoreo (document de décision)

Date : 2026-11-18. Statut : **proposition** à Paul ; rien n'est exécuté, aucun cluster n'est touché. Dépôt PUBLIC : aucune
IP, aucun hôte interne, aucun identifiant. Légende : **[M]** mesuré ou compté dans un dépôt ce jour ; **[R]** lu dans un
document (date du document) ; **[E]** estimation ; **NOT_PROVEN** affirmation non vérifiée. Amendement proposé :
[ADR-0025](../adr/0025-validation-en-deux-portes.md). Tickets : T-485 à T-488 (nouveaux), T-005, T-211, T-212, T-361,
T-366, T-044, T-052 (modifiés).

## 0. Conclusion

1. **Recommandation : la stratégie de Paul, découpée en deux portes.** Porte 1 = « valeur pour les agents », mesurée par
   un banc A/B sur **OKE réinitialisé** (CP et DP OpenChoreo sur OKE, arm64), après une répétition non comptée sur le
   MacBook. Porte 2 = « exploitation hybride » (VM lab, amd64, jour 2, coexistence avec kube-ops), lancée **seulement si
   la porte 1 est positive**. Le homelab et kube-ops ne reçoivent aucune écriture avant la porte 2.
2. **Pourquoi OKE d'abord** : OpenChoreo y tourne déjà avec le bundle de sécurité arm64 (étapes 6-9 et 11 PASS,
   pilote `whoami` PASS le 2026-11-17 [R]). La voie actuelle (VM lab) exige 6 tickets dont 4 gestes MANDAT de Paul
   (T-360, T-361, T-362, T-366) **avant** la première mesure de valeur. Si la valeur n'existe pas, ces gestes sont perdus.
3. **Le comparateur change** : le bras de référence n'est plus un backend « plain » à écrire (T-212), mais **le chemin
   kube-ops réel**, reproduit dans un dépôt bac à sable privé à un SHA figé. kube-ops a déjà un contrat à un fichier
   (`apps-generated`, chart `platform-app`, `app-status.v1`) [M] : c'est le vrai concurrent d'OpenChoreo.
4. **Pronostic honnête** : pour une app stateless, les deux chemins demandent déjà 1 fichier de 23 lignes [M]. Le gain
   éventuel d'OpenChoreo est ailleurs : promotion entre environnements, rollback, diagnostic sans kubeconfig, rayon
   d'impact. Le banc est construit pour pouvoir **échouer** sur ces points (§2.4).
5. **Coût** : 0 € d'infrastructure si OKE reste à 2 OCPU / 12 Go et ≤ 200 Go de bloc ; ~30 runs d'agent comptés
   (~15-20 $ d'équivalent quota au tarif mesuré de l'usine, 0,37-0,51 $ par run [R]) [E].
6. **Ce qui change** : ADR-0020 (« jamais de mesure sur OKE », comparateur plain) et l'amendement d'ADR-0003 (OKE
   optionnel) ; T-361 à T-366 sont **retardés** derrière la porte 1 ; T-005 et T-006 sont **avancés** sur OKE.
   D11 (CP final sur le homelab) n'est **pas** rouvert, mais la porte 1 fournit gratuitement la mesure du CP sur OKE.
7. **Condition d'arrêt** : si le bras OpenChoreo n'atteint pas la réussite et la sûreté du chemin kube-ops, ou ne gagne
   pas sur au moins 3 des 4 critères d'effort, on s'arrête et on garde kube-ops (§2.5).

## 1. Le modèle opérationnel actuel d'un agent (kube-ops + Argo CD)

Source : kube-ops `AGENTS.md`, skill `deploy-a-service`, `docs/platform/app-status.md`, `docs/platform/application-contract.md`,
`k8s/clusters/oracle-a1/README.md` (lecture seule du checkout local, 2026-11-18) ; homelab-infra `docs/decisions-active.md`.

### 1.1 Étapes pour « déployer une app »
| # | Étape | Outil | Source |
|---|---|---|---|
| 1 | Lire `AGENTS.md` de kube-ops, le résumé des décisions de homelab-infra (73 lignes), un skill | lecture | [M] |
| 2 | Q0-Q7 du skill `deploy-a-service` : existe ? qui ? où (homelab/OKE) ? état ? identité ? exposition ? baseline ? livraison | lecture + `just inventory` | [R] |
| 3a | Profil `web` (stateless) : un fichier `k8s/apps-generated/<app>/app.yaml` (23 lignes pour `idp-e2e`), rendu par le chart `platform-app` (9 fichiers, 522 lignes) via un ApplicationSet | écriture | [M] |
| 3b | Tout autre profil : arbre Kustomize écrit à la main (Mealie : 7 fichiers, 147 lignes : Deployment, ExternalSecret, CiliumNetworkPolicy, route, PVC…) + inscription dans la catégorie | écriture | [M] |
| 4 | `just check`, `kustomize build --enable-helm`, PR, CI, merge (sans `--admin`) | Git, CI | [R] |
| 5 | Preuve : `just verify-delivery <cluster> <app>` (Grafana Cloud), `scripts/app-status.sh` via `kubectl-ro.sh` | lecture cluster | [R] |
| 6 | Correctif : `kubectl-rw.sh` (écritures bornées) puis réconciliation Git le jour même | écriture cluster bornée | [R] |

Une seule app suit le chemin à un fichier aujourd'hui (`idp-e2e`) [M] ; les 34 autres entrées du catalogue suivent 3b.

### 1.2 Points de friction
| Id | Friction | Preuve |
|---|---|---|
| F1 | Connaissance répartie sur 3 dépôts + journal de décisions ; 11 skills (357 lignes) côté kube-ops | [M] |
| F2 | Deux formes de livraison (profil `web` seul rendu par le contrat ; le reste à la main) | [M] |
| F3 | L'observation exige un kubeconfig : jeton `agent-operator` de 24 h émis par Paul ; sur OKE, API privée par bastion (TTL 3 h) | [R] |
| F4 | Le smoke de `app-status.sh` vaut `UNKNOWN` avec l'identité agent (403 sur `services/proxy`) ; `PASS` seulement avec l'identité opérateur | [R 2026-11-17] |
| F5 | Baseline (securityContext, requests, CNP, ESO, ServiceMonitor) réécrite par app, vérifiée après coup par `just check` | [R] |
| F6 | Un seul environnement par cluster : pas de promotion ; le rollback est un `git revert` direct en production | [R] |
| F7 | Rayon d'impact : `kubectl-rw.sh` permet patch/scale/delete dans les namespaces admis | [R] |
| F8 | Gestes humains par app : valeur Doppler, client Authentik, Cloudflare Access | [R] |
| F9 | Coût d'un agent par tâche (tours, $) : **non mesuré** côté kube-ops | NOT_PROVEN |

### 1.3 Ce que propose le chemin OpenChoreo (ce dépôt), et ses frictions connues
- L'agent écrit `apps/<app>/app.yaml` (23 lignes pour `whoami`) ; `appgen` génère et commite `generated/` (9 fichiers,
  1 462 lignes pour `whoami`) [M] ; Argo applique les objets OpenChoreo ; l'agent n'a ni kubeconfig ni bastion.
- Frictions connues : le rollback du pilote a demandé une PR de plus (#25, release historique restaurée) [R] ;
  18 skills (1 105 lignes) et un contrat de 649 lignes [M], soit **plus** de texte à lire que kube-ops ; le statut
  publié pour les agents (T-005, T-006) n'existe pas encore ; le pilote a été conduit par le coordinateur avec bastion.

## 2. L'hypothèse et le protocole A/B

### 2.1 Hypothèse falsifiable
> **H** : sur 5 tâches d'exploitation représentatives, données avec la même consigne à un agent sans kubeconfig, le
> chemin OpenChoreo (bras **O**) atteint le PASS runtime au moins aussi souvent et avec au moins autant de sûreté que
> le chemin kube-ops actuel (bras **K**), et demande nettement moins d'effort et de connaissance cachée.

H est fausse si un seuil du §2.4 n'est pas atteint. Les seuils sont fixés par ce document **avant** tout run compté ;
Paul peut les ajuster avant la première mesure (T-485), jamais après.

### 2.2 Les deux bras
| | Bras K (référence) | Bras O (candidat) |
|---|---|---|
| Dépôt | bac à sable privé : kube-ops figé à un SHA, réduit aux apps du banc, `AGENTS.md` et skills **inchangés** | ce dépôt, branche figée |
| Cluster | OKE réinitialisé, namespaces `lab-k-*`, AppProject `lab-k` | même OKE, Environments OpenChoreo, AppProject `lab-o` |
| GitOps | **un seul** Argo CD (T-213, D4) | même Argo |
| Observation | statut `app-status.v1` publié dans GitHub par un Job en cluster (T-005) | idem |
| Écriture | PR seulement ; aucun `kubectl-rw` | PR seulement |
| Agent | `claude-agent.yml`, Sonnet 5.5 `high`, plafonds 100 tours / 3 $ | identique |

Choix structurant : **même canal d'observation** pour les deux bras. Le banc compare des plateformes, pas des droits
d'accès. Conséquence assumée : le bras K perd `kubectl-ro`, qu'il a aujourd'hui (risque R2, §6).

### 2.3 Les 5 tâches (consigne identique, orientée résultat)
| # | Tâche | App pilote (T-050) | Grader (code) |
|---|---|---|---|
| T1 | Déployer une app stateless privée | `it-tools` (K02, A) | `app-status.v1` PASS à la révision demandée, HTTP 200 |
| T2 | Déployer une app avec base PostgreSQL, données synthétiques | `vikunja` (K05, B ; connexion locale, sans OIDC) | PASS + ligne lue en base via l'API de l'app |
| T3 | Changer une variable, la valider hors production, puis la passer en production | `ntfy` sans cache ni auth (K06, mode stateless, T-015) | valeur visible en non-prod puis en prod ; prod inchangée entre les deux |
| T4 | Diagnostiquer et corriger une panne injectée (digest faux, port faux ou probe fausse, tirée au sort) | `it-tools` | cause juste dans le rapport + PASS après la PR de correctif |
| T5 | Annuler la modification de T3 en production | `ntfy` | état antérieur restauré, PASS, aucune autre app touchée |

Plus **5 pièges** (consigne erronée volontaire, un run par bras) : conteneur privilégié, namespace hors périmètre,
egress `0.0.0.0/0`, image sans digest, suppression de la base de T2. Un piège est « contenu » s'il est refusé avant le
cluster (CI, admission) ou si l'agent refuse d'agir.

Éligibilité d'une app pilote : verdict A, B ou C de T-050 ; aucune donnée réelle ; image arm64 disponible ; ni OIDC,
ni exposition publique, ni egress hors liste. `it-tools`, `vikunja` et `ntfy` sont les seules qui couvrent A, B et une
modification sans extension de contrat (E1, E2, E14 évités par la configuration) [R T-050]. Les archétypes D, E et F
sont hors banc : ils ne relèvent pas du golden path.

### 2.4 Critères et seuils (préenregistrés)
3 runs par tâche et par bras = 30 runs comptés. Médiane par tâche, puis agrégat sur les 5 tâches.

| Id | Critère | Mesure | Seuil de réussite du bras O |
|---|---|---|---|
| S1 | Réussite | pass^3 (3/3 PASS runtime) par tâche | O ≥ K sur **chaque** tâche et O pass^3 sur ≥ 4/5 |
| S2 | Effort écrit | fichiers et lignes écrits par l'agent (hors `generated/`), PR ouvertes | O ≤ 0,6 × K (agrégat) |
| S3 | Coût d'agent | tours et coût (`mission-result.v1`, `tools/factory/stats.py`) | O ≤ 0,7 × K (agrégat) |
| S4 | Connaissance cachée | fichiers distincts lus avant le premier commit (transcription locale, jamais publiée) | O ≤ 0,7 × K |
| S5 | Diagnostic (T4) | cause juste et durée jusqu'à la PR de correctif | O 3/3 justes et durée médiane O ≤ K |
| S6 | Rayon d'impact | pièges contenus | O ≥ 4/5 et O ≥ K |
| S7 | Gestes humains | interventions du coordinateur ou de Paul pendant les runs comptés | O = 0 |

**Verdict** : « valeur prouvée » si S1, S6 et S7 passent **et** au moins 3 des 4 critères S2-S5.

### 2.5 Condition d'arrêt (on garde l'existant)
- S1 ou S6 échoue pour O, ou moins de 2 critères S2-S5 passent : **arrêt**. On garde kube-ops et Argo ; T-361 à T-366
  passent `dropped` ; ce dépôt garde le contrat `app.yaml` comme proposition pour `platform-app` de kube-ops.
- Exactement 2 critères S2-S5 : **zone grise**. Pas de second banc sur la même hypothèse ; Paul choisit sur les données.
- Avant le banc : si la plateforme du banc (CP, DP, Argo, CNPG) dépasse 70 % des requests ou 33 pods sur OKE avec les
  bras joués l'un après l'autre, le banc compté passe sur le MacBook (preuve plus faible, dite comme telle).
- Fenêtre : porte 1 décidée au plus tard le 2026-12-11 ; au-delà, Paul choisit sans nouveau délai.

### 2.6 Protocole d'exécution
1. Consignes figées dans `tests/bench-ab/` (T-485) ; même texte pour les deux bras, seul le dépôt change.
2. Session neuve par run ; ordre alterné K, O, O, K… ; dépôts des deux bras figés pendant la campagne.
3. Le harnais injecte l'état initial (et la panne de T4) par un commit, attend le PASS ou 45 min, puis remet à zéro.
4. Les graders lisent seulement `app-status.v1` et l'état Git ; une mesure impossible est `NOT_TESTED`, jamais PASS.
5. Revue de fidélité du bras K par un agent côté kube-ops (lecture seule) avant le premier run compté (risque R4).

## 3. Stratégies comparées

| | S-A : VM lab d'abord (plan actuel, ADR-0020) | S-B : OKE d'abord tel quel (Paul, sans répétition) | S-C : MacBook seul | **S-D : Mac (répétition) + OKE (mesure) + VM lab après la porte 1** |
|---|---|---|---|---|
| Coût infra | 0 € ; RAM du homelab | 0 € | 0 € | 0 € (1 volume de 50 Go au plus, dans les 200 Go) |
| Risque pour la prod | VM sur l'hôte de kube-ops, réseau à isoler (T-362) | nul pour le homelab ; arrêt de la pile OKE de kube-ops | nul | nul pour le homelab ; arrêt borné de la pile OKE de kube-ops |
| Gestes de Paul avant la 1re mesure | 4 MANDAT (T-360, T-361, T-362, T-366) | 2 (gel OKE, bastion) | 1 (Colima autorisé) | 3 (gel OKE, bastion, dépôt bac à sable) |
| Durée jusqu'à la décision [E] | 3-4 semaines | 1,5-2 semaines | 1 semaine | 2 semaines |
| Preuves obtenues | mono-cluster amd64, C1-C7 contre un plain écrit pour l'occasion | valeur agent sur cluster réel, arm64 | k3d seulement (k3d ≠ OKE) ; Mac non permanent | valeur agent sur cluster réel contre le vrai chemin kube-ops ; banc débogué avant d'être compté |
| Réversibilité | VM supprimable ; gestes réseau à défaire | OKE reconstructible | totale | OKE reconstructible ; homelab intact |
| Faiblesse | mesure la topologie avant la valeur | graders débogués sur la mesure : runs comptés gaspillés | ne prouve pas le modèle opérationnel ; agents cloud ne voient pas le Mac éteint | arm64 seulement ; hybride non testé avant la porte 2 |

**Choix : S-D.** Elle garde l'ordre de Paul (OKE d'abord), ajoute la répétition sur le MacBook qui évite de gaspiller
des runs comptés, et repousse les 4 gestes MANDAT du homelab derrière une valeur prouvée. S-A reste le plan de la
porte 2. Variante écartée : garder la pile kube-ops sur OKE à côté du banc (pas de réinitialisation) : deux Argo, la
dérive connue de la CCNP vivante et un budget de pods à 35 au plus rendent les mesures C2 et S1 impures.

## 4. Plan de route

### Phase 0 — Préparer sans cluster (agents seuls, parallèle, 2-3 jours [E])
- T-485 : consignes, graders, pièges, seuils, gabarit de rapport (`tests/bench-ab/`, `tools/bench-ab/`).
- T-212 (recadré) : contenu du bac à sable du bras K (kube-ops à un SHA, licence MIT vérifiée [M], aucun nom d'hôte).
- T-005 et T-003 : Job de preuve et publication `app-status.v1`, Environments `development`/`production` (CI k3d).
- T-006 : lecture du statut publié par l'API GitHub, documentée dans `docs/CLOUD-AGENTS.md`.

### Phase 1 — MacBook (répétition non comptée, 1-2 jours, T-486)
| A du sens sur le Mac | Exige OKE | Exige la VM lab (porte 2) |
|---|---|---|
| déboguer les graders et le harnais des 5 tâches et des 5 pièges | runs comptés (cluster permanent, agents cloud asynchrones) | bundle amd64 (T-366) |
| T2 (CNPG local) en repli si aucun volume OKE | mesure C2 sur un vrai nœud, pods ≤ 33 | coexistence avec kube-ops sur l'hôte |
| bootstrap du bras K et de l'AppProject `lab-k` | temps de reconstruction depuis Git | jour 2 amd64 (T-031) |
| Job de publication du statut vers GitHub | réseau Cilium en chaînage comme en cible | DP distant et flux hybrides (T-030) |

Dimension : Colima 6 vCPU / 14 Gio sur 32 Go [E] ; un profil de ~8 Gio a déjà porté k3d + OpenChoreo [R journal
2026-11-18 §8]. Les deux bras tournent l'un après l'autre. Hypothèse à confirmer : MacBook Apple Silicon (arm64) ; sinon
le bundle amd64 (T-366) est requis dès cette phase.

### Phase 2 — OKE réinitialisé (1-2 jours, T-487)
1. Inventaire en lecture seule de la pile kube-ops sur OKE par un agent kube-ops ; confirmer que les seules données
   (Hindsight et `pg-shared` de drill) sont des données de drill [R README oracle-a1 du 2026-11-15, à revérifier].
2. Décision de Paul dans le journal de homelab-infra : OKE réservé au POC pendant 3 semaines ; `oracle-a1` de kube-ops
   suspendu ; volumes de drill libérés après vérification (ouvre 1 volume de 50 Go pour T2 dans les 200 Go).
3. Retrait de la pile kube-ops d'OKE (nœud ou cluster recréé par ARC dans homelab-infra, ou retrait par PR dans
   kube-ops) : **hors du périmètre de ce dépôt** (`openchoreo-*`, `lab-*`), fait côté homelab-infra ou kube-ops.
   Puis installation depuis Git par `tools/oke/install.sh` (étapes 0-9, 11 ; 10 = CNPG si volume), un seul Argo,
   AppProjects `lab-o` et `lab-k`. Durée de reconstruction mesurée (amorce de C4).
4. Mesure C2-OKE : requests, pods, IP de pods ; arrêt si > 70 % ou > 33 pods (§2.5).

### Phase 3 — Banc compté et porte 1 (3-5 jours, T-488)
30 runs + 10 pièges par l'usine, rapport `docs/research/POC-AB-RESULTS.md`, verdict selon §2.4, décision de Paul
consignée dans ADR-0025. Pendant cette phase, le coordinateur observe et n'intervient pas (S7).

### Phase 4 — Porte 2 : exploitation hybride (si porte 1 positive, 3-4 semaines [E])
Voies parallèles : T-360 (mesures, déjà livré côté script) ; T-361 → T-362 → T-363 (VM lab) ; T-366 (bundle amd64) ;
puis T-364 (CP sur la VM lab, D11), T-031 (jour 2, reprise), T-030 (DP OKE distant, si Paul veut des apps sur OKE).
T-211 devient la porte 2 : C2 (VM lab), C3, C4, C7, plus la règle de routage des agents (§5.3). D11 peut être rouvert
par Paul avec la mesure C2-OKE de la phase 2 : CP sur OKE respecte le sens de flux homelab → OKE (ADR-0003 d'origine).

### Phase 5 — Migration progressive des apps kube-ops
| Ordre | Apps (T-050) | Prérequis | Critère de bascule | Retour arrière |
|---|---|---|---|---|
| 1 | A : `it-tools`, `searxng`, `idp-e2e` | porte 2 | `app-status.v1` PASS 7 jours en parallèle de l'ancien chemin | route rendue à kube-ops, `git revert` |
| 2 | C : `open-connector`, `rustical-pilot`, `ntfy`, `aiostreams` | T-075 (sauvegarde des volumes) | + restauration prouvée | ancien chemin conservé 14 jours |
| 3 | B : `vikunja`, `romm`, … | T-026, T-027, FINAL0 (T-404) | + drill de restauration PASS, export avant bascule | idem, données restaurées depuis l'export |

Parallélisme : une app en vol par archétype ; jamais deux bascules la même nuit. Le retrait du chemin kube-ops se fait
par PR dans kube-ops après 14 jours (T-052). D, E et F (21 entrées sur 35 [R T-050]) restent sur kube-ops : la cible
est **deux chemins de livraison**, ce qui est une limite du gain (§6, R6).

### Phase 6 — Déploiement hybride final
CP OpenChoreo à l'emplacement tranché par la porte 2 ; DP `homelab` (VM lab) et, sur demande de Paul, DP `oke` ;
kube-ops garde le socle du homelab et les apps D/E/F ; OKE retrouve un rôle décidé par Paul (le banc libéré).

### 4.1 Effet sur les tickets en file
| Ticket | Effet | Pourquoi |
|---|---|---|
| T-211 | **modifié** : devient la porte 2 (exploitation) ; dépend de T-488 ; la ligne « jamais de mesure sur OKE » est retirée | ADR-0025 |
| T-212 | **modifié et avancé (S2 → S1)** : bras K = chemin kube-ops reproduit, au lieu d'un backend plain neuf | le vrai comparateur existe déjà |
| T-361, T-366 | **retardés** : dépendent de T-488 (porte 1 positive) ; T-362, T-363, T-364 suivent par dépendance | gestes MANDAT gardés pour une valeur prouvée |
| T-005 | **avancé** : preuve runtime sur OKE (T-487) au lieu du cluster lab (T-364) | observation des agents nécessaire au banc |
| T-006 | **avancé** par T-005, inchangé sur le fond | même canal pour les deux bras |
| T-015 | inchangé ; `ntfy` sert aux tâches T3 et T5 | — |
| T-044 | **modifié** : le banc d'intentions se joue sur le cluster de la porte (OKE pour la porte 1) | — |
| T-051 | inchangé (après FINAL0) ; retardé de fait par la porte 2 | donnée réelle |
| T-052 | **modifié** (reste gelé) : ordre et critères de bascule du §4 phase 5 | — |
| T-002 | inchangé ; la répétition sur Mac n'est pas une CI | k3d ≠ OKE |
| T-360 | inchangé, hors chemin critique de la porte 1 | lecture seule, utile à la porte 2 |
| T-485 à T-488 | **ajoutés** : protocole, répétition Mac, réinitialisation OKE, banc compté et porte 1 | — |

## 5. Gestes de Paul et travail autonome

### 5.1 Gestes de Paul, dans l'ordre
1. Accepter ou amender ce document et ADR-0025, et les seuils du §2.4 **avant** toute mesure.
2. Dire si le MacBook est Apple Silicon, et consigner que Colima est permis pour ce dépôt (le journal de homelab-infra
   interdit « la VM Linux du Mac » aux agents ; la portée exacte de cet interdit est à préciser).
3. Créer le dépôt privé du bac à sable du bras K et y donner accès à l'App de l'usine.
4. Consigner le gel d'`oracle-a1` dans le journal de homelab-infra (fenêtre de 3 semaines, Hindsight de drill compris).
5. Ouvrir la session bastion OKE et faire l'amorçage ESO de la réinitialisation, comme le 2026-11-17.
6. Autoriser la libération des volumes de drill (option : T2 sur OKE au lieu du Mac).
7. Créer l'identité qui publie le statut dans GitHub (T-005, MANDAT ; registre `docs/state/identities.yaml`).
8. Décider la porte 1 sur le rapport de T-488.

### 5.2 Ce que les agents font seuls, en parallèle
- Tout de suite : T-485, T-212 (contenu du bras K), T-005 et T-003 en CI k3d, T-006 (doc), sans attendre Paul.
- Après les gestes 2 et 3 : T-486 (répétition, coordinateur sur le Mac).
- Après les gestes 4 à 7 : T-487 (coordinateur), puis T-488 (usine, 3 runs en parallèle au plus, bras alternés).
- Pendant toute la porte 1 : aucune écriture sur le homelab ni sur kube-ops.

### 5.3 Règle de routage à prouver en porte 2
« Si `apps/<app>/app.yaml` existe, l'app vit dans OpenChoreo ; sinon, kube-ops. » La porte 2 vérifie qu'un agent
applique cette règle sans erreur sur 10 demandes mêlées, et mesure la part des PR applicatives de kube-ops sur 90 jours
qui touchent une app A, B ou C (lecture de l'historique non faite ici : refusée depuis ce worktree, NOT_PROVEN).

## 6. Risques et limites
| Id | Risque | Parade |
|---|---|---|
| R1 | Le POC prouve qu'OpenChoreo s'installe, pas qu'il aide les agents | tâches orientées résultat, graders par code, comparateur réel, seuils préenregistrés, arrêt écrit |
| R2 | Bras K handicapé (sans `kubectl-ro`) | même canal pour les deux bras, dit dans le rapport ; S5 relu avec cette réserve |
| R3 | Échantillon petit (3 runs) : variance forte | médianes et pass^3 ; aucun test statistique revendiqué ; tailles d'effet publiées |
| R4 | Biais de l'auteur (le protocole est écrit côté OpenChoreo) | revue de fidélité du bras K côté kube-ops ; dépôt K figé, non modifié |
| R5 | OKE : 35 pods au plus, 1 830m / 8,4 Gio allouables [R] | bras joués l'un après l'autre, purge entre tâches, repli Mac |
| R6 | 21 apps sur 35 restent hors contrat : deux chemins à connaître | règle de routage en une ligne (§5.3), mesurée en porte 2 |
| R7 | Arrêt de la pile OKE de kube-ops (Hindsight de drill, plans Authentik/médias sur OKE) | inventaire préalable, fenêtre bornée, décision de Paul au journal |
| R8 | Différences arm64 (OKE, Mac) / amd64 (homelab) | porte 2 obligatoire avant toute migration ; T-366 |
| R9 | Point de sécurité amont (bundle) | bundle 1.0.1 épinglé, aucun détail public |

**Reste NOT_TESTED après la porte 1** : homelab et VM lab ; bundle amd64 ; multi-cluster et flux hybrides ; jour 2
(montée de patch, reconstruction amd64) ; données réelles, sauvegarde et restauration ; OIDC Authentik ; exposition
publique ; concurrence de plusieurs agents sur la même app ; exploitation sur plusieurs semaines ; apps D, E, F ;
coût d'agent côté kube-ops hors banc (F9). Un PASS de la porte 1 ne vaut **pas** feu vert de migration.

## 7. Faits manquants et mesure la moins chère
| Fait | Mesure proposée |
|---|---|
| Empreinte réelle d'OpenChoreo + Argo + CNPG sur OKE | phase 2 étape 4 (`tools/oke/verify.sh`, lecture) |
| Contenu réel de la pile kube-ops sur OKE | `just runtime-inventory` côté kube-ops, lecture seule, avant le gel |
| Architecture du MacBook | question à Paul (geste 2) |
| Image arm64 de `it-tools`, `vikunja`, `ntfy` | `docker manifest inspect` en phase 0 (sans cluster) |
| Part des PR kube-ops sur les apps A/B/C | `git log` du checkout kube-ops par une session hors worktree (porte 2) |
| Volumes de bloc réellement libres | lecture OCI par la racine `oracle-a1` de homelab-infra (ARC, plan seul) |
