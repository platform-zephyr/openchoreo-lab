# Job CI `platform` : vérification de `platform/**` et `tools/oke/**` (revues I10, B2, PR #8 P1)

**Statut : intégré** dans `.github/workflows/ci.yaml` (jobs `platform` et `platform-render`, tous deux inclus dans l'agrégat `ci-ok`, seul check requis par `main-protection`). Depuis 2026-11-18, les contrôles Helm (security bundle, rendus, gardes de désinstallation, kubeconform) tournent dans `platform-render`, en parallèle, avec un cache des charts dont le sha256 est revérifié à chaque usage (`docs/research/CI-SPEED.md`). Permissions `contents: read`, aucun secret, aucun cluster. Actions épinglées par SHA ; binaires linux-arm64 vérifiés par sha256.

## Pourquoi

Argo applique `platform/**` depuis `main` (`selfHeal`, étape 11) avec un contrôleur qui a les droits `*/*/*`. Un AppProject ne peut pas restreindre un **chemin** source, et une `Application` choisit librement son `spec.project`. Sans contrôle CI, une PR verte pourrait :
- glisser une `Application` (projet `default`, ou tout autre) dans un fichier que `lab-platform` synchronise ;
- passer `lab-authz` en synchro automatique ;
- poser un `ClusterAuthzRoleBinding`, un `ClusterRoleBinding` ou une NetworkPolicy « tout ouvrir ».

## Séparation bootstrap / GitOps (platform/install/argocd/)

| Fichier | Rôle | Appliqué par |
|---|---|---|
| `project-default-locked.yaml` | projet `default` verrouillé : aucun dépôt, aucune destination, aucune whitelist, blacklist `*/*` | `install.sh --step 11` (SSA `--force-conflicts`), vérifié par `verify.sh --step 11` (B11-default-locked) |
| `project-lab.yaml` | AppProject `lab` (kinds nommés, sans `Application`), `lab-authz` (authz `lab-*`), `lab-root` (kind `Application` dans `lab-argocd` seulement) | `install.sh --step 11` |
| `root-application.yaml` | Application `lab-root` (projet `lab-root`, chemin `apps/`) | `install.sh --step 11` |
| `apps/*.yaml` | Application enfants (`lab-platform` projet `lab`, `lab-authz` projet `lab-authz`, sync manuelle) | Argo (`lab-root`) |

Tout ce qui n'est pas sous `apps/` est du bootstrap privilégié : jamais synchronisé par Argo, modifié par PR puis rejoué par l'opérateur.

## Contrôles du job

| Contrôle | Commande | Échec si |
|---|---|---|
| YAML | `yamllint` sur `platform/*` (sauf `component-types`, voir plus bas), `tools/oke`, `tests/argo-guard` | une erreur |
| Scripts | `shellcheck -x -P SCRIPTDIR tools/oke/*.sh tests/argo-guard/*.sh`, `bash -n` | un constat |
| Règles Argo | `python3 -I tools/oke/argo_guard.py .` | voir ci-dessous |
| Cas négatifs | `tests/argo-guard/run.sh` | un piège non refusé, ou l'arbre actuel refusé |
| Rendus Helm | `tools/oke/render-check.sh` (charts épinglés, sha256) | `psa_check.py` en écart ; PVC, Service LB/NodePort ou image sans digest |
| Gardes de désinstallation | `tests/argo-guard/uninstall-guards.sh` (kubectl/helm factices) | P2/P3 de la revue PR #8 régressent |
| Schémas | `tools/oke/kubeconform-platform.sh` (`-strict`, CRD rendues des charts épinglés + Cilium) | objet invalide ou schéma manquant |

### Règles de `argo_guard.py`

Arbre contrôlé : `platform/`, `generated/`, `apps/`. Un YAML illisible fait échouer le contrôle (rc=2).
- **A1** : une `Application` hors `platform/install/argocd/apps/`. Seule exception : `root-application.yaml`, qui doit rester `lab-root`, dans le projet `lab-root`, sur le chemin `apps/`. Tout `ApplicationSet` est refusé.
- **A2** : un `spec.project` hors de `{lab, lab-authz, lab-root}`, donc jamais `default`. Dans `apps/`, seuls `lab` et `lab-authz` sont admis. `lab-authz` est réservé à l'Application `lab-authz`, sur le chemin `platform/authz`.
- **A3** : une Application `lab` qui synchronise un chemin hors de `platform/` et `generated/`, ou `platform/install/argocd/` ou `platform/authz/`. Sont aussi refusés les sources multiples, Helm, plugin et kustomize.
- **A4** : `syncPolicy.automated` sur le projet `lab-authz`.
- **P1** : un AppProject hors des deux fichiers de bootstrap, ou un projet `default` non verrouillé.
- **P2** : un joker `*` en whitelist (group, kind ou name), en dépôt source ou en destination. Sont aussi refusés une entrée cluster-scoped sans `name`, `Application` ou `AppProject` en whitelist ailleurs que dans `lab-root`, et un projet `lab-root` qui admet autre chose qu'`Application` dans `lab-argocd`.
- **Z1** : un kind authz OpenChoreo hors de `platform/authz/`. Dans `platform/authz/`, tout autre kind ou un nom hors `lab-*` est refusé.
- **S1** : dans les fichiers synchronisés par une Application `lab`, un objet cluster-scoped absent, par kind et nom, de la whitelist `lab`, ou un kind namespacé non listé. `ClusterRoleBinding`, CRD, webhooks et `Namespace` autres que `lab-pg` sont donc refusés.
- **S2** (revue A1) : une NetworkPolicy synchronisée hors de la liste nommée de `lab-pg`, ou qui ouvre tout : règle sans `from`/`to`, `namespaceSelector: {}` ou `/0`.
- **S3** (revue A2) : le Namespace `lab-pg` sans `pod-security…/enforce=restricted`, `part-of` ou `egress-isolated`.
- **K1** : un `kustomization.yaml`.

## CODEOWNERS et ruleset

`.github/CODEOWNERS` désigne `@SmadjaPaul` sur `platform/install/argocd/**`, `platform/policies/**`, `platform/authz/**` et `tools/oke/**`.

**Décision** (2026-11-17) : la revue des code owners n'est **pas** exigée par `main-protection` (`require_code_owner_review: false`, 0 approbation), pour ne pas bloquer l'autonomie des agents. La barrière effective est le job `platform` dans `ci-ok`.

**Option** : activer `require_code_owner_review: true` avec 1 approbation dans `tools/apply-branch-protection.sh`. Toute PR qui touche ces chemins exigerait alors l'accord de Paul. Cela coûte un geste humain par PR, y compris pour les PR d'agents sur `tools/oke/`.

## Limites connues

- `platform/component-types/service-restricted.yaml` a 6 erreurs d'indentation yamllint, préexistantes et hors périmètre de cette correction. Ce dossier est donc exclu du lint du job `platform` en attendant sa correction.
- `argo_guard` est un contrôle statique. Il ne voit pas une Application créée à la main dans le cluster. `verify.sh --step 11` contrôle l'état réel : projet `default` verrouillé, aucune Application `default`, `lab-authz` sans `automated`.
- Les objets cluster-scoped NOMMÉS restent modifiables par une PR mergée, mais en contenu seulement. Cela vaut pour les 5 types OpenChoreo, les 2 VAP et VAPB du labo et le Namespace `lab-pg` (dont les labels PSA sont gardés par S3).
