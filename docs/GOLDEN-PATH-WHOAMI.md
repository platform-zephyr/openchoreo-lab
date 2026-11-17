# Golden path whoami : cycle GitOps sur OKE (préparation)

Statut : **DRAFT, préparation statique uniquement.** Rien de ce document n'a été exécuté contre OKE ni contre k3d.
Tout ce qui touche au runtime est `NOT_TESTED` jusqu'à exécution par le coordinateur, qui est le seul à avoir accès à OKE.
Ne pas merger avant que la plateforme OKE soit prête (voir §2).

## 0. Résumé

- Le cycle à prouver : déploiement de `whoami` sur OKE par GitOps, modification visible en HTTP, rollback Git avec retour à l'état d'origine.
- Aucune exposition publique : le HTTP passe par `kubectl port-forward` vers le Service ClusterIP de la cellule, sur `127.0.0.1`.
- Livrables de cette branche (`tests/golden-path-whoami/`) :

| Fichier | Rôle | Écrit ou lit le cluster ? |
|---|---|---|
| `common.sh` | Fonctions communes, garde-fous (KUBECONFIG, contexte, verbes limités, pas de Secret) | lit seulement |
| `verify-http.sh` | État runtime : Argo, ReleaseBinding, ComponentRelease, pod, sécurité, portée, HTTP 200 | lit seulement (+ tunnel local) |
| `verify-change.sh` | Prouve que `WHOAMI_NAME` est livré et visible en HTTP | lit seulement |
| `verify-rollback.sh` | Prouve le retour à la base : même release, même UID de ComponentRelease | lit seulement |
| `selftest.sh` | Garde-fous testés sans cluster (refus avant tout appel réseau) | aucun |
| `change.patch` | Changement prêt : `env: {WHOAMI_NAME: ...}` + release régénérée | non (patch git) |
| `cluster-oke.patch` | Bascule `cluster: k3d` vers `cluster: oke` (à appliquer après ouverture du gate) | non (patch git) |

## 1. Ce qui est vérifié statiquement (PASS)

Résultats obtenus sur la branche `feat/whoami-oke-cycle` (commande, résultat) :

| # | Contrôle | Commande | Résultat |
|---|---|---|---|
| S1 | Validation des apps (10) | `python3 tools/appgen/appgen.py validate` | PASS |
| S2 | Pas de dérive de `generated/` (72 fichiers) | `python3 tools/appgen/appgen.py check` | PASS |
| S3 | Tests appgen | `python3 -m unittest discover -s tests/appgen` | PASS (103 tests, 1 skip kubeconform) |
| S4 | Syntaxe bash | `bash -n tests/golden-path-whoami/*.sh` | PASS |
| S5 | Shellcheck | `shellcheck -x tests/golden-path-whoami/*.sh` | PASS |
| S6 | YAML (périmètre CI) | `yamllint -c tools/appgen/yamllint.yaml apps tools tests .github` | PASS (avertissements préexistants sur `mealie`, `rustical-pilot`, `ci.yaml`, hors périmètre) |
| S7 | Garde-fous sans cluster | `bash tests/golden-path-whoami/selftest.sh` | PASS (12 cas, tous refusés avant tout appel réseau) |
| S8 | Secrets | `gitleaks dir tests/golden-path-whoami docs/GOLDEN-PATH-WHOAMI.md` | PASS (aucune fuite) |
| S9 | Patch de changement applicable | `git apply --check tests/golden-path-whoami/change.patch` | PASS |
| S10 | Patch de bascule OKE applicable | `git apply --check tests/golden-path-whoami/cluster-oke.patch` | PASS |
| S11 | Ordre des patches indifférent | `git apply` bascule puis `--check` changement, et l'inverse | PASS dans les deux sens |
| S12 | Rendu OKE simulé (gate ouvert, caps factices, voir F1) | `appgen --allow-oke validate` puis `render` sur une copie | PASS : `generated/whoami` identique à la version k3d (même release `whoami-31985273d8`) |
| S13 | Changement simulé puis retour (patch inverse) sur une copie | `git apply` change puis `git apply -R` | PASS : `releaseName` revient à `whoami-31985273d8`, fichier de release restauré |

Le changement (S9) produit : `releaseName` `whoami-31985273d8` vers `whoami-e4720c4c8b`, un nouveau fichier de release, et la suppression de l'ancien (voir F3).

## 2. Findings bloquants (à traiter par la plateforme, hors de cette branche)

Ces points sont trouvés par la préparation. Ils ne sont pas corrigés ici, car ils touchent `clusters/`, `tools/` ou `.github/`, hors périmètre autorisé.

- **F1. `clusters/oke/capabilities.yaml` est invalide selon son propre schéma.** `databaseInstances: {}` et `storageClasses: {}` violent `minProperties: 1` (`docs/schema/capabilities.schema.json`). Dès qu'une app cible `oke`, `appgen` échoue, même avec `--allow-oke`. Les règles CI ne le voient pas tant qu'aucune app ne cible OKE. **Correctif attendu : PR plateforme** qui rend le fichier valide (sans ouvrir de volume ni de base, ce que la politique interdit encore).
- **F2. Le gate OKE est fermé sur `main`.** `cluster: oke` est refusé sans `--allow-oke`. La CI (`.github/workflows/ci.yaml`, jobs `appgen`) lance `appgen validate` et `check` sans ce drapeau. Une bascule fusionnée avant l'ouverture du gate fait donc échouer la CI de `main`. Il faut un correctif CI conditionné à l'état du gate, en PR plateforme, avant la bascule.
- **F3. `appgen render` supprime les releases non courantes.** `cmd_render` fait `shutil.rmtree(generated)` puis réécrit uniquement les releases courantes. Le changement supprime donc `releases/whoami-31985273d8.yaml` (voir `change.patch`). Cela contredit « releases append-only » (`docs/APP-CONTRACT.md` §6 et `golden-paths/A-stateless-http/CHECKLIST.md`). Conséquences :
  - le rollback par `git revert` fonctionne, car le revert restaure le fichier et le blob est identique (contrôlé par `verify-rollback.sh`, R3) ;
  - côté cluster, la ComponentRelease d'origine n'est conservée que si elle n'est pas purgée. Le rendu ne pose aucune annotation `Prune=false,Delete=false` sur les ComponentRelease. Le risque est réel dès que `lab-apps` passe en `prune: true`.
  - **Correctif attendu : PR plateforme** sur `tools/appgen` (conserver les releases existantes, ou au minimum annoter les ComponentRelease `Prune=false,Delete=false`). Tant que ce n'est pas fait, `verify-rollback.sh` R4 est la preuve de non-recréation, à exécuter.
- **F4. Pas de `Name:` garanti dans la réponse de l'image.** La modification suppose que `traefik/whoami:v1.10.3` lit `WHOAMI_NAME` et affiche `Name: <valeur>`. Ce point n'a pas été exécuté (pas de conteneur lancé). C'est une hypothèse `[S]`. Si la première réponse ne contient pas `Name:`, la modification n'est pas prouvée. Repli documenté : `args: ["--port", "8080", "--name", "<valeur>"]` (à confirmer par `--help` de l'image). Dans ce cas, changer `change.patch` avant la PR.
- **F5. Nommage et labels de cellule `[S]`.** `cell_ns` suppose le label `openchoreo.dev/project` / `openchoreo.dev/environment` sur le namespace `dp-*`, avec repli sur le nommage `dp-default-whoami-production-*`. À confirmer sur le premier `verify-http.sh`, qui échoue en `W0` si le nommage diffère.
- **F6. Application Argo `lab-apps` absente d'OKE.** `STATE.md` (étape 11) : Argo CD n'est pas encore installé sur OKE. `verify-http.sh` renvoie `BLOCKED` sur G2 tant que la CRD manque.

## 3. Séquence exacte pour le coordinateur

Prérequis (tous obligatoires avant toute étape runtime) : F1 et F2 traités, gate OKE franchi (Cilium, baseline kube-ops #1620, refus IMDS prouvé, accès opérateur), installation fail-closed des étapes OKE 6 à 11 faite et vérifiée, PR #8 fusionnée (voir `STATE.md` §6).

Variables (à poser dans le shell du coordinateur, jamais dans Git) :

```bash
export KUBECONFIG=<kubeconfig OKE dédié, jamais celui de Paul>
export CONTEXT_RE=<motif du contexte OKE, défaut oracle-a1>
R=<chemin du clone openchoreo-lab à jour sur origin/main>
EVID=<dossier de preuves hors dépôt, p.ex. ~/evidence-whoami/$(date -u +%Y%m%dT%H%M%SZ)>
mkdir -p "$EVID"
```

**Étape 0. Garde-fous sans cluster** (aucune écriture) :

```bash
cd "$R" && bash tests/golden-path-whoami/selftest.sh
python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py check
```

Attendu : `selftest : OK`, `appgen validate : OK`, `aucune derive`.

**Étape 1. Bascule OKE** (après F1, F2 et ouverture du gate ; PR distincte) :

```bash
git switch -c feat/whoami-cluster-oke origin/main
git apply tests/golden-path-whoami/cluster-oke.patch
python3 tools/appgen/appgen.py --allow-oke validate && python3 tools/appgen/appgen.py --allow-oke check
git add -A apps/whoami && git commit -m "whoami: cible oke (gate ouvert)" && git push -u origin HEAD
gh pr create --draft --title "whoami: cible oke" --body-file <corps>
```

Preuve attendue : CI verte (nécessite F2 corrigé), `generated/` inchangé. Merge seulement après GO de Paul.

**Étape 2. Baseline runtime** (après sync Argo de la bascule) :

```bash
BASE_REL=$(git -C "$R" show origin/main:generated/namespaces/default/projects/whoami/components/whoami/release-bindings/whoami-production.yaml | sed -n 's/^  releaseName: //p')
MERGE_OKE=<SHA de merge de la bascule>
EXPECT_REVISION=$MERGE_OKE EXPECT_RELEASE=$BASE_REL \
  bash "$R/tests/golden-path-whoami/verify-http.sh" | tee "$EVID/01-baseline.txt"; echo "rc=$?"
```

Critère : `verdict: PASS`, code 0 (`BASE_REL` attendu : `whoami-31985273d8` à la date de cette branche ; le lire dans Git, car le hash dépend du CCT). Un `PARTIAL` (code 3) n'est pas un PASS : il faut lire les lignes `NOT_TESTED` et `BLOCKED`.

**Étape 3. Changement** : PR à partir de `change.patch`, CI verte, merge (squash) :

```bash
git switch -c feat/whoami-change origin/main
git apply "$R/tests/golden-path-whoami/change.patch"
python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py check
git add -A apps/whoami generated && git commit -m "whoami: WHOAMI_NAME (preuve GitOps)" && git push -u origin HEAD
gh pr create --draft --title "whoami: WHOAMI_NAME" --body-file <corps>
# après GO et merge :
CHANGE_SHA=$(git -C "$R" rev-parse origin/main)   # SHA du merge sur main
BASE_SHA=$(git -C "$R" rev-parse "$CHANGE_SHA^")
CHANGE_SHA=$CHANGE_SHA BASE_SHA=$BASE_SHA TIMEOUT=900 \
  bash "$R/tests/golden-path-whoami/verify-change.sh" | tee "$EVID/02-change.txt"; echo "rc=$?"
```

Preuves attendues : `C1` PASS (app.yaml et release de changement distinctes), `C2` PASS (baseline vue, UID enregistré hors dépôt), `C3` PASS (révision Argo = `CHANGE_SHA`, `ReleaseBinding` sur `whoami-e4720c4c8b`, `WHOAMI_NAME` dans le pod, `Name: whoami-gitops-oke-v2` dans la réponse HTTP).

**Étape 4. Rollback** : `git revert` dans une PR de revert, merge, puis preuve :

```bash
git switch -c revert/whoami-change origin/main
git revert --no-edit "$CHANGE_SHA"
git push -u origin HEAD && gh pr create --draft --title "revert: whoami WHOAMI_NAME" --body-file <corps>
# après GO et merge :
REVERT_SHA=$(git -C "$R" rev-parse origin/main)
REVERT_SHA=$REVERT_SHA CHANGE_SHA=$CHANGE_SHA BASE_SHA=$BASE_SHA TIMEOUT=900 \
  bash "$R/tests/golden-path-whoami/verify-rollback.sh" | tee "$EVID/03-rollback.txt"; echo "rc=$?"
```

Preuves attendues : `R1` à `R3` PASS (Git : revert identique à la base, blobs identiques), `R5` PASS (convergence), `R4` PASS (même UID de ComponentRelease qu'en étape 3, objet non recréé), `W6` PASS (pas de `WHOAMI_NAME` dans le pod), `H4` PASS (plus de `Name: whoami-gitops-oke-v2`).

Note : `R4` est `NOT_TESTED` si `verify-change.sh` n'a pas été exécuté depuis ce poste (fichier d'UID absent). Dans ce cas, le rollback n'est pas prouvé « objet d'origine ».

**Étape 5. Synthèse** : copier `$EVID` dans le dossier de preuves du dépôt (`evidence/runtime/oke/whoami/`, en PR), citer les codes retour et le SHA de chaque étape.

## 4. Critères PASS / FAIL / NOT_TESTED

| Statut | Signification | Effet |
|---|---|---|
| PASS | Contrôle exécuté contre OKE, valeur attendue obtenue | compte |
| FAIL | Valeur différente, ou ressource absente | l'étape échoue : ne pas poursuivre, `fix-app` |
| NOT_TESTED | Contrôle non exécutable (CRD absente, UID de référence absent) | verdict PARTIAL, pas PASS |
| BLOCKED | Prérequis absent (KUBECONFIG, contexte, API server, SHA inconnu) | code 2, rien n'est prouvé |

Codes retour : 0 PASS, 1 FAIL, 2 BLOCKED, 3 PARTIAL. Seul le code 0 vaut PASS.

## 5. Détail des contrôles runtime

| ID | Contrôle | Source |
|---|---|---|
| P0 | KUBECONFIG explicite, contexte autorisé (`CONTEXT_RE`), `kubectl version` répond | `common.sh` `preflight` |
| G2 | Application `lab-apps` Synced/Healthy, révision = commit attendu | `argocd`, `applications.argoproj.io` |
| G3 | Component `whoami` avec `autoDeploy: false` | `components.openchoreo.dev` |
| G4 | ReleaseBinding `releaseName` attendu ; ComponentRelease présente | `releasebindings`, `componentreleases` |
| G5 | ReleaseBinding Ready, ReleaseSynced, ResourcesReady ; ProjectReleaseBinding Ready | conditions |
| W0 | Cellule `dp-default-whoami-production-*` trouvée | namespaces |
| W4 | Deployment disponible (ready = desired), pods Ready, moins de 3 redémarrages | deployment, pods |
| W5 | runAsNonRoot, automount=false, allowPrivilegeEscalation=false, rootfs RO | deployment |
| W6 | `WHOAMI_NAME` dans le pod : valeur attendue, ou absente | deployment |
| W7 | Service `whoami` ClusterIP, port 8080 | service |
| S1 à S5 | 0 PVC ; 0 Service LoadBalancer/NodePort ; 0 route externe, 0 Ingress ; 0 LoadBalancer ou PVC liés à whoami (tout namespace) ; 0 Resource OpenChoreo `whoami` (pas de base) | cellule, cluster |
| H1 | GET `/health` = 200 via port-forward | `curl` sur `127.0.0.1` |
| H2 | GET `/` = 200, corps contenant `Hostname:` (corps non imprimé) | idem |
| H3 | Corps contenant `Name: <valeur attendue>` | idem |
| H4 | Corps ne contenant plus `Name: <valeur retirée>` | idem |
| C1 à C3, R1 à R5 | Voir `verify-change.sh` et `verify-rollback.sh` | Git + runtime |

## 6. Ce qui reste hors périmètre, et pourquoi

- **Pas d'exposition ni de pod éphémère.** La variante « curl depuis un pod éphémère restricted » a été écartée : créer un pod est une écriture, et le script doit rester en lecture seule. Le tunnel `port-forward` ne modifie aucun objet.
- **Pas de base, pas de volume, pas de LoadBalancer** (whoami est `stateless`, `exposure: private`, `network: none`, `backup: none`).
- **Pas de Secret lu**, pas de jeton écrit. Le corps HTTP n'est pas journalisé, seuls les codes et les comparaisons le sont.
- **Pas de merge, pas de « ready ».** La PR reste en draft.

## 7. Sécurité et hygiène

- Aucun identifiant, aucune adresse de cluster, aucun nom de contexte réel dans ce document ni dans les scripts. Les sorties n'affichent que le fait que le contexte matche.
- Les fichiers d'UID de référence sont écrits hors dépôt (`$WHOAMI_STATE_DIR`, par défaut `~/.local/state/golden-path-whoami`).
- Les garde-fous sont testés par `selftest.sh` sans cluster.
