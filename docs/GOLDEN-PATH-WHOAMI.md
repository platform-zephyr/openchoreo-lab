# Golden path whoami : cycle GitOps sur OKE

Statut : **préparation statique.** Rien de ce document n'a été exécuté contre OKE ni k3d. Tout le runtime est `NOT_TESTED` tant que le coordinateur ne l'a pas joué, seul à avoir accès à OKE.

Base : `origin/main` après #19 (schéma capabilities), #20 (verify), #21 (whoami cible `oke`, gate OKE ouvert par défaut, `lab-apps` en synchro automatique limitée à `generated/namespaces/default/projects/whoami`).

## 0. Contenu de `tests/golden-path-whoami/`

| Fichier | Rôle | Touche le cluster ? |
|---|---|---|
| `common.sh` | Garde-fous : `KUBECONFIG` explicite, contexte matchant `CONTEXT_RE` (défaut `oracle-a1`), `admin@homeops` refusé, verbes limités à get/version/api-resources/auth can-i, aucun Secret lu | lecture seule |
| `verify-http.sh` | État : Argo `lab-o-whoami` Synced/Healthy, ReleaseBinding Ready, ComponentRelease présente, pod Ready, sécurité, Service ClusterIP, 0 PVC / 0 LoadBalancer / 0 route externe / 0 base, HTTP 200 via `port-forward` sur `127.0.0.1` | lecture seule + tunnel local |
| `verify-change.sh` | Prouve que `WHOAMI_NAME` est livré (Argo, RB, pod) et visible en HTTP | lecture seule |
| `verify-rollback.sh` | Prouve le retour à la base : blobs Git identiques, même release, même UID de ComponentRelease | lecture seule |
| `make-change-pr.sh` | Worktree depuis `origin/main`, applique `change.patch`, `appgen validate/check`, commit, push, PR | aucun (Git et GitHub seulement) |
| `make-revert-pr.sh` | Worktree depuis `origin/main`, `git revert --no-commit <CHANGE_SHA>`, restauration des releases historiques (append-only), validation `check --base`, push, PR. Paramètres `APP` (défaut `whoami`) et `MARKER` | aucun |
| `selftest.sh` | 14 garde-fous testés sans cluster (refus avant tout appel réseau) | aucun |
| `change.patch` | Patch sur `origin/main` : `env: {WHOAMI_NAME: whoami-gitops-oke-v2}` dans `apps/whoami/app.yaml`, release `whoami-69a1749676` ajoutée | non |

## 1. Vérifications statiques

| # | Commande | Résultat |
|---|---|---|
| S1 | `python3 tools/appgen/appgen.py validate` | PASS (10 apps) |
| S2 | `python3 tools/appgen/appgen.py check` | PASS (aucune dérive) |
| S3 | `python3 -m unittest discover -s tests/appgen` | PASS (103 tests, 1 skip) |
| S4 | `bash tests/golden-path-whoami/selftest.sh` | PASS |
| S5 | `shellcheck -x tests/golden-path-whoami/*.sh` | PASS |
| S6 | `bash -n tests/golden-path-whoami/*.sh` | PASS |
| S7 | `git apply --check tests/golden-path-whoami/change.patch` sur `origin/main` | PASS |
| S8 | `DRY_RUN=1 tests/golden-path-whoami/make-change-pr.sh` | PASS (validation, aucun push) |
| S9 | `DRY_RUN=1 CHANGE_SHA=<sha> tests/golden-path-whoami/make-revert-pr.sh` | PASS sur un revert propre ; refuse, sans push, si le revert ne passe pas la validation (ex. #19 réintroduit F1) |
| S10 | `gitleaks dir` sur les fichiers ajoutés | PASS |

Le changement ne touche que `apps/whoami/` et `generated/namespaces/default/projects/whoami/`. L'ancienne release `whoami-647fc6bfc1` reste dans `generated/` : `appgen` conserve désormais les releases existantes et pose `Prune=false,Delete=false` sur les ComponentRelease.

## 2. Séquence pour le coordinateur

Variables (shell du coordinateur, jamais dans Git) :

```bash
export KUBECONFIG=<kubeconfig OKE dédié>
export CONTEXT_RE=<motif du contexte OKE, défaut oracle-a1>
R=<clone openchoreo-lab à jour sur origin/main>
EVID=<dossier de preuves hors dépôt>; mkdir -p "$EVID"
cd "$R" && git fetch -q origin main
```

**Étape 0. Garde-fous, sans cluster** :

```bash
bash tests/golden-path-whoami/selftest.sh
python3 tools/appgen/appgen.py validate && python3 tools/appgen/appgen.py check
```

**Étape 1. Baseline runtime** (la release de base se lit dans Git, pas dans cette doc) :

```bash
BASE_REL=$(git show origin/main:generated/namespaces/default/projects/whoami/components/whoami/release-bindings/whoami-production.yaml | sed -n 's/^  releaseName: //p')
MAIN=$(git rev-parse origin/main)
EXPECT_REVISION=$MAIN EXPECT_RELEASE=$BASE_REL bash tests/golden-path-whoami/verify-http.sh | tee "$EVID/01-baseline.txt"; echo "rc=$?"
```

Critère : `verdict: PASS`, rc 0. Rc 3 (PARTIAL) n'est pas un PASS.

**Étape 2. Changement** :

```bash
bash tests/golden-path-whoami/make-change-pr.sh     # PR draft ; READY=1 pour non-draft (décision de Paul)
# CI verte, GO de Paul, merge (squash) par le coordinateur :
CHANGE_SHA=$(gh pr view <N> --json mergeCommit --jq .mergeCommit.oid)
BASE_SHA=$(git rev-parse "$CHANGE_SHA^")
git fetch -q origin main
CHANGE_SHA=$CHANGE_SHA BASE_SHA=$BASE_SHA TIMEOUT=900 bash tests/golden-path-whoami/verify-change.sh | tee "$EVID/02-change.txt"; echo "rc=$?"
```

Lab-apps synchronise automatiquement (sans prune) : aucun `argocd app sync` à la main. `verify-change.sh` attend la convergence.

Critères : C1 PASS (app.yaml du commit porte `WHOAMI_NAME`, release distincte), C2 PASS (baseline vue, UID de release enregistré hors dépôt), C3 PASS (révision Argo = `CHANGE_SHA`, RB sur `whoami-69a1749676`, `WHOAMI_NAME` dans le pod, `Name: whoami-gitops-oke-v2` dans la réponse HTTP).

**Étape 3. Rollback** :

```bash
CHANGE_SHA=$CHANGE_SHA bash tests/golden-path-whoami/make-revert-pr.sh   # PR draft de revert
# GO de Paul, merge par le coordinateur :
REVERT_SHA=$(gh pr view <M> --json mergeCommit --jq .mergeCommit.oid)
git fetch -q origin main
REVERT_SHA=$REVERT_SHA CHANGE_SHA=$CHANGE_SHA BASE_SHA=$BASE_SHA TIMEOUT=900 \
  bash tests/golden-path-whoami/verify-rollback.sh | tee "$EVID/03-rollback.txt"; echo "rc=$?"
```

Critères : R1, R2, R3 PASS (Git : revert identique à la base, blobs identiques), R5 PASS (convergence vers `whoami-647fc6bfc1`), R4 PASS (même UID de ComponentRelease qu'en étape 2), W6 PASS (pas de `WHOAMI_NAME` dans le pod), H4 PASS. R4 est NOT_TESTED si `verify-change.sh` n'a pas tourné depuis ce poste.

**Étape 4. Synthèse** : copier `$EVID` dans `evidence/runtime/oke/whoami/` via PR, avec les SHA et les codes retour.

## 3. Codes et critères

| Code | Statut | Effet |
|---|---|---|
| 0 | PASS | seul code qui vaut PASS |
| 1 | FAIL | ne pas poursuivre, `fix-app` |
| 2 | BLOCKED | prérequis absent (KUBECONFIG, contexte, API server, SHA inconnu) |
| 3 | PARTIAL | aucun FAIL, mais NOT_TESTED ou BLOCKED |

## 4. Findings restants

Image : `docker.io/traefik/whoami:v1.10.3@sha256:43a68d...` (nom qualifié, #22 : CRI-O refuse le nom court en mode enforcing). Cellule réelle attendue : `dp-default-whoami-production-f68ecf5a`, Service `whoami:8080` ClusterIP.


- **F4. Comportement `WHOAMI_NAME` non exécuté `[S]`.** L'hypothèse : `traefik/whoami:v1.10.3` lit `WHOAMI_NAME` et affiche `Name: <valeur>`. Non vérifié (aucun conteneur lancé ici). Si la baseline ne prouve pas le format, repli `args: [..., "--name", "<valeur>"]` à confirmer par `--help` de l'image, puis regénérer `change.patch`.
- **F5. Nommage de cellule `[S]`.** `cell_ns` lit le label `openchoreo.dev/project` / `environment`, avec repli sur `dp-default-whoami-production-*`. `verify-http.sh` échoue en `W0` si ni l'un ni l'autre ne matche.
- **F7. Rollback et UID.** `R4` dépend de `verify-change.sh` exécuté depuis le même poste (fichier d'UID hors dépôt, `~/.local/state/golden-path-whoami`). Sinon la preuve « objet d'origine, non recréé » est NOT_TESTED.
- **F8. Dépendance à la CI.** `make-*-pr.sh` ne contourne pas la CI : la PR n'est mergeable qu'avec les checks requis verts. Ils ne sont pas exécutés ici.

## 5. Hors périmètre

- Pas d'exposition publique, pas de pod éphémère (écriture), pas de `port-forward` vers autre chose que `svc/whoami`.
- Pas de base, pas de volume, pas de LoadBalancer (stateless, `exposure: private`, `network: none`).
- Aucun Secret lu, aucun jeton écrit. Le corps HTTP n'est jamais imprimé.
- Pas de merge, pas de passage en ready hors décision de Paul.

## 6. Plusieurs apps OKE : ApplicationSet `lab-o` (golden path n°2 : ntfy)

> T-491 : l'Application unique `lab-apps` à `sources[]` (états antérieurs de ce golden path) est remplacée par l'ApplicationSet `lab-o`. Les preuves runtime citées plus haut datent de l'ancien modèle ; le nouveau est **NOT_TESTED** sur OKE.

- **`lab-o` ne synchronise pas `generated/` en bloc.** L'ApplicationSet `lab-o` (`platform/install/argocd/apps/lab-apps.yaml`, générateur Git `files`, T-502) crée **une Application `lab-o-<app>` par entrée** de `clusters/oke/lab-o-apps.yaml` (liste versionnée du cluster OKE), sur `generated/namespaces/default/projects/<app>`, même dépôt, `targetRevision: main`, `directory.recurse: true`, `include: "*.yaml"`, projet `lab-o` et destination `default` littéraux. Il n'y a plus de liste `exclude` : une app absente de la liste (k3d, volume ou base, ex. miniflux) n'a aucune Application.
- **Garde CI** (`tools/oke/argo_guard.py`, O1-O5) : refuse tout autre générateur ou fichier, tout projet ou destination paramétrés, et toute entrée de la liste qui n'est pas une app OKE stateless générée (l'app doit être `cluster: oke`, `profile: stateless`, sans `storage` ni `database` dans `apps/<app>/app.yaml`, avec son dossier `generated/`), ni doublon. `tests/argo-guard/run.sh` couvre chaque cas.
- **Ajouter une app OKE** : `apps/<app>/app.yaml` (cluster oke, stateless) → `appgen render` → une ligne `- app: <app>` dans `clusters/oke/lab-o-apps.yaml` → PR ; rien à éditer sous `platform/`. Un retrait d'app est une PR qui retire la ligne de la liste : l'Application disparaît, les objets restent (`preserveResourcesOnDeletion`, NOT_TESTED).
- **Revert sans suppression de release** : `tests/golden-path-whoami/make-revert-pr.sh` (paramètres `APP` et `MARKER`, défaut whoami) restaure, dans le même commit de revert, les fichiers `generated/**/releases/*` supprimés par `git revert`, depuis `CHANGE_SHA`. La CI `tests/release-history/check.sh` impose cette règle. `verify-rollback.sh` R2 tolère la release de changement conservée (contenu = `CHANGE_SHA`).
- **ntfy (golden path n°2)** : `apps/ntfy/app.yaml` (oke, stateless, sans PVC, sans secret, `exposure: private`, `network: none`). Cache et auth en mémoire (variables non posées), donc aucun chemin inscriptible : `readOnlyRootFilesystem` tient sans `emptyDir`. Scripts : `tests/golden-path-ntfy/make-change-pr.sh` (ajoute `NTFY_LOG_LEVEL: DEBUG`), `tests/golden-path-ntfy/verify-http.sh` (lecture seule, `/v1/health` via `port-forward`), revert par `APP=ntfy MARKER=NTFY_LOG_LEVEL make-revert-pr.sh`. Preuves runtime OKE : NOT_TESTED tant que la PR n'est pas mergée et déployée. La 2e PR `pin-project ntfy` sera requise après le premier déploiement (avertissement d'`appgen check --base`).
