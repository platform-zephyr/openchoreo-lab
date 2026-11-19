# CI k3d : suites d'intégration sur clusters jetables

Workflow : `.github/workflows/k3d-integration.yml`. Non bloquant en dev : l'agrégat `k3d-ok` ne fait pas partie de `ci-ok`. Voie choisie pour le rendre requis à FINAL0 (T-435) : check séparé `k3d-ok` dans `main-final.json`, `ci-ok` inchangé (variante « needs de ci-ok » écartée).

## 1. Principe

- Un job = un runner `ubuntu-24.04-arm` (4 vCPU, 16 Go) = un cluster k3d créé puis supprimé. Aucun état partagé, aucun accès au k3d du Mac ni à Colima, aucun accès OKE.
- Outils épinglés (k3d 5.9.0, yq 4.54.3, helm v3.22.1) vérifiés par sha256. Noyau `rancher/k3s:v1.36.1-k3s1`.
- Aucun secret. Permissions `contents: read`. Preuves (`tests/<suite>/evidence`) et journal publiés en artefacts publics, rétention 14 jours. Les diagnostics n'affichent que des `describe` et des journaux, jamais de valeur de Secret.
- `tools/k3d/ci-bootstrap.sh` installe OpenChoreo 1.3.3 minimal (étapes 1 à 9 de `tools/oke/install.sh`, mêmes charts, values et sha256 de `platform/install/versions.env`). Sans les gardes OKE, sans Cilium (NetworkPolicy de l'étape 2), sans Argo CD (étape 11), sans Backstage (`--set backstage.enabled=false`, comme l'étape 6).
- Limite « chart sans security bundle » : la CI installe le chart OpenChoreo standard, SANS le security bundle exigé par `tools/oke/install.sh` (`docs/SECURITY-BUNDLE.md`). Un PASS en CI ne prouve pas l'installation durcie utilisée sur OKE. La limite est rappelée dans le résumé de chaque job `bootstrap=oc`.
- Déclencheurs : **`workflow_dispatch`** et **label `k3d` posé sur une PR** (D-6), plus `merge_group` (ci-dessous). Aucune suite ne tourne sur push ni la nuit (décision de Paul, 2026-11-18) : elles ne freinent pas les itérations des agents. Quand et comment les réactiver : `docs/research/K3D-REACTIVATION.md` (T-452, à arbitrer par Paul). Le texte de `docs/research/CI-SPEED.md` §4 (PR filtrée, push sur `main`, nuit) décrit l'état antérieur.
- Déclencheur `merge_group` (T-435) : il publie `k3d-ok` dans la file de fusion. La porte lance les suites seulement si la variable de dépôt `K3D_REQUIRED` vaut `true` et si le groupe touche `platform/`, `tools/{oke,k3d,appgen}/`, `tests/{k3d,vap,argo-escalation,gitops-k3d}/` ou ce workflow. Sinon elle dit « non lancé » et `k3d-ok` est vert sans suite (ex. PR `apps/`). Tant que `K3D_REQUIRED` n'est pas posée (dev), aucune suite ne tourne dans la file : `k3d-ok` vert = NOT_TESTED, écrit dans le résumé du run et en annotation (T-513). **Une fusion n'est pas une preuve k3d** (constat et décision : §6).
- Audit API server (suite `vap`) : une sonde vérifie que `/var/log/lab-audit.log` reçoit des événements. Sinon les tests `AUD-*` sont NOT_TESTED (jamais PASS) et le résumé le dit.

## 2. Contournements temporaires

- Environnement `development` : plus de contournement (T-003). `platform/install/manifests/40-openchoreo-env.yaml` déclare `development` et `production` et le chemin de promotion ; `tools/k3d/ci-bootstrap.sh` applique ce manifeste sans rien dériver.

## 3. Suites (runs de référence 44287620940 et 44288812441, 2026-11-18)

Statuts : PASS, FAIL (non bloquant, visible), KNOWN_FAIL (échec connu documenté, le test est exécuté et non contourné), NOT_TESTED (test non exécuté, à ne jamais lire comme PASS).

| Suite | Cluster | Bootstrap | Statut | Détail |
|---|---|---|---|---|
| `vap` | `lab-sec-vap` (audit API server activé) | non | FAIL | 91 PASS, 1 FAIL : B-09 (écart kube-ops connu, `tests/vap/RESULTS.md`). AUD-* : PASS avec preuves d'audit réelles (40, 9, 1 événements). Job 1 min 11 s (PR) à 5 min 22 s (`main`) |
| `argo-escalation` | `argo-esc` | non (installe Argo) | PASS | Job 23 min 22 s |
| `k3d` | `openchoreo` | oui (environ 4 min) | FAIL | Bloque au test T12 / RRB `t-alpha-db` (voir §4). Job 8 min (bootstrap 81-89 s) |
| `gitops-k3d` (gardé dans la matrice, jamais retiré) | `gitops` | oui | KNOWN_FAIL | Le patch T-DEPLOY cherche l'ancre `isProduction: true` suivie de `---` dans `40-openchoreo-env.yaml`, que main a changée. T-ARGO-HEALTH est déjà FAIL connu. La suite s'arrête après T-SWITCH (77 s) : un job vert n'est qu'un KNOWN_FAIL. Job 3 min 20 à 3 min 45 |

Non lancé : `phase2-whoami` (absent d'`origin/main`, dépend du k3d partagé et d'une image locale seca1).

## 4. Limites connues

- `k3d` / RRB `t-alpha-db` non Ready : cause prouvée par le diagnostic, ce n'est pas un problème d'ordre de démarrage. Le PushSecret `r-*-pg-role` écrit dans la clé `lab-pg-roles/<nom>` du store `lab-store` (provider Kubernetes d'ESO 2.0.1), et ESO refuse le `/` (`invalid resource name`). La clé est définie dans `platform/resource-types/cnpg-lab-db.yaml` (l.114, l.212) et contrôlée par `platform/policies/vap-cluster-agent-scope.yaml`. Corriger impose un changement de contrat (classe REVUE).
- Triage T-469 des 24 FAIL du run 44313941923 (2026-11-18, PR #69) : une seule cause d'environnement en explique 22. Détail cas par cas : `backlog/T-469-triage-echecs-suite-k3d.md`.
  - Cause racine (défaut de fixture, pas du produit) : les Project de `tests/k3d/fixtures/10-projects.yaml` citaient le `DeploymentPipeline` `default`, absent de la CI (le bootstrap n'installe que `standard`, sans chemin de promotion). Journal du controller-manager : `DeploymentPipeline "default" not found`. Avec `autoDeploy: true`, aucun ReleaseBinding n'est créé : aucun pod de cellule, 11 attentes `timeout` (5 x 300 s, 6 x 180 s), sondes A/B vides. Cascade : T01g, T02, T03a, T04a, T05, T06a-c, T06e, T07b-d, T08a-d, T09a/b (+3 REVOKE), T10.
  - Correctif (fixture `t-pipeline` development vers production) : NOT_TESTED tant qu'un dispatch daté ne l'a pas confirmé.
  - T03f et T03i : tests périmés face aux VAP durcies (R3 labels PSA et `cell`, R6 gabarit du Job). Refus voulus, pas des défauts produit. Tests alignés sur le gabarit réel.
  - Aucun cas n'est classé `KNOWN_FAIL` : aucune cause ne justifie de garder un cas rouge. `run.sh` n'a pas de mécanisme `KNOWN_FAIL` par cas (voir `tests/vap/known-fail.sh`) et n'en a pas besoin ici.
- `argo-escalation` (T-505, 2026-11-19) : la suite échouait sur main (run 44495170272, 0fc7412) et sur la PR #169 (run 44435032144) à l'attente du Cluster `lab-pg`. Cause : `lab-platform` synchronise des `CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy` (T-494, T-006) et le cluster de la suite n'a pas les CRD ; Argo CD refuse alors toute la synchro. Correctif : `tests/argo-escalation/cilium-crds.yaml` (CRD minimales à schéma permissif) et garde `cilium_crds_check` qui refuse tout de suite une nouvelle kind `cilium.io` sans CRD. Dernier run vert avant T-494 : 44410837626. Les runs `merge_group` ne lancent aucune suite tant que `K3D_REQUIRED` n'est pas posée : leur vert ne prouve rien. Preuve du correctif : PASS, niveau CI, dispatch du 2026-11-19 sur la branche T-505 (run 44501238351) : k3d, vap, gitops-k3d et argo-escalation verts.
- `argo-escalation` (T-514, 2026-11-19) : nouvel échec au bootstrap (run 44507884152, branche T-517 sur c413af7), sans lien avec T-517. Cause (niveau statique : code et chronologie) : depuis T-502 (#174), l'ApplicationSet `lab-o` lit `clusters/oke/lab-o-apps.yaml`, que `run.sh` ne copie pas dans le dépôt de test. Aucune Application `lab-o-*` n'est rendue et l'attente de `lab-o-whoami` expire (180 s). Le PASS de T-505 (44501238351) est antérieur à #174 et contenait `P-PLATFORM FAIL` non compté : `run.sh` ne retourne pas d'échec sur un cas `FAIL`. Correctifs proposés et mesures : `backlog/evidence/T-514-mesure-k3d-2026-11-19.md`.
- Reproductibilité mesurée (T-514, 17 runs complets du 2026-11-18 au 2026-11-19, lecture API) : `argo-escalation` 13 PASS, 4 FAIL, PASS en 20 à 23 min, FAIL en 4 min ; les 4 FAIL relèvent de 2 causes déterministes (CRD Cilium, puis `clusters/` non copié), aucun échec intermittent observé. `gitops-k3d` 15/2 (12 à 22 min), `k3d` 10/7 (3 à 4 min), `vap` 14/3 (1 min environ). 3 exécutions consécutives sur un même commit : NOT_TESTED.
- Test T08f (IMDS) : NOT_TESTED par conception, comme sur k3d local.
- Le dispatch manuel n'est possible qu'une fois le workflow sur `main`.
- Le k3s n'est pas épinglé par digest, seulement par tag de version.

## 5. Lancer à la main

Depuis n'importe quelle branche (le workflow est sur `main`) :

```
gh workflow run k3d-integration.yml --ref <branche>
gh run watch <id>
gh run view <id> --json jobs --jq '.jobs[]|"\(.name) \(.conclusion)"'
```

Ou poser le label `k3d` sur la PR (événement `labeled` : toutes les suites ; tout nouveau label sur la PR relance et annule le run en cours).

Les preuves : `gh run download <id> -n k3d-<suite>`.

## 6. Rendre requis : décision `K3D_REQUIRED` (T-513, 2026-11-19)

**Proposition : poser `K3D_REQUIRED=true` à FINAL0 (T-435, T-400), pas maintenant, pas « jamais ».** Validée par Paul
s'il fusionne la PR T-513. Jusque-là, une fusion n'est pas une preuve k3d : la preuve d'une PR qui touche les chemins
des suites est un dispatch daté sur sa branche (§5) ou le label `k3d`.

### 6.1 Constat (mesuré, API GitHub Actions en lecture, 2026-11-19)

- Variable de dépôt `K3D_REQUIRED` : absente (`gh variable list` vide). Ruleset `main-protection` : file de fusion active ; `k3d-ok` non requis.
- Les 9 runs `merge_group` de `k3d-integration` (44428540374 à 44504718229, PR #158 à #182) : `gate` success, suites `skipped`, `k3d-ok` success, 16 à 22 s. Quatre de ces PR (#158, #165, #166, #182) touchaient pourtant les chemins des suites.
- Le `k3d-ok` vert sans suite écrit désormais `NOT_TESTED` dans le résumé et en annotation (workflow, T-513).

### 6.2 Coût

| Mesure | Valeur |
|---|---|
| Run complet sur `main` (44410837626, 2026-11-18) | mural 24 min ; jobs : `argo-escalation` 23 min 43, `gitops-k3d` 18 min 58, `k3d` 4 min 19, `vap` 1 min 20 ; total ≈ 48 min de runner, 4 runners en parallèle |
| Dispatch T-505 (44501238351, 2026-11-19) | mural 24 min ; ≈ 48 min de runner |
| Minutes facturées | 0 : runners `ubuntu-24.04-arm` standards gratuits en dépôt public. Le coût réel est la concurrence (4 des ~20 jobs simultanés du plan Free) et l'attente |
| PR fusionnées qui touchent les chemins des suites | 27 sur 100 (2026-11-18 14:32 au 2026-11-19 10:36 UTC, ~20 h) ; 9 sur 22 depuis l'arrivée de la file (2026-11-19 00:20) |
| Estimation si posée maintenant | ≈ 30 groupes par jour × 48 min ≈ 1 500 min de runner par jour [E] ; avec `k3d-ok` requis, chaque groupe concerné attend ~24 min dans la file |

### 6.3 Options

| Option | Effet | Verdict |
|---|---|---|
| Maintenant, sans `k3d-ok` requis | 1 500 min/jour et 4 runners pris 24 min par groupe ; la file n'attend pas le résultat : la fusion ne prouve toujours rien | Écartée : coût sans preuve, contraire à D-2 |
| Maintenant, avec `k3d-ok` requis | Preuve à chaque fusion ; ~24 min d'attente par groupe concerné ; un FAIL bloque la file | Écartée en dev (D-2) : c'est FINAL0 |
| **À FINAL0, avec le ruleset** | Une fusion = preuve k3d pour les chemins des suites | **Retenue** |
| Jamais | `k3d-ok` jamais une preuve ; contraire à T-400 et ADR-0002 §4 | Écartée |

Complexité justifiée : une variable de dépôt (`vars`, primitive native de GitHub) est le plus petit interrupteur
possible sans jeton. Autres voies écartées : supprimer la variable (les suites tournent tout de suite) ; retirer
`merge_group` jusqu'à FINAL0 (deux changements à FINAL0 au lieu d'un geste, et une file bloquée si l'ordre est faux) ;
lire le ruleset par l'API dans la porte (appel réseau et code de plus pour le même résultat).

### 6.4 Gestes de Paul à FINAL0 (dans cet ordre)

1. Poser la variable : `gh variable set K3D_REQUIRED --body true` (ou Settings > Secrets and variables > Actions > Variables). Geste humain : aucun agent ne la pose.
2. Puis appliquer `main-final.json` (créé par T-400) avec `{"context": "k3d-ok"}` dans `required_status_checks`, à côté de `ci-ok` (inchangé). Ordre inverse = `k3d-ok` requis mais vert sans suite pendant l'intervalle.
3. Vérifier le premier run `merge_group` qui touche les chemins des suites : suites lancées (pas `skipped`). Essai daté de la file : NOT_TESTED jusque-là.

Prérequis (calendrier et forme : `docs/research/K3D-REACTIVATION.md` §3, nuit seule avant T-364, suite réduite requise
à FINAL0) :

1. Corriger les FAIL et KNOWN_FAIL déclarés : B-09 (écart kube-ops), T12 (clé ESO), gitops (ancre du test, PR séparée sous `tests/`) ; issue #49 : contournement retiré par T-003.
2. Trois exécutions vertes consécutives de chaque suite retenue, sur `main`.
3. `k3d-ok` reste un check séparé : `ci.yaml` n'est pas modifié (variante « `needs` de `ci-ok` » écartée, voir l'en-tête).
