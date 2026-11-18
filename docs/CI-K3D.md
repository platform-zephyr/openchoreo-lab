# CI k3d : suites d'intégration sur clusters jetables

Workflow : `.github/workflows/k3d-integration.yml`. Non bloquant : l'agrégat `k3d-ok` ne fait pas partie de `ci-ok`.

## 1. Principe

- Un job = un runner `ubuntu-24.04-arm` (4 vCPU, 16 Go) = un cluster k3d créé puis supprimé. Aucun état partagé, aucun accès au k3d du Mac ni à Colima, aucun accès OKE.
- Outils épinglés (k3d 5.9.0, yq 4.54.3, helm v3.22.1) vérifiés par sha256. Noyau `rancher/k3s:v1.36.1-k3s1`.
- Aucun secret. Permissions `contents: read`. Preuves (`tests/<suite>/evidence`) et journal publiés en artefacts publics, rétention 14 jours. Les diagnostics n'affichent que des `describe` et des journaux, jamais de valeur de Secret.
- `tools/k3d/ci-bootstrap.sh` installe OpenChoreo 1.3.3 minimal (étapes 1 à 9 de `tools/oke/install.sh`, mêmes charts, values et sha256 de `platform/install/versions.env`). Sans les gardes OKE, sans Cilium (NetworkPolicy de l'étape 2), sans Argo CD (étape 11), sans Backstage (`--set backstage.enabled=false`, comme l'étape 6).
- Limite : la CI installe le chart OpenChoreo standard ; un PASS en CI ne prouve pas l'installation durcie utilisée sur OKE.

## 2. Contournements temporaires

- Environnement `development` dérivé de `40-openchoreo-env.yaml` dans `tools/k3d/ci-bootstrap.sh`. Attendu par `tests/k3d/fixtures`, absent de `platform/`. La CI teste donc une plateforme légèrement différente d'OKE. TEMPORAIRE : issue #49 l'ajoutera au manifeste de plateforme ; une fois #49 fusionnée, retirer ce bloc `yq`.

## 3. Suites (résultats du run de référence, 2026-11-18)

Statuts : PASS, FAIL (non bloquant, visible), KNOWN_FAIL (échec connu documenté, le test est exécuté et non contourné), NOT_TESTED (test non exécuté, à ne jamais lire comme PASS).

| Suite | Cluster | Bootstrap | Statut | Détail |
|---|---|---|---|---|
| `vap` | `lab-sec-vap` (audit API server activé) | non | FAIL | 91 PASS, 1 FAIL : B-09 (écart kube-ops connu, `tests/vap/RESULTS.md`). AUD-* : PASS avec preuves d'audit réelles (40, 9, 1 événements). Job environ 1 min |
| `argo-escalation` | `argo-esc` | non (installe Argo) | PASS | Job environ 23 min |
| `k3d` | `openchoreo` | oui (environ 4 min) | FAIL | Bloque au test T12 / RRB `t-alpha-db` (voir §4). Job environ 11 min |
| `gitops-k3d` | `gitops` | oui | KNOWN_FAIL | Le patch T-DEPLOY cherche l'ancre `isProduction: true` suivie de `---` dans `40-openchoreo-env.yaml`, que main a changée. T-ARGO-HEALTH est déjà FAIL connu. Job environ 4 min |

Non lancé : `phase2-whoami` (absent d'`origin/main`, dépend du k3d partagé et d'une image locale seca1).

## 4. Limites connues

- `k3d` / RRB `t-alpha-db` non Ready : cause prouvée par le diagnostic, ce n'est pas un problème d'ordre de démarrage. Le PushSecret `r-*-pg-role` écrit dans la clé `lab-pg-roles/<nom>` du store `lab-store` (provider Kubernetes d'ESO 2.0.1), et ESO refuse le `/` (`invalid resource name`). La clé est définie dans `platform/resource-types/cnpg-lab-db.yaml` (l.114, l.212) et contrôlée par `platform/policies/vap-cluster-agent-scope.yaml`. Corriger impose un changement de contrat (classe REVUE).
- Test T08f (IMDS) : NOT_TESTED par conception, comme sur k3d local.
- Le dispatch manuel n'est possible qu'une fois le workflow sur `main`.
- Le k3s n'est pas épinglé par digest, seulement par tag de version.

## 5. Lancer à la main

Depuis une branche, le workflow se déclenche par PR portant le label `k3d` :

```
gh pr edit <n> --add-label k3d
```

Une fois le fichier sur `main` :

```
gh workflow run k3d-integration.yml --ref <branche>
gh run watch <id>
gh run view <id> --json jobs --jq '.jobs[]|"\(.name) \(.conclusion)"'
```

Les preuves : `gh run download <id> -n k3d-<suite>`.

## 6. Rendre requis (plan)

1. Corriger les FAIL et KNOWN_FAIL déclarés : B-09 (écart kube-ops), T12 (clé ESO), gitops (ancre du test, PR séparée sous `tests/`), issue #49 (retirer le contournement).
2. Trois exécutions vertes consécutives de chaque suite retenue, sur `main`.
3. Ajouter `k3d-ok` à `needs` de `ci-ok` dans `.github/workflows/ci.yaml`, puis mettre à jour la protection de branche (`tools/apply-branch-protection.sh`).
