# Résultats : preuve négative Argo CD sur un vrai Argo (flux A2)

> **T-491 (2026-11-18) : NOT_TESTED.** `run.sh` cible désormais l'ApplicationSet `lab-o` (Applications `lab-o-<app>`, projet `lab-o`, contrôleur ApplicationSet à 1 réplica dans ce test). Les résultats ci-dessous datent du 2026-11-17 avec l'ancienne Application `lab-apps` ; la suite n'a pas été relancée sur k3d depuis.

**Étiquette : k3d, PAS OKE.** Le cluster jetable `k3d-lab-sec-argo` (K8s v1.35.5+k3s1, 1 nœud) a été supprimé après les tests.

- **Date** : 2026-11-17, de 20:06 à 20:28 UTC.
- **Argo CD** : chart `argo-cd` 10.3.3 (sha256 `ce2549…8007` vérifié), image `quay.io/argoproj/argocd:v3.5.1@sha256:0deb1a1c…41ee8`, values `platform/install/values/argocd.yaml` inchangées, namespace `lab-argocd`.
- **Projets et Application** : `platform/install/argocd/` de l'arbre de travail du flux A2. Ce sont les projets `lab-platform`, `lab-apps`, `lab-authz` et `lab-root`, plus `default` verrouillé, appliqués comme le fait `install.sh --step 11`.
- **CRD** :
  - OpenChoreo au commit `5336791f` (v1.3.3, le même que la CI) ;
  - CNPG à partir du chart 0.29.1 (sha256 vérifié), CRD seulement, aucun opérateur.
- **Dépôt Git de test** : copie de `platform/`, `generated/` et `apps/`, servie dans le cluster par `git daemon` (`tests/argo-escalation/git-server.yaml`, image Argo épinglée par digest). Rien n'a été poussé sur GitHub.
- **Seuls écarts au réel :**
  - l'URL GitHub est remplacée par `git://lab-gitsrv…/repo.git`, partout (`sourceRepos` et `repoURL`) ;
  - le status du Cluster CNPG `lab-pg` est simulé : sans opérateur, le health Lua d'Argo plante sur un status vide. Aucun AppProject ni aucune garde n'est touché.
- **Reproduire** : `KUBECONFIG=<k3d jetable> tests/argo-escalation/run.sh all`. Le script refuse un kubeconfig OKE et le k3d partagé `openchoreo`.
- **Interruption** : une exécution a été interrompue par un signal externe pendant N3, à 20:10. Le dépôt de test a été remis en état (revert du commit N3), puis la suite a repris à N3 (`ARGO_ESC_FROM=t_n3_kube_system`) sur le même cluster et le même Argo, à 20:16. Journaux : `evidence/run-part1.log` et `evidence/run-part2.log` ; `evidence/run-info.txt` porte les deux en-têtes.

## Synthèse : 20 PASS, 0 FAIL, 1 ACCEPTÉ (attendu, chemin privilégié)

Chaque test suit le même protocole :
1. un commit « malveillant » dans le dépôt de test ;
2. une synchro réelle, automatique (`lab-root`) ou manuelle (opération `sync` posée sur l'Application) ;
3. l'observation de l'Application Argo : `operationState`, `conditions`, résultat par ressource ;
4. l'observation de l'API server : l'objet est absent, ou son `resourceVersion` ou son label est inchangé ;
5. un revert.

Les preuves brutes sont dans `evidence/<ID>-<app>.json` (Application complète) et `evidence/<ID>-<app>.summary.json`. Les horodatages sont dans `evidence/results.tsv`.

| ID | Attaque (commit) | Résultat | État Argo observé | API server |
|---|---|---|---|---|
| P-APPS | témoin : `generated/` réel (9 apps) synchronisé par `lab-apps` | **PASS** | `lab-apps` Succeeded | Component `default/whoami` et Workloads présents |
| P-PLATFORM | témoin : annotation légitime sur la VAP `lab-cell-pod-hardening`, synchro manuelle | **PASS** | `lab-platform` Succeeded (`initiatedBy: argo-escalation-test`) | annotation présente |
| N9 | même commit, **sans geste opérateur** | **PASS** | 90 s avec refresh forcés : aucune opération, `lab-platform` OutOfSync ; log du contrôleur « Sync prevented by sync window » | VAP inchangée |
| N1 | Application enfant `project: default` dans `apps/`, vers un ClusterRoleBinding cluster-admin | **PASS** | Application créée par `lab-root` (kind permis), puis `InvalidSpecError: … not permitted in project 'default'` (dépôt et destination) | CRB `lab-n1-evil` absent |
| N2a | Application glissée dans `platform/policies/` (synchro `lab-platform`) | **PASS** | Failed : `resource argoproj.io:Application is not permitted in project lab-platform` | Application absente |
| N2b | Application dans `generated/` | **PASS** | Failed : `… Application is not permitted in project lab-apps` | absente |
| N3 | Application (`apps/`) dans le namespace `kube-system` | **PASS** | `lab-root` : `namespace kube-system is not permitted in project 'lab-root'` (5 nouvelles tentatives, puis Failed) | aucune Application dans `kube-system` |
| N4 | `lab-authz` passé en `automated` + nouveau `ClusterAuthzRole lab-n4-escalade` (`actions: ["*"]`) | **PASS** | `spec.automated` appliqué par `lab-root`. Pendant environ 100 s, aucune synchro : « Sync prevented by sync window » (`evidence/N4-controller-window.log`). Synchro manuelle ensuite : Succeeded. | rôle absent avant la synchro manuelle, présent après (supprimé ensuite) |
| N5a | ClusterRoleBinding cluster-admin dans `generated/` | **PASS** | Failed : `ClusterRoleBinding is not permitted in project lab-apps` | absent |
| N5b | Namespace `kube-system` patché (PSA privileged) dans `generated/` | **PASS** | Failed : `:Namespace is not permitted in project lab-apps` | `resourceVersion` inchangé |
| N5c | VAP `lab-cell-pod-hardening` neutralisée (`Ignore`, `true`) dans `generated/` | **PASS** | Failed : `ValidatingAdmissionPolicy is not permitted in project lab-apps` | `resourceVersion` inchangé |
| N5d | nouvelle VAP dans `generated/` | **PASS** | Failed (idem) | absente |
| N5e | ClusterRole `*/*/*` dans `generated/` | **PASS** | Failed : `ClusterRole is not permitted in project lab-apps` | absent |
| N5f | Secret en clair dans `generated/` | **PASS** | Failed : `:Secret is not permitted in project lab-apps` | absent |
| N5g | label PSA de `lab-pg` abaissé depuis `generated/` | **PASS** | Failed : `:Namespace is not permitted in project lab-apps` | label `restricted` inchangé |
| N5h | Project OpenChoreo (kind permis) dans `kube-system` | **PASS** | Failed : `namespace kube-system is not permitted in project 'lab-apps'` | absent |
| N6 | ClusterRole `*/*/*` dans `platform/policies/`, synchro manuelle | **PASS** | Failed : `ClusterRole is not permitted in project lab-platform` | absent |
| N7a | PSA `lab-pg` → privileged dans `platform/data/`, sans geste opérateur | **PASS** | 60 s sans synchro (fenêtre `deny`) | `restricted` inchangé |
| N7b | même commit, **synchronisé à la main** | **ACCEPTÉ PAR ARGO** (attendu) | Succeeded : Namespace `lab-pg` nommé dans `lab-platform` | `privileged`. Barrière : CI S3 et relecture opérateur, **pas Argo** |
| N7c | revert + synchro manuelle | **PASS** | Succeeded | `restricted` restauré |
| N8 | Application enfant `lab-apps` qui vise `platform/install/argocd/project-*.yaml` (AppProject) | **PASS** | `n8-projects` : `resource argoproj.io:AppProject is not permitted in project lab-apps` | AppProject inchangés (`resourceVersion`) |

## Non testé

- **NOT_TESTED** : sur OKE (étape 11 en attente). Les mêmes manifests y seront appliqués par `install.sh --step 11`.
- **NOT_TESTED** : Argo avec `application.sync.impersonation` (barrière au niveau de l'API server). Non activé.
- **NOT_TESTED** : `lab-apps` en `automated`. Les tests synchronisent à la main, ce qui est le pire cas (un opérateur synchronise). La barrière AppProject est la même en synchro automatique.
