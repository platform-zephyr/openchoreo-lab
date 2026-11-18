# Escalade de privilèges par Argo CD : preuve négative (flux A2, PR #8)

> **T-491 : renommage.** L'Application `lab-apps` est devenue l'ApplicationSet `lab-o` (une Application `lab-o-<app>` par app) et l'AppProject `lab-apps` l'AppProject `lab-o`. Ce document décrit l'état courant. Les preuves N* de `tests/argo-escalation/RESULTS.md` datent du 2026-11-17 sous l'ancien nom : **NOT_TESTED** sous `lab-o` tant que la suite n'est pas rejouée.

> Preuves réelles : `tests/argo-escalation/RESULTS.md`, avec un vrai Argo CD v3.5.1 (chart 10.3.3, values du dépôt) sur un k3d jetable `lab-sec-argo`. Étiquette **k3d, pas OKE**. Script reproductible : `tests/argo-escalation/run.sh`. Frontière de confiance et décision : `docs/GITOPS-TRUST-BOUNDARY.md`.

## Conclusion

**Prouvé sur un vrai Argo, la CI mise de côté.** Une PR **applicative**, qui ne touche que `apps/**` → `generated/**`, ne peut pas :
- créer d'Application ;
- choisir `default` pour gagner des droits ;
- toucher au RBAC, aux VAP, aux Namespace ou aux labels PSA ;
- poser un Secret ;
- écrire hors de `default`.

Dans chacun de ces cas, Argo refuse la synchro (`… is not permitted in project lab-o`), et l'API server ne reçoit rien.

La synchro automatique de l'authz (`lab-authz`) est impossible, même si une PR ajoute `automated` : la fenêtre `deny` du projet l'empêche. La synchro manuelle reste possible. Il en va de même pour tout `platform/**` : `lab-platform` porte la même fenêtre. Un merge ne s'applique donc jamais seul.

**Ce qui reste :**
1. Une PR qui modifie `platform/**` **n'est pas une PR applicative**. C'est un changement privilégié. Aujourd'hui, GitHub ne la bloque pas : ruleset `main-protection` à 0 approbation, `require_code_owner_review: false`, agents sous l'identité de Paul. De plus, `ci-ok` est calculé par le workflow de la PR elle-même. **La barrière effective est le geste opérateur, c'est-à-dire la synchro manuelle.** Si l'opérateur synchronise sans relire, Argo accepte ce que le projet nomme : N7b, Argo accepte la baisse PSA de `lab-pg`.
2. Une Application enfant `project: default` ajoutée dans `apps/`, qui relève elle aussi de `platform/**`, est **créée** par `lab-root`. C'est le kind permis. Elle reste inerte : `InvalidSpecError`, rien n'est appliqué. Même chose pour N8.
3. La revue humaine obligatoire est une option que Paul doit décider : ruleset avec revue code owner et identité d'agent distincte. Elle n'est **pas activée**. CODEOWNERS sans revue obligatoire n'est pas un contrôle d'autorisation.
4. Le contrôleur Argo garde `*/*/*` : l'API server ne refuse rien à Argo. Toutes les barrières prouvées ici sont des barrières **Argo** (AppProject). L'imitation de la synchro par un compte de service restreint (`application.sync.impersonation`) en ajouterait une au niveau de l'API. Elle n'est pas activée (values hors périmètre de ce flux).

## Modèle de menace

- **Attaquant** : un agent applicatif, ou une PR compromise, qui peut ouvrir une PR et la merger si `ci-ok` passe. On suppose le pire : la CI est contournée, puisqu'elle s'exécute depuis la PR.
- **Cible** : les droits du contrôleur Argo (`*/*/*`), les politiques qui bornent l'agent (VAP, RBAC, PSA, authz OpenChoreo) et les Secrets.
- **Hors périmètre** : un attaquant qui détient les identifiants opérateur (admin Argo, kubeconfig OKE, droits admin GitHub). Il n'y a alors aucune frontière (`docs/GITOPS-TRUST-BOUNDARY.md`).

## Séparation par source (`platform/install/argocd/`)

| Projet | Source (tenue par l'Application de `apps/` + CI A2/A3) | Destinations | Kinds | Synchro |
|---|---|---|---|---|
| `lab-root` | `platform/install/argocd/apps` | `lab-argocd` | `Application` seulement | auto |
| `lab-platform` | `platform/**` (include fermé) | `default`, `lab-pg` | cluster : 5 types OpenChoreo, 2 VAP et VAPB `lab-*`, Namespace `lab-pg`, tous nommés ; namespacé : Environment, DeploymentPipeline, NetworkPolicy, Cluster CNPG | **manuelle forcée** (fenêtre `deny`) |
| `lab-o` | `generated/namespaces/default` | `default` | **aucun kind cluster-scoped** ; 9 kinds OpenChoreo applicatifs | automatique sans prune (ApplicationSet `lab-o`) |
| `lab-authz` | `platform/authz` | `lab-argocd` | `ClusterAuthzRole*` `lab-*` | **manuelle forcée** (fenêtre `deny`) |
| `default` | — | — | rien (verrouillé) | — |

Un AppProject ne restreint pas un **chemin**. Le lien entre une source et son projet passe par l'Application enfant, qui est un changement `platform/**`. `argo_guard` le contrôle en CI (A2/A3). Argo, de son côté, borne ce que chaque projet peut appliquer, quel que soit le chemin.

## Attaque → barrière réelle → preuve

PASS = refusé comme attendu, avec observation de l'état Argo (opération, conditions) **et** de l'API server. Détail et horodatage : `tests/argo-escalation/RESULTS.md`.

| Attaque | Type de PR | Barrière réelle | Barrière CI (`argo_guard`, contournable par la PR) | Preuve réelle |
|---|---|---|---|---|
| Application dans `generated/` | applicative | Argo : `lab-o` sans kind Application | A1, G1 | N2b **PASS** |
| ClusterRoleBinding, ClusterRole `*`, VAP nouvelle ou modifiée dans `generated/` | applicative | Argo : `lab-o` sans kind cluster-scoped | S1, G1 | N5a, N5c, N5d, N5e **PASS** |
| Namespace `kube-system` ou label PSA (`lab-pg`) depuis `generated/` | applicative | Argo : `lab-o` sans Namespace | G1, S1 | N5b, N5g **PASS** |
| Secret en clair dans `generated/` | applicative | Argo : Secret hors whitelist `lab-o` | S1, G1 (+ gitleaks) | N5f **PASS** |
| Objet applicatif hors de `default` (par exemple `kube-system`) | applicative | Argo : destination `lab-o` = `default` seulement | — | N5h **PASS** |
| Application enfant `project: default` | privilégiée (`apps/`) | Argo : `default` verrouillé (aucun dépôt, aucune destination) ; l'Application est créée mais inerte | A2 | N1 **PASS** |
| Application hors `apps/` (dans `platform/policies`) | privilégiée | Argo : Application hors whitelist `lab-platform` | A1 | N2a **PASS** |
| Application dans `kube-system` | privilégiée (`apps/`) | Argo : destination `lab-root` = `lab-argocd` | — | N3 **PASS** |
| Application qui synchronise les AppProject | privilégiée (`apps/`) | Argo : AppProject hors whitelist de tout projet | A2, P1 | N8 **PASS** |
| `lab-authz` passé en `automated` | privilégiée | Argo : fenêtre `deny` (`manualSync: true`) du projet `lab-authz` | A4 | N4 **PASS** (automatique bloqué, manuel possible) |
| Merge sur `platform/**` (VAP, PSA…) | privilégiée | Argo : fenêtre `deny` du projet `lab-platform`, donc geste opérateur obligatoire | A4, P3 | N9, N7a **PASS** |
| ClusterRole `*` par `platform/**`, même synchronisé à la main | privilégiée | Argo : kinds cluster-scoped nommés de `lab-platform` | S1 | N6 **PASS** |
| Baisse PSA de `lab-pg` par `platform/**`, synchronisée à la main | privilégiée | **aucune dans Argo** (Namespace nommé) : relecture opérateur | S3 | N7b **ACCEPTÉ par Argo** (attendu) |
| Modifier les VAP ou le RBAC du cluster par une PR applicative | applicative | Argo `lab-o` (cluster-scoped interdit) ; le RBAC du cluster n'est synchronisé par aucun projet (bootstrap) | S1 | N5a, N5c, N5e **PASS** |

**API server / VAP.** Aucune VAP du labo ne vise l'identité d'Argo : `lab-cluster-agent-scope` vise l'agent OpenChoreo et `lab-cell-pod-hardening` les pods `dp-*`. Le contrôleur Argo a `*/*/*`. **Toutes les barrières prouvées ci-dessus sont donc des barrières Argo (AppProject), pas des barrières de l'API.** C'est suffisant tant que les AppProject ne peuvent être changés que par l'opérateur. C'est le cas : aucun projet n'admet le kind AppProject (N8), et `project-*.yaml` est du bootstrap.

## Ce qui tourne en CI, et ce qui n'y tourne pas

- **En CI** (job `platform`, inclus dans `ci-ok`) :
  - `tools/oke/argo_guard.py` : nouvelles règles G1 et P3, A2/A3/A4 étendues à `lab-o`/`lab-platform` (O1-O5 pour l'ApplicationSet `lab-o`), S1 par projet ;
  - `tests/argo-guard/run.sh` : 28 cas, dont 13 nouveaux pour le flux A2 ;
  - `kubeconform -strict` des AppProject et Application (`tools/oke/kubeconform-platform.sh`, inchangé, couvre `argocd/*.yaml` et `apps/*.yaml`) ;
  - shellcheck et yamllint de `tests/argo-escalation/`.
- **Hors CI** : `tests/argo-escalation/run.sh`. Il exige un cluster jetable, Argo, CRD et un dépôt Git servi dans le cluster, soit une vingtaine de minutes. Il se rejoue à la main, et sa preuve est archivée dans `tests/argo-escalation/evidence/`. Toute PR qui modifie `platform/install/argocd/**` devrait le rejouer. C'est une règle de revue, pas un contrôle technique.
- **Limite de la CI** : elle s'exécute depuis la PR, qui peut la modifier. C'est un filet contre l'erreur, **pas une frontière contre un agent hostile**. Les frontières sont les AppProject, appliqués par l'opérateur, et la synchro manuelle des projets privilégiés.

## Impacts à reporter (hors périmètre de ce flux)

- `tools/oke/verify.sh` (B11-projects) attendait les projets `lab lab-authz lab-root` ; corrigé (T-491) : `lab-platform lab-o lab-authz lab-root`. B11-lab-platform suppose une synchro faite : l'étape 11 doit inclure une synchro manuelle de `lab-platform`.
- `tools/oke/uninstall.sh` supprime les Applications `lab-root lab-platform lab-authz` (l.211) : l'ApplicationSet `lab-o` et ses Applications `lab-o-<app>` n'y figurent pas (hors périmètre T-491, à traiter).
- `docs/CI-PLATFORM-CHECKS.md` décrit encore le projet `lab` et les règles d'avant A2.
- `docs/APP-CONTRACT.md` §5 annonce `lab-platform` en selfHeal : ce n'est plus le cas (fenêtre `deny`).
