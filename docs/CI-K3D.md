# CI k3d : suites d'intégration sur clusters jetables

Workflow : `.github/workflows/k3d-integration.yml`. Non bloquant en dev : l'agrégat `k3d-ok` ne fait pas partie de `ci-ok`. Voie choisie pour le rendre requis à FINAL0 (T-435) : check séparé `k3d-ok` dans `main-final.json`, `ci-ok` inchangé (variante « needs de ci-ok » écartée).

## 1. Principe

- Un job = un runner `ubuntu-24.04-arm` (4 vCPU, 16 Go) = un cluster k3d créé puis supprimé. Aucun état partagé, aucun accès au k3d du Mac ni à Colima, aucun accès OKE.
- Outils épinglés (k3d 5.9.0, yq 4.54.3, helm v3.22.1) vérifiés par sha256. Noyau `rancher/k3s:v1.36.1-k3s1`.
- Aucun secret. Permissions `contents: read`. Preuves (`tests/<suite>/evidence`) et journal publiés en artefacts publics, rétention 14 jours. Les diagnostics n'affichent que des `describe` et des journaux, jamais de valeur de Secret.
- `tools/k3d/ci-bootstrap.sh` installe OpenChoreo 1.3.3 minimal (étapes 1 à 9 de `tools/oke/install.sh`, mêmes charts, values et sha256 de `platform/install/versions.env`). Sans les gardes OKE, sans Cilium (NetworkPolicy de l'étape 2), sans Argo CD (étape 11), sans Backstage (`--set backstage.enabled=false`, comme l'étape 6).
- Limite « chart sans security bundle » : la CI installe le chart OpenChoreo standard, SANS le security bundle exigé par `tools/oke/install.sh` (`docs/SECURITY-BUNDLE.md`). Un PASS en CI ne prouve pas l'installation durcie utilisée sur OKE. La limite est rappelée dans le résumé de chaque job `bootstrap=oc`.
- Déclencheur : **`workflow_dispatch` seulement** (décision de Paul, 2026-11-18). Aucune suite ne tourne sur PR, sur push ni la nuit : elles ne freinent pas les itérations des agents. Quand et comment les réactiver : `docs/research/K3D-REACTIVATION.md` (T-452, à arbitrer par Paul). Le texte de `docs/research/CI-SPEED.md` §4 (PR filtrée, push sur `main`, nuit) décrit l'état antérieur.
- Déclencheur `merge_group` (T-435) : il publie `k3d-ok` dans la file de fusion. La porte lance les suites seulement si la variable de dépôt `K3D_REQUIRED` vaut `true` et si le groupe touche `platform/`, `tools/{oke,k3d,appgen}/`, `tests/{k3d,vap,argo-escalation,gitops-k3d}/` ou ce workflow. Sinon elle dit « non lancé » et `k3d-ok` est vert sans suite (ex. PR `apps/`). Tant que `K3D_REQUIRED` n'est pas posée (dev), aucune suite ne tourne dans la file.
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
- Test T08f (IMDS) : NOT_TESTED par conception, comme sur k3d local.
- Le dispatch manuel n'est possible qu'une fois le workflow sur `main`.
- Le k3s n'est pas épinglé par digest, seulement par tag de version.

## 5. Lancer à la main

Seul déclencheur actif. Depuis n'importe quelle branche (le workflow est sur `main`) :

```
gh workflow run k3d-integration.yml --ref <branche>
gh run watch <id>
gh run view <id> --json jobs --jq '.jobs[]|"\(.name) \(.conclusion)"'
```

Le label `k3d` sur une PR ne lance plus rien tant que le déclencheur `pull_request` est retiré.

Les preuves : `gh run download <id> -n k3d-<suite>`.

## 6. Rendre requis (plan)

FINAL0 (T-435, T-400) : Paul pose la variable de dépôt `K3D_REQUIRED=true`, puis applique `main-final.json` avec `{"context": "k3d-ok"}` ajouté à `required_status_checks` à côté de `ci-ok` (inchangé). `main-final.json` est créé par T-400 ; T-435 ne le crée pas (le test `tests/github-config` exige son absence en dev). Essai daté de la file : NOT_TESTED jusqu'à cette application.

Calendrier et forme proposés (nuit seule avant T-364, suite réduite requise à FINAL0) : `docs/research/K3D-REACTIVATION.md` §3.

1. Corriger les FAIL et KNOWN_FAIL déclarés : B-09 (écart kube-ops), T12 (clé ESO), gitops (ancre du test, PR séparée sous `tests/`) ; issue #49 : contournement retiré par T-003.
2. Trois exécutions vertes consécutives de chaque suite retenue, sur `main`.
3. Ajouter `k3d-ok` à `needs` de `ci-ok` dans `.github/workflows/ci.yaml`, puis mettre à jour la protection de branche (`tools/apply-branch-protection.sh`).
