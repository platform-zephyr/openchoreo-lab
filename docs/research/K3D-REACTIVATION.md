---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Réactiver les suites k3d : quand et sous quelle forme (T-452)

Date : 2026-11-18. Légende : **[M]** mesuré (API GitHub Actions en lecture, ou dépôt) ; **[V]** source lue ; **[E]** estimation ;
**NOT_PROVEN** affirmation non vérifiée. Ce rapport est une étude : il ne réactive aucune suite et ne touche ni `ci.yaml`
ni `k3d-integration.yml`. Les décisions marquées **D-n** sont attendues de Paul (§7).

## 0. Conclusion

1. **Garder le dispatch manuel jusqu'à la fin de S1**, puis **réactiver en nuit seule, non bloquante, avant le début de
   T-364** (OpenChoreo sur la VM lab). Coût : environ **40 min de runner par nuit**, gratuites en dépôt public ; aucun
   effet sur `ci-ok` ni sur le merge des agents.
2. **Ne jamais remettre le déclencheur « push sur `main` »** avant FINAL0. Avec 50 commits sur `main` en 1,5 jour [M],
   il coûterait environ 1 000 min de runner par jour [E]. Surtout, il occuperait 4 des ~20 slots de jobs pendant
   24 min à chaque merge, alors qu'un seul run `ci` prend déjà 16 jobs [M]. Il ralentirait donc `ci-ok` de tous les agents.
3. **Avant de réactiver la nuit, corriger les 3 échecs connus** par de petites PR vérifiées par dispatch manuel sur la
   branche. Sinon la nuit est rouge chaque jour et le signal ne vaut rien. Coût total estimé : **3 PR, 3 à 5 heures d'agent** [E].
4. **Rendre k3d requis seulement à FINAL0**, sous une forme réduite et filtrée par chemins du noyau (`vap` + `k3d`,
   `argo-escalation` seulement si la frontière Argo change). C'est déjà ce que T-400 exige (`k3d-ok` dans `main-final.json`).
   **T-435 (« k3d-ok requis », étape S1) contredit la décision de Paul** et doit passer en FINAL0 (D-2).
5. **La valeur des suites est réelle.** `k3d` a trouvé un vrai défaut du produit (T12 : la base de l'archétype B ne
   peut pas devenir Ready avec le store `lab-store` du dépôt), invisible pour toute la CI statique. Le report est donc
   un risque accepté, pas une perte nulle.
6. **ADR-0002 §4** (« une PR qui touche `platform/` doit avoir la CI k3d verte ») est suspendu de fait. Un amendement de
   Paul doit le dater : « à partir de FINAL0 » (D-1).

## 1. Ce que chaque suite prouve, et ce qui n'est couvert nulle part ailleurs

`ci-ok` (16 jobs statiques [M]) couvre : schéma et rendu d'`appgen`, kubeconform contre les CRD v1.3.3, règles Argo
statiques (`argo_guard.py`, 41 cas négatifs), PSA statique des rendus, cellule restreinte statique (`tests/cell-cpt`),
Kyverno en CLI, garde de fuite et gitleaks. Aucun job de `ci-ok` ne démarre d'API server.

| Suite | Ce qu'elle prouve (runtime k3d) | Couvert ailleurs ? | Exclusif à la suite |
|---|---|---|---|
| `vap` (`tests/vap/run.sh`, 92 cas) | Les CEL de `platform/policies/` sont **évaluées par un vrai API server** : refus de l'agent hors `dp-*`, sous-ressources (exec, ephemeralcontainers, status/finalize), R6 lab-pg, R2b, audit `Deny,Audit` | kubeconform valide le schéma, pas la CEL ni son type-check ; aucun test statique n'évalue `matchConditions` | **Oui** : une CEL qui ne compile pas, qui échoue « fermée » par erreur ou qui laisse passer une sous-ressource. Exemple réel : 10 FAIL avant correctif, dont 1 contournement PSA (`tests/vap/RESULTS.md`) |
| `argo-escalation` (21 cas) | Un **vrai Argo CD** applique les AppProject et les fenêtres de synchro : un commit malveillant dans `generated/`, `apps/` ou `platform/` est refusé par Argo | `argo_guard.py` vérifie les mêmes règles **statiquement** à chaque PR (`ci-ok`) | **Partiel** : le comportement réel d'Argo (fenêtres `deny`, refus `InvalidSpecError`, N7b accepté par conception). Utile surtout quand `platform/install/argocd/`, les values Argo ou la version d'Argo changent |
| `k3d` (`tests/k3d/run.sh`, 52 cas) | OpenChoreo 1.3.3 CP + DP réellement installés : PSA de cellule, traits refusés, VAP-1/VAP-2 sur des pods réels, NetworkPolicy appliquées (kube-router), base CNPG par app avec rôle et TLS, REVOKE | `tests/cell-cpt` (statique) ; rien pour CNPG, ESO, NetworkPolicy ni pour le rendu réel des CCT/CRT | **Oui** : la chaîne CRT → PushSecret → ESO → secret de cellule. Exemple réel : T12 (§2.2), invisible statiquement |
| `gitops-k3d` (26 cas, bloqué tôt) | Boucle complète `app.yaml` → `appgen` → Argo → OpenChoreo → pod → HTTP 200 → modification → dérive → rollback | Rien d'autre ne fait la boucle complète hors OKE (pilote manuel du 2026-11-17) | **Oui en théorie, non en pratique** : la suite s'arrête à T-DEPLOY (§2.3). Le job « vert » de 77 s [M] n'est qu'un `KNOWN_FAIL` |

Limites communes, à ne jamais lire comme un PASS :
- k3d ≠ homelab ≠ OKE. Pas de Cilium, pas de security bundle, pas d'IMDS (T08f NOT_TESTED), noyau k3s par tag.
- Le chart OpenChoreo de la CI est installé **sans** security bundle (`docs/CI-K3D.md` §1).
- `development` est dérivé de `production` tant que `platform/` ne le fournit pas (issue #49).

## 2. Échecs connus et coût de correction

Run de référence : `k3d-integration` 44287620940 (PR, 2026-11-18 10:40-11:04 UTC) et 44288812441 (push `main`,
10:48 UTC) [M].

| Suite | Résultat [M] | Durée du job [M] | Dont suite |
|---|---|---|---|
| `vap` | FAIL (B-09) | 1 min 11 s (PR) ; 5 min 22 s (`main`) | 29 s ; 4 min 48 s |
| `argo-escalation` | PASS | 23 min 22 s | 22 min 48 s |
| `k3d` | FAIL (T12) | 7 min 59 s ; 8 min 4 s | bootstrap 81-89 s, suite 6 min |
| `gitops-k3d` | KNOWN_FAIL (exit 0) | 3 min 44 s ; 3 min 18 s | 77 s |

### 2.1 `vap` / B-09 (écart de la baseline kube-ops)

- Fait : un conteneur éphémère `privileged` hors `dp-*` (`pods/ephemeralcontainers`) est admis. La baseline exportée
  d'OKE (`tests/vap/fixtures/baseline-oke-export.json`) ne couvre pas cette sous-ressource. Dans `dp-*` et `lab-pg`,
  VAP-2 le refuse déjà (V2-07b PASS).
- Le défaut est **hors de ce dépôt** (kube-ops). La cible a changé : le CP part sur la VM lab du homelab (D11), avec sa
  propre baseline (T-363).
- Correction, deux voies :
  - **A (recommandée, 30-60 min d'agent)** : classer B-09 `KNOWN_FAIL` **au niveau du cas** dans `tests/vap/run.sh`.
    Le cas reste exécuté, son verdict reste visible et la suite rend 0 s'il n'y a pas d'autre FAIL ; s'il passe un jour,
    la suite l'annonce (même règle que `gitops-k3d`). Chemin noyau (`tests/vap/`) : REVUE, merge après `ci-ok` en mode dev.
  - **B (vraie correction, 1-2 h + geste kube-ops)** : ajouter `pods/ephemeralcontainers` à la baseline de la VM lab
    (T-363) et rafraîchir la fixture. Dépend de T-363 et d'un autre dépôt.
- Ce n'est **pas** un contournement : aucune politique n'est désactivée, seul le verdict agrégé change, avec trace.

### 2.2 `k3d` / T12 (clé ESO invalide, défaut réel du produit)

- Fait : le PushSecret `r-*-pg-role` écrit la clé `lab-pg-roles/<nom>` dans `lab-store`. `lab-store` utilise le
  **provider kubernetes** d'ESO (`platform/install/manifests/20-eso-lab-store.yaml`), qui refuse le `/`
  (`invalid resource name`). Le RRB `t-alpha-db` ne devient jamais Ready. Le PASS local du 2026-11-17
  (`tests/k3d/RESULTS.md`, T12a-d) utilisait OpenBao, où `/` est un chemin valide : le changement de store a cassé
  l'archétype B sans qu'aucun test statique ne le voie.
- Conséquence : **toute app de l'archétype B (Postgres) échouera** sur une plateforme installée par
  `platform/install/`. L'archétype A (porte ADR-0020, C1) n'est pas touché.
- Correction (2-3 h d'agent, une PR REVUE) : remplacer le séparateur par un caractère admis (ex. `lab-pg-roles-<nom>`)
  dans `platform/resource-types/cnpg-lab-db.yaml` (l. 114 et 212), aligner la règle R6 de
  `platform/policies/vap-cluster-agent-scope.yaml` (`startsWith('lab-pg-roles/')`, l. 177) et les cas P05/P01 de
  `tests/vap/`, puis prouver par dispatch manuel de `k3d` **et** `vap` sur la branche. Si OpenBao devient le store
  (T-022/T-023, I2), le séparateur `-` reste valide pour les deux providers [E].
- À faire **avant le premier ticket qui livre une base** (T-051, I3 ; T-026, I1), donc bien avant FINAL0.

### 2.3 `gitops-k3d` / ancre T-DEPLOY obsolète

- Fait : T-DEPLOY patche `40-openchoreo-env.yaml` en cherchant `  isProduction: true\n---`. La correction G1
  (`gateway.ingress`) est **déjà dans `main`** : l'ancre n'existe plus, l'`assert` Python échoue, la suite s'arrête
  après T-SWITCH. Les cas T-ARGO-HEALTH, T-PRUNE-STATUS, T-PIN-STALE, T-STRATEGY et T-RETRAIT-1 (FAIL au run 4) ont été
  « corrigés statiquement » depuis : leur état runtime est **NOT_TESTED**.
- Correction (1 h d'agent pour l'ancre) : rendre le patch idempotent (sauter si `gateway.ingress.internal` est présent,
  sinon l'ajouter) ; garder `known_fail` tant que T-ARGO-HEALTH n'est pas corrigé. **Coût inconnu ensuite** : le premier
  run complet peut révéler jusqu'à 5 FAIL déjà connus.

### 2.4 Durée d'`argo-escalation` (PASS, mais 23 min)

- Cause [V, `tests/argo-escalation/run.sh`] : 10 groupes de tests strictement séquentiels sur **un seul** dépôt Git de
  test (commit → synchro → observation → revert). Environ 5 min sont des attentes fixes voulues (N9 90 s, N4 100 s,
  N1 65 s, N7a 60 s : prouver qu'Argo ne synchronise **pas** pendant une fenêtre `deny`). Le reste est du polling Argo
  (`wait_rev`, jusqu'à 180-240 s par cas).
- Options, de la moins chère à la plus chère :
  1. **Ne la lancer que si la frontière Argo change** (`platform/install/argocd/`, `platform/install/values/argocd.yaml`,
     `tools/oke/argo_guard.py`, `tests/argo-escalation/`) et chaque nuit. 0 h de code ; 9 commits sur 50 touchent le
     noyau, et moins encore la frontière Argo [M].
  2. Réduire les attentes négatives à 30 s (0,5 h) : gain ~3 min, preuve plus faible ; déconseillé.
  3. Paralléliser en 2-3 jobs sur des dépôts et AppProject distincts (4-6 h) : ~10 min de mur, mais 2-3 slots au lieu d'1.
- Recommandation : option 1. La durée n'est un problème que si la suite tourne sur chaque PR ou chaque merge.

## 3. Jalons candidats, forme et coût

### 3.1 Coût unitaire mesuré

Run 44287620940 [M] : somme des jobs **36,4 min** ; facturé à la minute supérieure par job **≈ 40 min de runner** ;
durée murale **23,7 min** (bornée par `argo-escalation`). Les runners `ubuntu-24.04-arm` standards sont **gratuits et
illimités** en dépôt public [V]. Le vrai coût est la **concurrence** : 20 jobs simultanés sur le plan Free [V ; plan de
l'organisation NOT_PROVEN], alors qu'un run `ci` lance 16 jobs [M]. Une suite k3d complète prend 4 slots pendant 4 à
24 min et peut donc retarder le `ci-ok` des agents.

### 3.2 Formes possibles

| Forme | Bloque `ci-ok` ? | Min de runner [E] | Slots occupés | Signal | Verdict |
|---|---|---|---|---|---|
| Manuel (`workflow_dispatch`, état actuel) | non | 40 par lancement | 4 pendant ≤ 24 min | seulement quand quelqu'un lance | maintenant |
| **Nuit seule**, toutes les suites, `max-parallel: 2` | non | ~40/jour (~1 200/mois) | 2 pendant ~32 min | J+1 au plus tard | **recommandé dès la fin de S1** |
| Label `k3d` sur PR (`types: [labeled]` seulement) | non | 40 par PR étiquetée | 4 | à la demande de l'agent | utile en complément, à la discrétion de l'exécutant |
| Post-merge sur `main`, chaque commit | non (mais rouge sur `main`) | 40 × ~33 commits/j ≈ 1 300/jour ; filtré par chemins (30 % [M]) ≈ 400/jour | 4 en continu | par commit | **refusé avant FINAL0** (concurrence) |
| Post-merge filtré **et regroupé** (au plus 1 run par heure, `concurrency` sans annulation) | non | ≤ 40/heure ≈ 300-600/jour | 4 | ≤ 1 h | option si la nuit ne suffit pas (après la porte) |
| Suite réduite requise sur PR du noyau (`vap` + `k3d`, `argo-escalation` si frontière Argo) | **oui**, sur ~18 % des PR [M] | ~11 min par PR concernée ; +24 si frontière Argo | 2-3 | avant merge | **FINAL0** |
| Toutes les suites requises sur toute PR | oui | 40 × chaque push (20 runs annulés en 1 h observés sur une seule branche [M]) | 4 | avant merge | **refusé** |

### 3.3 Calendrier recommandé

| Jalon (ROADMAP) | Forme | Préalable | Pourquoi |
|---|---|---|---|
| S0 → S1 (maintenant) | **manuel** ; les PR de correction lancent `gh workflow run k3d-integration.yml --ref <branche>` | aucun | priorité à la vitesse du pilote 24 h (ADR-0021) ; les 3 échecs connus rendraient la nuit rouge chaque jour |
| **Fin de S1, avant T-364** | **nuit seule, non bloquante**, `max-parallel: 2`, alerte en lecture (§4) | B-09 classé, T12 corrigé, ancre gitops corrigée ; 1 dispatch vert sur `main` | dès que `platform/` part sur un vrai cluster (VM lab), une régression de VAP ou de CRT doit être vue en ≤ 24 h, avant Argo ; coût négligeable |
| S2-S3 | nuit + label `k3d` à la discrétion de l'exécutant pour les PR `platform/policies`, `platform/resource-types`, `platform/component-types` | nuit verte | permet à un agent de vérifier son propre changement sans bloquer les autres |
| PORTE (T-211, 2026-12-04) | idem ; le rapport de porte cite les 3 dernières nuits | nuit verte | preuve d'appoint que le moteur n'est pas cassé par `platform/` ; **pas** une mesure de C1-C7 (k3d ≠ homelab) |
| I1 (premières bases) | idem ; T12 doit être PASS | T12 corrigé (§2.2) | T-026, T-051 livrent l'archétype B |
| **FINAL0** (T-404) | **suite réduite requise** par chemins du noyau, `merge_group` ajouté, `k3d-ok` vert si la porte dit « non lancé » ; nuit complète gardée | 3 nuits vertes consécutives (`docs/CI-K3D.md` §6) ; T-435 déplacé en FINAL0 | ADR-0002 §4 redevient vrai quand l'identité d'usine et le ruleset sans contournement arrivent ; T-400 l'exige |
| I1-I8 | identique à FINAL0 | — | — |
| **FINAL** (T-401) | identique ; T-401 relit 7 nuits vertes et les éventuels `KNOWN_FAIL` restants | `gitops-k3d` sans `known_fail` ou écart signé par Paul | revue de sécurité finale |

Option écartée : « requis seulement à FINAL » (pas avant). Elle laisse I1-I8 (données réelles, OpenBao, exposition
publique) sans contrôle compensatoire sur `platform/policies/`, alors que FINAL0 rétablit justement la revue sur ce chemin.

### 3.4 Ébauche du changement de workflow (non appliquée, pour décision)

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: "17 3 * * *"          # nuit seule (UTC) ; aucune PR, aucun push
  pull_request:
    types: [labeled]              # seulement quand le label `k3d` est posé (le gate le vérifie)
# suite : strategy.max-parallel: 2 sur l'événement schedule
```

`ci-ok` reste inchangé ; `k3d-ok` reste hors de `ci-ok` jusqu'à FINAL0.

## 4. Remonter l'échec sans bloquer les agents

Contraintes : les issues GitHub sont réservées au lancement d'agents (`backlog/README.md`) ; le workflow n'a que
`contents: read` ; aucun secret dans le dépôt public. Un échec de nuit ne doit ni arrêter l'usine ni bloquer un merge.

1. **Visible sans code** : le run de nuit est rouge dans l'onglet Actions, le résumé de job donne PASS / FAIL /
   KNOWN_FAIL / NOT_TESTED par suite, et les preuves sont en artefact 14 jours. La notification e-mail native des
   workflows planifiés existe, mais son destinataire n'est pas documenté de façon fiable : **NOT_PROVEN**, ne pas s'y fier.
2. **Lecture par le dispatcher (recommandé, sans permission d'écriture)** : le dispatcher (T-314) ou le trieur lit
   `gh run list --workflow k3d-integration.yml --event schedule --limit 1` avant de choisir les tickets. Si la dernière
   nuit est FAIL sur une suite non `KNOWN_FAIL`, il crée un **ticket de backlog** `fix-k3d-<suite>-<date>` (couloir `ci`,
   AUTONOME) et le place en tête du couloir. Les autres couloirs continuent. Dédoublonnage : un seul ticket ouvert par suite.
3. **Résumé quotidien** : la ligne « k3d nuit : vert / rouge (suites) » entre dans le résumé ntfy unique de T-316, quand
   il existe.
4. **Pas d'issue automatique** tant que Paul n'a pas fait d'exception (D-4). Si elle est accordée : une issue unique,
   label `k3d-nightly` (jamais `agent:dev`), mise à jour puis fermée au retour du vert, permission `issues: write` sur
   le seul job d'alerte. Idée reprise du principe de `workflow-failure-issues` (§8), sans code copié.
5. **Disjoncteur** : 3 nuits rouges de suite sur la même suite → le dispatcher gèle les tickets qui touchent les chemins
   de cette suite (pas les autres) jusqu'au retour du vert. C'est la seule forme de blocage avant FINAL0, et elle reste
   locale à un couloir.

Point de vigilance : un workflow planifié d'un dépôt public est désactivé après 60 jours sans activité [V]. Le risque
est nul avec l'usine 24/7, mais le dispatcher doit signaler une nuit absente (pas de run depuis 36 h) comme un FAIL.

## 5. Lien avec T-002 et la porte ADR-0020

- **T-002**, critère 4 (« suites vap, k3d, argo-escalation vertes ») : au 2026-11-18, seule `argo-escalation` est verte
  [M]. `vap` et `k3d` sont rouges pour B-09 et T12. Avec le dispatch manuel, T-002 ne peut se fermer que par un
  dispatch vert sur `main` après les corrections du §2. Proposition (D-3) : garder le critère tel quel et le prouver par
  ce dispatch ; T-002 n'exige pas de déclencheur automatique.
- **T-435 et T-339** dépendent de T-002 et rendent k3d plus présent dès S1 (`k3d-ok` requis ; job PR choisi par chemins).
  Ils contredisent la décision du 2026-11-18. Proposition (D-2) : T-435 en FINAL0 (il est déjà prérequis de T-400) ;
  T-339 réduit à la bibliothèque `tools/dev/cluster`, sans job PR avant FINAL0.
- **Porte ADR-0020** : C1 et C6 se mesurent sur le homelab, pas sur k3d (k3d ≠ homelab, amendement Fable §7). Les
  suites ne sont **pas** une mesure de porte. Elles servent d'appoint : une nuit verte de `k3d` et `gitops-k3d` montre
  que `platform/` n'a pas cassé le moteur pendant la mesure ; une nuit rouge explique une intention ratée sans la compter
  contre OpenChoreo. T12 ne touche pas C1 (archétype A seulement). Si la porte conclut « abandonner », `k3d` et
  `gitops-k3d` deviennent sans objet (moteur retiré) ; `vap` et `argo-escalation` restent utiles au backend plain.
- **ADR-0002 §4** : le contrôle compensatoire est suspendu de fait depuis le 2026-11-18. L'amendement « arbitrages de
  Paul n°2 » ne le mentionne pas. Proposition (D-1) : amender ADR-0002 §4 par Paul (noyau) : « suspendu pendant le
  développement, rétabli à FINAL0 sous forme réduite par chemins (`docs/research/K3D-REACTIVATION.md` §3) ».

## 6. Risques acceptés pendant le report

- Une régression de VAP ou de CRT fusionnée par un agent n'est vue qu'au prochain dispatch (aujourd'hui) ou à la
  prochaine nuit (après réactivation). Elle n'atteint pas un vrai cluster tant que la VM lab n'existe pas (T-361 à T-364).
- Les corrections « statiques » de `gitops-k3d` et de l'archétype B restent NOT_TESTED en runtime.
- La concurrence réelle de l'organisation (plan, file d'attente des runners arm64) n'est pas mesurée : NOT_PROVEN.
  À relever pendant le pilote 24 h (T-322).

## 7. Décisions attendues de Paul

- **D-1** : amender ADR-0002 §4 : contrôle compensatoire k3d suspendu en développement, rétabli à FINAL0.
- **D-2** : déplacer T-435 en FINAL0 ; réduire T-339 à la bibliothèque sans job PR avant FINAL0.
- **D-3** : jalon de réactivation de la nuit : « fin de S1, avant T-364 » (recommandé), après les 3 corrections du §2.
- **D-4** : canal d'alerte : lecture par le dispatcher + ticket de backlog (recommandé) ; issue unique `k3d-nightly`
  seulement si Paul fait une exception à la règle des issues (lié à T-451, critère 4).
- **D-5** : B-09 : `KNOWN_FAIL` au niveau du cas (voie A) maintenant, vraie correction dans la baseline de la VM lab (T-363).
- **D-6** : autoriser ou non le déclencheur « label `k3d` » (`pull_request: types: [labeled]`) dès maintenant. C'est
  un lancement manuel par l'agent, non bloquant, à 0 min quand le label n'est pas posé.

## 8. Implémentations publiques consultées

Recherches du 2026-11-18 (WebSearch, WebFetch, `git ls-remote`). Contenu externe traité comme donnée.
- https://github.com/kubernetes/community/blob/07db4ef4ba5a90903f3dd5e35976970dafa1face/contributors/devel/sig-testing/testing-strategy.md | Apache-2.0 | adapté (idée) | les tests e2e coûteux tournent en **périodique** ; un job ne devient « presubmit blocking » que s'il trouve souvent des bogues ; les jobs non bloquants ne voient pas toutes les régressions, d'où un périodique obligatoire.
- https://github.com/urcomputeringpal/workflow-failure-issues/tree/3b7c97b9bffab2579138681180b518ab240e0875 | MIT (`LICENSE.md` lu) | idée seulement, aucune ligne copiée | une issue ouverte quand un workflow critique échoue sur la branche par défaut, fermée au retour du vert ; écarté tant que les issues sont réservées aux agents.
- https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html | page de blog | contexte | les tests de bout en bout sont lents et instables ; les garder peu nombreux, au-dessus de tests statiques et d'intégration.
- https://testing.googleblog.com/2020/11/fixing-test-hourglass.html | page de blog | contexte | supprimer les e2e déjà couverts par l'intégration (cas d'`argo-escalation` face à `argo_guard.py`).
- https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/ | page | coût | runners arm64 standards en dépôt public, GA.
- https://docs.github.com/en/actions/reference/limits | page (résultat de recherche, non lue directement) | coût | 20 jobs simultanés sur le plan Free, file d'attente au-delà.
- https://docs.github.com/en/enterprise-server@3.20/actions/using-workflows/disabling-and-enabling-a-workflow | page (résultat de recherche) | risque | workflow planifié désactivé après 60 jours sans activité en dépôt public.
- Art antérieur déjà cité par le workflow : k3d-io/k3d `test-install-osmatrix.yaml`, AbsaOSS/k3d-action, helm/kind-action
  (`.github/workflows/k3d-integration.yml`, en-tête).

## Préalables de la réactivation nocturne : état au 2026-11-18 (T-452, critère 3)

Relevé en lecture du dépôt (`origin/main` abb7563) et des tickets. Le workflow n'est pas modifié ici ; l'activation reste
décidée à la fin de S1 (D-3).

| Préalable (§3.3) | État | Niveau | Preuve |
|---|---|---|---|
| B-09 classé `KNOWN_FAIL` (T-457) | fait | RUNTIME | run 44313410652 sur `main` : 91 PASS, 0 FAIL, 1 KNOWN_FAIL, RESULTAT PASS |
| T12 corrigé (T-456) | fait pour T12a-e ; la suite `k3d` reste rouge | RUNTIME | run 44313941923 (PR #69) : T12a-e PASS ; FAIL préexistants T01g, T02-T06, T03f (mêmes FAIL sur `main`, run 44313410652) |
| Ancre `gitops-k3d` (T-458) | partiel : la suite dépasse T-DEPLOY, résultat `KNOWN_FAIL` ; FAIL réapparus non classés | RUNTIME partiel | run 44313410652 ; T-458 `in-progress` |
| 1 dispatch vert sur `main` | **non atteint** : `k3d` rouge (FAIL T01g, T02-T06, T03f) | FAIL | run 44313410652 |

Conclusion : **NOT_PROVEN, pas prêt**. La condition « nuit verte » du §3.3 n'est pas remplie : activer `schedule` maintenant
rendrait la nuit rouge chaque jour (risque du §0, point 3). Ce n'est pas un échec de la décision D-3 mais un préalable
manquant, absent de la liste T-456 à T-458 : **corriger ou classer `KNOWN_FAIL` les FAIL préexistants de la suite `k3d`**
(T01g, T02-T06, T03f). Un ticket de correction reste à créer (couloir `ci`, AUTONOME) ; non créé ici.

Check-list d'activation (à exécuter à la fin de S1, hors de ce ticket) :
1. T-458 `done` ; FAIL de la suite `k3d` corrigés ou classés ; dispatch complet vert sur `main`, daté.
2. Ajouter `schedule: [{cron: "17 3 * * *"}]` dans `.github/workflows/k3d-integration.yml` (ébauche §3.4) et
   `max-parallel: 2` sur l'événement `schedule` ; `ci-ok` inchangé.
3. Vérifier que le garde de décision du workflow accepte l'événement `schedule` (en-tête, ligne « tout événement hors PR »).
4. Faire lire la dernière nuit par le dispatcher (T-314, décision D-4) et signaler une nuit absente depuis 36 h.
5. Consigner la preuve (premier run `schedule`, date, verdict par suite) puis cocher le critère 3 de T-452.

## Décisions de Paul (2026-11-18)
D-1 à D-6 acceptées telles que recommandées (voir T-452). Corrections ouvertes : T-456 (T12), T-457 (B-09), T-458 (ancre gitops-k3d).
