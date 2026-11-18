---
owner: paul
updated: 2026-11-18
review_days: 30
---
# Durée de la CI pré-merge

Date : 2026-11-18. Légende : **[M]** mesuré (API GitHub Actions, lecture seule, ou exécution locale) ; **[V]** source lue ; **[E]** estimation ; **NOT_TESTED** non exécuté.

## 0. Conclusion
1. Le check requis `ci-ok` dure environ **1 min 20 à 2 min** [M]. Le chemin critique est le job `platform` (**85 à 95 s**, 66 s au mieux) ; `appgen` suit (**34 à 37 s**). Tous les autres jobs finissent en moins de 20 s.
2. Deux étapes font l'essentiel du temps : `tests/argo-guard/run.sh` (**35 s**) et les tests unitaires d'`appgen` (**24 s**). Les deux passent ce temps à parser du YAML avec le **parseur Python pur** de PyYAML, alors que la variante C (`CSafeLoader`, libyaml) est déjà installée [M].
3. Ce changement implémente, dans `.github/workflows/` seulement :
   - `platform` est coupé en deux jobs parallèles, `platform` et `platform-render` ; les deux sont dans `ci-ok` ;
   - un cache des archives de charts, sûr car chaque fichier est revérifié par son sha256 ;
   - `cancel-in-progress` seulement sur PR : un run de `main` n'est plus annulé ;
   - `k3d-integration` est filtré par chemins plus fins sur PR, et tourne après le merge (push sur `main`) et chaque nuit.
4. Gain estimé sur `ci-ok` : **~100 s → ~65 s** [E]. Avec T-451 (`CSafeLoader` dans `argo_guard.py` et `appgen.py`), le gain atteint **~45 s** [E].
5. Rien n'est retiré. `ci-ok` reste le seul check requis, avec la même règle : il échoue si un job amont n'est pas `success`. La garde de fuite, `secrets` (gitleaks) et `actionlint` restent avant le merge. k3d reste hors de `ci-ok`.

## 1. Mesure : jobs classés par durée

Source : run `ci` 44284793543 de la PR #55 (2026-11-18 10:22 UTC, `success`, 1 min 18 s) et 8 runs `success` du même jour [M]. Durée d'un job = `completed_at - started_at`.

| Rang | Job | PR #55 (s) | Plage sur 8 runs (s) | Étapes dominantes |
|---|---|---|---|---|
| 1 | `platform` | 66 | 85-95 | cas négatifs argo_guard 24-36 ; kubeconform 14-20 ; rendus Helm 9-12 ; shellcheck 5-7 ; outils 5-7 |
| 2 | `appgen` | 35 | 34-37 | tests unitaires 24 |
| 3 | `lint-code` | 15 | 15-18 | shellcheck de tous les `*.sh` 9 |
| 4 | `leak-guard` | 15 | 15-16 | tests de la garde 10 |
| 5 | `crd-schema` | 14 | 12-17 | pip 4 ; kubeconform 4 |
| 6 | `dev-factory` | 11 | 9-17 | outils 3 ; tests 3 |
| 7 | `yamllint` | 9 | 6-13 | pip 4 |
| 8 | `secrets` | 7 | 5-7 | gitleaks sur l'historique 1 |
| 9 | `backlog`, `actionlint`, `charts`, `release-history` | 5-6 | 3-7 | mise en place du runner |
| — | `ci-ok` | 2 | 2-4 | agrégation |

Le temps d'attente du runner est de 1 à 6 s par job [M]. Le run complet dure le temps de `platform` plus `ci-ok` plus l'attente.

Suites k3d (`k3d-integration`, hors `ci-ok`) [M] : `vap` 30-65 s, `gitops-k3d` 3 min 20, `k3d` 8 min 20 (bootstrap OpenChoreo 77-100 s), `argo-escalation` plus de 15 min (environ 23 min selon `docs/CI-K3D.md`). Avant ce changement, le filtre `tests/` les lançait sur presque toute PR.

Mesure locale (x86_64, 4 vCPU, PyYAML 6.0.2 avec libyaml) [M] :
- `python3 -I tools/oke/argo_guard.py .` : 0,62 s ; avec `CSafeLoader` : 0,11 s. Le cProfile met 2,0 s sur 2,05 s dans `yaml.load_all`. `tests/argo-guard/run.sh` lance 41 cas : 27 s.
- `python3 -m unittest discover -s tests/appgen` : 17,7 s ; avec `CSafeLoader` dans `load_yaml` et `_PlatformLoader` : 4,2 s. Les 139 tests passent et `appgen check` ne montre aucune dérive. L'essai n'est pas commité.

## 2. Ce qui est optimisé ici (sans retirer de contrôle)

| Optimisation | Job | Gain estimé | Risque |
|---|---|---|---|
| Coupe de `platform` : lint, règles Argo, cas négatifs et cellule dans `platform` ; security bundle, rendus, gardes uninstall et kubeconform dans `platform-render` | `platform` 92 s → ~52 s ; `platform-render` ~45 s, en parallèle | ~40 s sur le chemin critique [E] | Faible : mêmes commandes, même ordre, même variable `OKE_PHASEB_STATE`. Un job de plus dans `ci-ok`. |
| Cache `actions/cache` des archives de charts et du manifest Gateway API, avec `versions.env` comme clé | `platform-render` | 3-10 s [E] (part réseau non isolée, NOT_TESTED) | Empoisonnement neutralisé : `fetch_chart` et `fetch_gw_crds` revérifient le sha256 épinglé de chaque fichier, qu'il vienne du cache ou non. Une PR ne lit que son cache et celui de `main` [V]. |
| `SECURITY_BUNDLE_CHART_CACHE` pointe sur le cache | `platform-render` | 1-3 s [E] | Option prévue par `tests/security-bundle/run.sh` ; le sha256 est revérifié. |
| `cancel-in-progress` seulement sur `pull_request` (ci et k3d) | tous | 0 s pré-merge | Aucun : un push sur PR annule toujours le run obsolète. Chaque commit de `main` garde son verdict. |

Écartés :
- **Cache pip** (`setup-python cache: pip`) : 2-4 s par job, hors chemin critique après la coupe. Il ajoute une surface de confiance, car les paquets ne sont pas vérifiés par empreinte (`--require-hashes` absent). Gain trop faible.
- **Filtres de chemins sur `ci.yaml`** : un workflow filtré par `paths` laisse un check requis « en attente » [V]. Un job sauté rend `ci-ok` rouge, puisque `skipped` y vaut un échec. Changer cette règle (motif `alls-green` + `allowed-skips` [V]) modifierait la sémantique de `ci-ok` : refusé ici.
- **Matrice sur les tests** : la matrice n'aide que si le temps est réparti sur plusieurs étapes. Ici, deux scripts séquentiels dominent ; la correction est `CSafeLoader` (T-451).

## 3. Ce qui reste pré-merge (non négociable)
`leak-guard` (garde T-303), `secrets` (gitleaks sur l'historique), `actionlint`, `release-history` (releases append-only), `platform` et `platform-render` (frontière Argo, PSA), `appgen` (dérive de `generated/`), `crd-schema`, `backlog`, `lint-code`, `yamllint`, `dev-factory`, `charts`. Ce sont des contrôles statiques de moins de 60 s : les reporter ne gagnerait rien sur le chemin critique et ouvrirait `main` à une régression de sécurité.

## 4. Ce qui est reporté après le merge
**`k3d-integration`** (non requis, 3 à 23 min par suite) :
- sur PR : seulement avec le label `k3d` ou si la PR touche `platform/`, `tools/oke/`, `tools/k3d/`, `tools/appgen/`, `tests/{k3d,vap,argo-escalation,gitops-k3d}/` ou le workflow. Un changement de `tests/appgen/`, `tests/backlog/` ou `tests/leak-guard/` ne lance plus 4 clusters ;
- après le merge : à chaque push sur `main`, toutes les suites, sans annulation entre commits ;
- chaque nuit (`17 3 * * *`, UTC) : toutes les suites, pour détecter une dérive amont sans commit.

Pourquoi c'est sûr : k3d n'a jamais bloqué le merge (`k3d-ok` hors `ci-ok`). Le report retire seulement un signal non bloquant sur les PR qui ne touchent pas ce que les suites testent. Ce signal est rétabli sur `main`.

Alerte : un échec post-merge rend le commit rouge sur `main`, et GitHub notifie l'auteur du push. **Pas d'issue automatique** : `backlog/README.md` réserve les issues GitHub au lancement d'un agent. Le mécanisme d'alerte (issue, ticket ou fichier d'état) est une décision de Paul (T-451). Les échecs connus (`vap` B-09, `k3d` T12, `docs/CI-K3D.md` §3) rendront `k3d-ok` rouge sur `main` jusqu'à leur correction.

## 5. Recommandations hors workflows (ticket T-451)
1. `CSafeLoader` dans `tools/appgen/appgen.py` (`load_yaml`, `_PlatformLoader`) : `appgen` 35 s → ~15 s [E] ; mesuré 17,7 s → 4,2 s en local.
2. `CSafeLoader` dans `tools/oke/argo_guard.py` (classe `Loader`, garde du noyau, CODEOWNERS) : cas négatifs 35 s → ~7 s [E] ; `platform` ~52 s → ~22 s [E].
3. File de fusion : `min_entries_to_merge_wait_minutes: 1` avec `min_entries_to_merge: 1`. L'attente ne s'applique que si le minimum n'est pas atteint [V] ; avec un minimum de 1, elle est sans effet. À vérifier sur un run `merge_group` réel (aucun observé le 2026-11-18).
4. `kubeconform -cache` pour les schémas Kubernetes par défaut, téléchargés à chaque run (part non isolée, NOT_TESTED).

## 6. Risques et NOT_TESTED
- NOT_TESTED : aucun run GitHub de cette branche (pas de push). Les gains sont des estimations tirées de la durée des étapes [E].
- NOT_TESTED : chemin du cache `${{ github.workspace }}/../phaseb` hors du workspace. `actions/cache` accepte des chemins absolus ; à confirmer sur le premier run (cache `miss`, puis `hit` après un run de `main`).
- `platform-render` installe moins d'outils que l'ancien `platform` (pas de yamllint ni de shellcheck) ; ses scripts n'en demandent pas (`need` de `tools/oke/lib.sh`).
- Le filtre k3d plus fin peut laisser passer une régression k3d venue de `apps/` ou `generated/`. C'était déjà le cas avant ; la régression est vue après le merge.

## 7. Art antérieur
- actions/cache v5.1.0, `caa296126883cff596d87d8935842f9db880ef25` (MIT) : portée du cache par branche, cache de la branche par défaut lisible par les autres, éviction après 7 jours sans accès. https://github.com/actions/cache/blob/caa296126883cff596d87d8935842f9db880ef25/README.md
- GitHub Docs, contrôles requis sautés ou en attente avec un filtre de chemins : https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks
- re-actors/alls-green (`allowed-skips`), écarté : https://github.com/marketplace/actions/alls-green
- Jake Wharton, un seul check requis en éventail : https://jakewharton.com/fan-in-to-a-single-required-github-action/
- GitHub Docs, file de fusion (`merge_group`, taille minimale de groupe et délai) : https://docs.github.com/en/enterprise-server@3.20/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
- GitHub Changelog, cache en lecture seule pour les déclencheurs non fiables (2026-06-26) : https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/
- `docs.github.com` est injoignable depuis cette session : les pages GitHub Docs sont citées depuis les résultats de recherche, sans lecture directe.
