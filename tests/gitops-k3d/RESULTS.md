# Résultats — boucle GitOps whoami — **k3d** (pas OKE)

- **Exécution de référence** : run 4, 2026-11-17 de 19:54:07Z à 20:15:22Z (`tests/gitops-k3d/run.sh all`, puis `cleanup`).
  Runs 1 à 3 (18:55-19:52Z) : mises au point du banc ; leurs constats qui ne se rejouent pas dans le run 4 sont cités avec leur preuve (`evidence/RUN1-*`, `RUN2-*`, `run{1,2,3}-results.tsv`).
- **Versions** (`evidence/VERSIONS.txt`) : Kubernetes v1.36.1+k3s1 (1 nœud arm64, colima) ; OpenChoreo v1.3.3 (`ghcr.io/openchoreo/controller:v1.3.3`, `cluster-agent:v1.3.3`) ; Argo CD v3.5.1 (chart argo-cd 10.3.3, sha256 `ce254920…` vérifié) ; whoami `traefik/whoami:v1.10.3` / `v1.11.0` par digest.
- **Source** : GitHub `platform-zephyr/openchoreo-lab` `main` (`d4297af` au run 4) puis dépôt de test `gl-repo` (clone de ce `main`, servi en `git://` dans le cluster). Identités factices : auteur des commits `gl-test <gl-test@invalid>` ; aucun secret, aucun compte créé.
- **Chaîne testée** : `apps/whoami/app.yaml` → `tools/appgen` (`validate` + `render`, la « CI » ; kubeconform non exécuté) → commit/push sur `gl-repo` (la « PR mergée ») → Argo CD (`gl-apps`, `gl-platform`) → OpenChoreo (ReleaseBinding → cluster-agent) → pod Ready → HTTP 200 via `gateway-default` (Host `production-gl-oc.internal.localhost`).
- **Bilan run 4** : **18 PASS, 6 FAIL, 2 NOT_TESTED** (26 lignes). La boucle déploiement → modification → dérive → rollback → redémarrage est PASS ; les FAIL sont des défauts du contrat/générateur, détaillés dans `docs/GITOPS-PROOF.md` §4.
- **Journal cluster-agent** (19:54Z → 20:02Z, `evidence/AGENT-403.txt`) : 1361 × 200, 21 × 201, 19 × 404, 12 × 422, **0 × 403**, 0 ligne ERROR. Les 422 correspondent au refus `spec.strategy.rollingUpdate` (T-STRATEGY).

## Tableau

| ID | Étape | Résultat | Preuve (run 4 sauf mention) |
|---|---|---|---|
| T-BOOT | Argo CD épinglé dans `argocd`, PSA restricted | PASS | 27-29 s ; GitHub joignable depuis le repo-server |
| T-PLAT | `gl-platform` (GitHub `main`) : CCT, CPT, CRT, ClusterTrait, VAP, Environment/Pipeline | PASS | Synced en 21 s ; `T-PLAT.txt` |
| T-GH-SYNC | `gl-apps` sur les objets réels de generated/ (GitHub `main`) | PASS | Synced en 5 s |
| T-GH-RENDER | whoami de generated/ rendu tel quel | **FAIL** | `RenderingFailed` : « endpoint internal : gateway.ingress.internal requis » (absent de l'Environment ET du ClusterDataPlane, k3d comme gabarit OKE) ; `T-GH.txt` |
| T-ARGO-HEALTH | Argo reflète l'état OpenChoreo | **FAIL** | Argo `Healthy` alors que le ReleaseBinding est `Ready=False` : aucun health check pour `openchoreo.dev` |
| T-SWITCH | Bascule GitHub → gl-repo (même sha) | PASS | aucune génération modifiée |
| T-DEPLOY | Correction de l'Environment **par commit** → pod Running, PSA restricted, default-deny, HTTP 200 | PASS | commit→pod 139 s (Git→Argo 103 s) ; sonde hors cellule BLOCKED ; HTTP 200 via gateway ; `T-DEPLOY.txt` |
| T-ANNOT | Annotations `Prune=false` (correction appgen simulée) + `prune: true` | PASS | Synced en 143 s |
| T-MOD-REPLICAS | replicas 1→2 par `app.yaml` | PASS | même ComponentRelease ; 5 s |
| T-MOD-VERSION | image v1.10.3→v1.11.0 par digest | PASS | `whoami-31985273d8` → `whoami-024137137b`, ancienne conservée, HTTP 200 ; 6 s |
| T-PRUNE-STATUS | Application Synced après une nouvelle release | **FAIL** | OutOfSync permanent : appgen supprime l'ancien fichier de release, Prune=false la garde (`requiresPruning`) ; `T-PRUNE-STATUS.txt`, `RUN2-OUTOFSYNC-PRUNE.txt` |
| T-IMMUT | ComponentRelease immuable | PASS | « spec.workload is immutable » |
| T-DRIFT-ARGO | `kubectl patch` du ReleaseBinding | PASS | selfHeal en 4 s |
| T-DRIFT-OC | `kubectl scale` du Deployment rendu (dp-*) | PASS | corrigé par OpenChoreo : ≤ 2 s (run 4), 314 s (run 3) : non déterministe |
| T-DRIFT-OC-DEL | Service rendu supprimé à la main | PASS | recréé en 2 s |
| T-DRIFT-PLAT | `kubectl patch` de l'Environment | PASS | selfHeal en 2 s |
| T-DRIFT-ORPHAN | Objet créé hors Git dans gl-oc | PASS | `OrphanedResourceWarning`, non supprimé |
| T-ROLLBACK | `git revert` du commit de version | PASS | binding revenu sur `whoami-31985273d8` (réutilisée, intacte), image v1.10.3, HTTP 200 ; 5 s |
| T-RESTART | `rollout restart` du controller-manager | PASS | mêmes UID de pods, 0 redémarrage, Deployment non modifié, HTTP 200 |
| T-PIN-STALE | Changement des paramètres du Project (quota, PVC) par `app.yaml` | **FAIL** | nouvelle ProjectRelease créée mais PRB resté épinglé : quota `pvcs=0` non mis à jour. Même cause au run 1 (`RUN1-QUOTA-PIN.txt` : quota 400m dans Git, 300m appliqué, rollout bloqué par `exceeded quota`) |
| T-PIN-PRB | 2e commit qui écrit `projectRelease` dans le PRB | PASS | quota `pvcs=1` appliqué ; Argo reprend le champ en SSA |
| T-STRATEGY | Passage stateless → stateful sur l'app en place | **FAIL** | 422 « spec.strategy.rollingUpdate: Forbidden … Recreate » ; ancienne version reste servie (HTTP 200), Argo `Healthy` |
| T-RETRAIT-1 | Retrait de l'app par Git | **FAIL** | Argo refuse : « auto-sync will wipe out all resources » (dernière app de l'Application) ; rien supprimé ; `T-RETRAIT-1.txt` |
| T-RETRAIT-PVC | Retrait sans perte du PVC | NOT_TESTED | aucun PVC créé (T-STRATEGY), retrait non appliqué ; étapes T-READD/T-RETRAIT-PVC du banc non exécutées (k3d rendu) |
| T-FINALIZERS | Suppression des objets OpenChoreo (nettoyage) | PASS | finalizers levés en 31-75 s, aucun objet bloqué |
| T-CI | `appgen check` + kubeconform dans la boucle | NOT_TESTED | la « CI » du banc = `appgen validate` + `render` ; kubeconform non exécuté |

## Durées de réconciliation mesurées (k3d)

| Étape | Git → Argo Synced | Commit → pods prêts | Mode |
|---|---|---|---|
| Correction Environment (run 4) | 103 s | 139 s | polling (120 s + gigue, défaut v3.5.1) |
| Annotations sync-options (run 4) | 143 s | — | polling |
| Mêmes étapes, runs 1-3 | 244 s / 111 s / 122-175 s | 326 s / 144 s | polling |
| replicas 1→2 | 2 s | 5 s | refresh forcé (= webhook) |
| version v1.10.3→v1.11.0 | 3 s | 6 s | refresh forcé |
| git revert | 2 s | 5 s | refresh forcé |
| Dérive ReleaseBinding (selfHeal Argo) | 4 s | +2 s | événement |
| Dérive Deployment rendu (`kubectl scale`) | — | ≤ 2 s (run 4) ; 314 s (run 3) | resync OpenChoreo, non déterministe |
| RenderingFailed → re-rendu après correction de l'Environment | — | ~56 s après le sync Argo (run 1, pas d'événement sur l'Environment) | requeue |

Sans webhook, la latence d'un commit est dominée par le polling Argo : **100 à 245 s** mesurés ; OpenChoreo ajoute 5 à 40 s.

## Reproduire

```sh
export KUBECONFIG=<kubeconfig du k3d jetable>    # contexte k3d-* obligatoire ; tout chemin *oke-access* est refusé
tests/gitops-k3d/run.sh all       # ~25 min ; écrit evidence/ et evidence/results.tsv
tests/gitops-k3d/run.sh cleanup   # supprime Applications, gl-oc, dp-gl-oc-*, gl-git, argocd, CRD argoproj
```

## T-458 : ancre réparée, FAIL classés (2026-11-18)

### Preuve runtime lue (CI, niveau CI, k3d)

Run 44313410652 (dispatch sur `main` `de4f079`, 2026-11-18, artefact `k3d-gitops-k3d`, `results.tsv` lu). La suite dépasse l'ancre T-DEPLOY (étape exécutée, 13:32:50Z) puis **s'arrête après T-RESTART** : 18 lignes, 14 PASS, 3 FAIL (T-ARGO-HEALTH, T-DEPLOY, T-ANNOT), 0 NOT_TESTED enregistré. Job vert uniquement parce que la suite est classée `known_fail`.

### Cause des 3 FAIL et de l'arrêt

| ID | Résultat au run 44313410652 | Cause | Traitement dans cette branche | État |
|---|---|---|---|---|
| T-ARGO-HEALTH | FAIL | le banc installait Argo sans le fragment de health checks A5 (`platform/install/argocd/health/values-openchoreo-health.yaml`, déjà dans main et testé hors cluster) | le helm du banc reçoit ce fragment | corrigé, **NOT_TESTED** (runtime) |
| T-DEPLOY | FAIL (`http=404`) | `main` porte G1 : la route est rendue d'emblée avec l'hôte `lab.internal` (pod Ready dès `td=1`) ; le patch d'hôte `internal.localhost` n'est jamais re-rendu (route restée sur `lab.internal` 5 min) et le curl visait `internal.localhost` | `patch_env.py` ne remplace plus un hôte existant (`noop`) ; `run.sh` lit l'hôte de la HTTPRoute rendue (`route_host`) | corrigé, **NOT_TESTED** (runtime) |
| T-ANNOT | FAIL (`non Synced`, 420 s) | appgen émet déjà les annotations (A1) : `annotate_syncopts.py` n'a rien à committer, aucun nouveau sync Argo, et `app_synced_at` attend une opération sur un sha qui n'arrive pas. Cause **probable**, non prouvée : l'état de l'Application n'était pas dans l'artefact | attente d'un état stable (`app_settled`) quand rien n'est à committer ; l'état Application est enregistré en cas d'échec | corrigé sur hypothèse, **NOT_TESTED** (runtime) |
| (arrêt après T-RESTART) | suite interrompue | `render` de l'étape stateful : `appgen validate` refuse `block-rwo` sur `cluster: oke` (`clusters/oke/capabilities.yaml` : `storageClasses: {}`, voulu) ; `set -e` | l'étape cible `cluster: k3d` (politique k3d, `block-rwo -> local-path`) ; aucune garde contournée | corrigé, validé statiquement (`appgen validate` OK sur l'app modifiée), **NOT_TESTED** (runtime) |

### Classement des 5 FAIL historiques du run 4

Aucun de ces cas n'a été exécuté au run 44313410652 (arrêt avant eux) : aucun résultat runtime daté, donc aucun `PASS`.

| ID | Classement | Motif |
|---|---|---|
| T-ARGO-HEALTH | corrigé (A5 câblé dans le banc) ; **NOT_TESTED** | voir ci-dessus ; FAIL réel au run 44313410652 avant câblage |
| T-PRUNE-STATUS | **PASS** (run 44313410652, 13:40:07Z) | « gl-apps Synced après nouvelle release » : A1/A2 corrigés dans appgen |
| T-PIN-STALE | étape réécrite pour la règle des 2 PR (A3) ; **NOT_TESTED** | commit 1 (size medium), `appgen check --base` annonce la 2e PR |
| T-PIN-PRB | étape réécrite (`appgen pin-project`) ; **NOT_TESTED** | commit 2 : PRB sur la ProjectRelease, quota cpu mis à jour |
| T-STRATEGY | **PASS statique attendu** : `appgen render` refuse RollingUpdate -> Recreate (A4) ; vérifié à la main hors cluster (refus « passage RollingUpdate -> Recreate refuse ») ; la ligne `PASS` du banc reste **NOT_TESTED** tant que `run.sh` ne l'a pas écrite | le 422 runtime n'est plus atteignable par Git |
| T-RETRAIT-1 | `allowEmpty: true` ajouté à `gl-apps` du banc (A6, correction documentée non appliquée à `lab-apps`) ; **NOT_TESTED** | le pin du PRB est retiré au retrait pour que T-READD n'épingle pas une ProjectRelease disparue |

Aucun `KNOWN_FAIL` n'est conservé : chaque FAIL a une cause et un correctif, aucun n'a de preuve runtime après correctif.

### Reste (dispatch)

`gh workflow run k3d-integration.yml --ref claude/t-458-reste` (suite `gitops-k3d`) puis lecture de `results.tsv` ; retirer `known_fail` de la matrice (`.github/workflows/k3d-integration.yml`, hors périmètre) et la ligne de `docs/CI-K3D.md` (PR #95 / T-469) seulement si la suite passe ; brancher `tests/gitops-k3d` dans la CI unitaire (`ci.yaml`).

### Tests statiques (STATIC)

`python3 -m unittest discover -s tests/gitops-k3d` : 17 tests (cas négatifs inclus : ancre absente, YAML invalide, Environment absent, hôte existant jamais remplacé ; câblage de `run.sh`).
