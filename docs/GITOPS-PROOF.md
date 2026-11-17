# Preuve GitOps Git → Argo CD → OpenChoreo — **k3d** (pas OKE)

Date : 2026-11-17. Banc : `tests/gitops-k3d/run.sh` ; résultats datés : `tests/gitops-k3d/RESULTS.md` ; preuves brutes : `tests/gitops-k3d/evidence/`.
Rien ici n'est une preuve OKE.

## 0. Conclusion

1. **La boucle Git → Argo CD → OpenChoreo fonctionne sur k3d** avec les objets réels du dépôt : déploiement (pod Running sous PSA restricted, default-deny, HTTP 200 via `gateway-default`), modification (replicas, version par digest), dérive (selfHeal Argo 2-4 s ; objets rendus réparés par OpenChoreo), rollback par `git revert` (release d'origine réutilisée, immuable), redémarrage du contrôleur sans impact. 18 PASS, 6 FAIL, 2 NOT_TESTED (`tests/gitops-k3d/RESULTS.md`).
2. **Mais generated/ ne se déploie pas tel quel** : whoami échoue au rendu (pas de `gateway.ingress.internal`), et Argo affiche `Healthy` quand même. Il a fallu un commit de correction de l'Environment.
3. **Quatre défauts du contrat/générateur bloquent l'exploitation** : pin du ProjectReleaseBinding jamais avancée (quota/PVC ignorés), Application OutOfSync permanente après chaque release, passage stateless→stateful refusé par l'API, retrait de la dernière app refusé par Argo. Aucun ne casse l'app en service (l'ancienne version reste servie), tous rendent l'état faux ou bloqué sans alerte.
4. **Latence** : 100 à 245 s par commit en polling (défaut Argo, pas de webhook prévu sur OKE) ; 2 à 6 s Git→pod avec un refresh forcé.
5. Le cluster-agent n'a renvoyé **aucun 403** pendant le run de référence (0 / 1413 requêtes).

## 1. Montage de l'essai (et écarts avec OKE)

| Élément | k3d (cet essai) | OKE (pack Phase B) | Effet de l'écart |
|---|---|---|---|
| Argo CD | chart argo-cd 10.3.3 (v3.5.1), sha256 vérifié, values `platform/install/values/argocd.yaml` + `tests/gitops-k3d/argocd-values-k3d.yaml` | même chart et mêmes values | aucun sur le comportement Argo |
| Namespace Argo | `argocd` (périmètre imposé) | `lab-argocd` | nul |
| AppProject | `gl` (calque de `project-lab.yaml`, destination `gl-oc`) | `lab` | nul ; voir correction O1 (§4) |
| Namespace OpenChoreo des apps | `gl-oc` | `default` | generated/ code `namespace: default` en dur. Un plugin CMP (`gl-ns-remap`, sidecar du repo-server, même image Argo épinglée) relit Git **sans modifier les fichiers** et remplace seulement la ligne `  namespace: default`. Sur OKE : source `directory`, sans plugin. |
| Source | GitHub `platform-zephyr/openchoreo-lab` `main` (joignable depuis le cluster), puis dépôt de test `gl-repo` (clone du même `main`, servi en `git://` dans le cluster) | GitHub `main` | les commits de test (modification, rollback, retrait) ne touchent pas le vrai dépôt |
| Applications | `gl-platform` (CCT, CPT, CRT, ClusterTrait, VAP, `40-openchoreo-env.yaml`), `gl-apps` (`generated/…/projects/whoami`) | `lab-root` → `lab-platform` (+ `lab-apps` à écrire) | `data/lab-pg-*` exclu (hors périmètre gl-*) ; les autres apps de generated/ exigent lab-pg, ESO et des SecretReference |
| Déclenchement | polling Argo par défaut (120 s + gigue) mesuré sur les 2 premiers commits, puis `argocd.argoproj.io/refresh=normal` après chaque push (équivalent webhook) | polling (aucun webhook prévu) | les durées « webhook » sont des minima |
| Data plane | ClusterDataPlane `default` du k3d, kgateway, NetworkPolicy appliquées par kube-router | Cilium chaining ; CCNP kube-ops `allow-egress-unisolated` (C1) | le default-deny n'est pas prouvé sur OKE tant que C1 n'est pas corrigé |

Namespace `dp-gl-oc-whoami-production-*` : créé par le CPT `cell-restricted` (préfixe imposé par le contrôleur), supprimé au nettoyage.

## 2. Ce qui est prouvé (k3d)

| Propriété | Preuve | Résultat |
|---|---|---|
| Argo épinglé (chart sha256), PSA restricted | T-BOOT | PASS |
| `platform/` synchronisé par Argo (CCT, CPT, CRT, ClusterTrait, VAP, Environment, Pipeline) | T-PLAT | PASS |
| Objets réels de generated/ synchronisés tels quels | T-GH-SYNC | PASS (rendu : FAIL, voir G1) |
| Une correction plateforme passe par un commit, pas par kubectl | T-DEPLOY | PASS |
| Pod Running sous PSA restricted, default-deny effectif, HTTP 200 via gateway | T-DEPLOY | PASS |
| replicas et version par `app.yaml` → appgen → commit | T-MOD-REPLICAS, T-MOD-VERSION | PASS |
| ComponentRelease immuable ; ancienne release conservée (Prune=false) | T-IMMUT, T-MOD-VERSION | PASS |
| Un objet = un contrôleur : `releaseName` écrit par Argo seul ; le contrôleur n'écrit que finalizers et `PRB.spec.projectRelease` (managedFields, run 1) | T-DRIFT-ARGO, `T-PIN-PRB.txt` | PASS |
| `ignoreDifferences` sur `/spec/projectRelease` inutile : en SSA, un champ absent de Git n'est pas comparé (PRB `Synced` pendant tout le run) | T-GH-SYNC → T-RESTART | PASS (corrige APP-CONTRACT §5) |
| Dérive manuelle corrigée : CR possédés par Argo (selfHeal 2-4 s), objets rendus dans `dp-*` (OpenChoreo, ≤ 2 s à 314 s) | T-DRIFT-* | PASS |
| Objet hors Git signalé orphelin, non supprimé | T-DRIFT-ORPHAN | PASS |
| Rollback `git revert` → release précédente réutilisée, HTTP 200 | T-ROLLBACK | PASS |
| Redémarrage du contrôleur : pods, Deployment et binding intacts | T-RESTART | PASS |
| Pin du PRB par un 2e commit : quota appliqué, Argo reprend le champ en SSA sans conflit | T-PIN-PRB | PASS |
| Finalizers : suppression des objets OpenChoreo sans blocage (31-75 s) | T-FINALIZERS | PASS |
| Cluster-agent : 0 réponse 403 | `evidence/AGENT-403.txt` | PASS |

## 3. Ce qui reste à prouver sur OKE

1. Toute la boucle avec la source `directory` réelle (sans plugin) dans `default`, AppProject `lab`, namespace `lab-argocd`.
2. Polling Git→Argo réel sur OKE (aucun webhook) et charge du repo-server (`reposerver.parallelism.limit: 1`).
3. Default-deny des cellules sous Cilium **après** la correction C1 (CCNP `allow-egress-unisolated`).
4. PVC sur la StorageClass OCI (block volume 50 Go minimum : coût et quota du compte), et sa conservation au retrait.
5. Redémarrage du contrôleur et du cluster-agent avec les requests réduites de la Phase B (55m / 304 Mi).
6. Health checks Lua (correction A5) et `ignoreDifferences` effectifs sur Argo v3.5.1 d'OKE.
7. Gateway interne réelle (hôte, listener) une fois la correction G1 (§4) choisie.

## 4. Corrections à apporter (NON appliquées ; à faire par PR revue)

Ordre = impact. Fichier cible entre parenthèses. Aucune n'est appliquée par cet essai.

1. **G1 — gateway interne absente** (`platform/install/manifests/40-openchoreo-env.yaml` et `30-clusterdataplane.yaml.tmpl`). appgen émet `visibility: [internal]` pour `exposure.mode: private` ; le CCT exige alors `gateway.ingress.internal`, que ni l'Environment ni le ClusterDataPlane ne déclarent → `RenderingFailed` sur **toutes** les apps privées (T-GH-RENDER). Correctif prouvé sur k3d : `spec.gateway.ingress.internal {name: gateway-default, namespace: openchoreo-data-plane, http: {host, listenerName: http, port: 19080}}` sur l'Environment (hôte OKE à choisir). Alternative : appgen n'émet pas `visibility` pour `private`.
2. **A1 — annotations Argo absentes de generated/** (`tools/appgen`). APP-CONTRACT §5 exige `Prune=false` sur Component/Resource et `Prune=false,Delete=false` sur ComponentRelease, mais generated/ ne les porte pas. Sans elles, la seule option sûre est `prune: false` sur toute l'Application. Émettre `metadata.annotations["argocd.argoproj.io/sync-options"]` (simulé par `tests/gitops-k3d/annotate_syncopts.py`, T-ANNOT PASS).
3. **A2 — OutOfSync permanent après chaque release** (`tools/appgen` render). `render` efface generated/ et ne réécrit que la release courante ; l'ancienne, protégée par Prune=false, reste `requiresPruning` → Application OutOfSync pour toujours (T-PRUNE-STATUS), ce qui masque toute vraie dérive. Corriger : conserver dans Git les fichiers `releases/` existants (append-only ; purge explicite par PR), et vérifier en CI que `releaseName` pointe un fichier présent.
4. **A3 — pin du ProjectReleaseBinding** (`tools/appgen`, APP-CONTRACT §5-§6). Tout changement des paramètres du Project (quota calculé depuis replicas/size, `pvcs`, egress, database) crée une ProjectRelease que le PRB n'adopte jamais : quota et NetworkPolicy restent anciens, sans erreur visible (T-PIN-STALE ; run 1 : rollout bloqué `exceeded quota`). Ajouter `appgen pin-project <app> <env> <release>` (calque de `pin-resource`, 2e PR) et le documenter comme le pin RRB ; la CI doit signaler qu'un diff de `project.yaml` exige la 2e PR. Variante : refuser en CI tout changement de paramètres Project sans pin.
5. **A4 — passage stateless → stateful refusé** (`platform/component-types/service-restricted.yaml`). RollingUpdate → Recreate sur un Deployment existant : 422 `spec.strategy.rollingUpdate: Forbidden` (T-STRATEGY). Corriger le template (`rollingUpdate` explicitement vidé quand `strategy == Recreate`, à valider [S]) ou faire refuser par appgen le changement de `profile`/`update.strategy` sur une app existante (retrait puis ré-ajout).
6. **A5 — health checks Argo** (`platform/install/values/argocd.yaml`, `configs.cm`). Ajouter `resource.customizations.health.openchoreo.dev_ReleaseBinding` (et `ProjectReleaseBinding`, `Component`) qui lit la condition `Ready` : Argo affiche `Healthy` sur un `RenderingFailed` (T-ARGO-HEALTH) et sur un rollout bloqué (T-STRATEGY).
7. **A6 — retrait de la dernière app** (APP-CONTRACT §4-§5, `lab-apps`). Argo refuse d'auto-synchroniser une Application qui deviendrait vide (« auto-sync will wipe out all resources », T-RETRAIT-1). Avec une Application `lab-apps` unique, retirer la dernière app est bloqué ; avec une Application par app, tout retrait l'est. Décider : `syncPolicy.automated.allowEmpty: true` (et alors prouver la conservation du PVC, NOT_TESTED ici) ou retrait = suppression de l'Application par PR.
8. **A7 — marge de quota** (`tools/appgen` `project_params`). Le quota = somme exacte des requests : aucune marge pour le pod en surplus d'un RollingUpdate (run 1 : 2 × medium sous 400m). Ajouter la request d'un pod (maxSurge) [S, observé seulement avec la pin bloquée].
9. **O1 — Application `lab-platform` invalide sur OKE** (`platform/install/argocd/apps/lab-platform.yaml`). `destination.namespace` absent, et l'AppProject `lab` n'autorise pas `''` → `InvalidSpecError` (reproduit sur k3d avec l'AppProject calqué). Ajouter `namespace: default`.
10. **C1 — APP-CONTRACT §5** : retirer « `ignoreDifferences: /spec/projectRelease` » (inutile en SSA, prouvé) et ajouter la règle « une modification des paramètres Project = 2 PR » (A3) ; §6 : un rollback qui traverse un changement de paramètres Project exige aussi de reculer la pin.

## 5. Limites de l'essai

- k3d seulement (1 nœud, flannel + kube-router, local-path) ; Argo dans `argocd` et apps dans `gl-oc` via un plugin de remappage (source `directory` non testée telle quelle).
- Seul whoami est testé ; les apps avec base (lab-pg, ESO, RRB) ne sont pas dans la boucle.
- Conservation du PVC au retrait **NOT_TESTED** (bloquée par A4 et A6) ; les étapes T-READD/T-RETRAIT-PVC du banc existent mais n'ont pas tourné jusqu'au bout (k3d rendu au coordinateur).
- « CI » = `appgen validate` + `render` ; kubeconform et `appgen check` non exécutés dans la boucle.
- Le run de référence (4) suit trois runs de mise au point ; les constats propres aux runs 1-3 sont cités avec leurs preuves (`evidence/RUN1-*`, `RUN2-*`).
- Durées « webhook » obtenues par `argocd.argoproj.io/refresh=normal` : sur OKE, sans webhook, compter 100-245 s par commit.
- Le serveur Git de test (`git daemon`, sans authentification) n'est qu'un outil de banc.
