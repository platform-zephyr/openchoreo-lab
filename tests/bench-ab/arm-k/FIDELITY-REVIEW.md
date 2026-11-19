# Revue de fidélité du bras K (T-504)

Date : 2026-11-19. Niveau de preuve : STATIC (lecture seule, aucun accès cluster). Revue indépendante exigée par `docs/research/POC-OPENCHOREO-STRATEGY.md` §2.5 point 5.
Références : bras K = `bench-ab-arm-k` @ `742bbd6` ; kube-ops = `ef50472` (HEAD du clone local, comparé par `diff -ru`). Notation : `K:` = bras K, `KO:` = kube-ops, `O:` = ce dépôt.

## Conclusion
**Verdict global : FAIL conditionnel.** Le contenu copié est fidèle (PASS), mais 3 écarts empêchent une mesure valide : M1 est impossible en l'état pour le bras K, M3 n'a pas d'équivalent non-prod, et les portes (`just check`, CI) manquent. À corriger ou à consigner AVANT la passe 0 (§4). Aucun écart ne favorise O par un défaut de copie ; les écarts qui handicapent K viennent presque tous du principe « aucun développement sur kube-ops » : ce sont des MESURES à consigner, pas des défauts.

## 1. Verdict par point
| # | Point | Verdict | Preuve |
|---|---|---|---|
| 1 | Chart `platform-app` inchangé | PASS | `diff -ru` KO/K de `k8s/charts/platform-app` : 0 différence. |
| 2 | `AGENTS.md`, `CLAUDE.md`, `k8s/CLAUDE.md`, `.claude/` | PASS | `diff -ru` : 0 différence (settings, hook `secret-output-guard.py`, agents). |
| 3 | Skills `.agents/skills` (11 sur 11) | PASS | Seules différences : 3 SKILL.md avec hôtes/IP factices (D11). Neutre. |
| 4 | Contrat et statut (`app-status.sh`, `application-contract.md`) | PASS | `diff` : 0 différence, sauf 1 hôte d'exemple factice. |
| 5 | Règles d'admission (VAP, PSA, NetworkPolicy, Kyverno) | FAIL partiel | Voir E3, E4. PSA et CNP du chart : PASS (copiés). |
| 6 | Outils et gates (`just check`, CI) | FAIL | Voir E2. |
| 7 | Livraison Argo (ApplicationSet, AppProject) | FAIL | Voir E1, E5. |
| 8 | Nature des pièges `traps/` | PASS avec réserve | Mêmes consignes K et O (`diff` : seule la ligne `repo:` change). Voir E4. |
| 9 | Tâches `tasks/M*.K.yaml` | FAIL pour M3 | Voir E6. |

## 2. Écarts classés
| Id | Écart | Classe | Sens sur la mesure |
|---|---|---|---|
| E1 | **echo-bench sort du namespace de son AppProject.** Le chart code `svc-<name>` en dur (`K: k8s/charts/platform-app/templates/namespace.yaml:7`, `workload.yaml:5`) ; l'AppProject K n'admet que `lab-k-*` (`K: k8s/bootstrap/argocd-root/apps-generated-project.yaml:23`, `:28`) et l'Application vise `lab-k-<name>` (`K: apps-generated-applicationset.yaml:61`). Argo refuse la synchro : M1, M4, P1, P2 sont irréalisables sans arbitrage. DIFF §4.1 le signale. | À CORRIGER | Handicape K à 100 % ; fausse S1. Avantage O mécanique. |
| E2 | **Gates absentes.** K n'a ni `.justfile`, ni `package.json`, ni `tests/` (harness, `tests/apps-generated/run.py`), ni workflows (`KO: .justfile:28` `check`, `KO: .github/workflows/apps-generated-contract.yaml`, `platform-app-contract.yaml`). Or `K: AGENTS.md:37` ordonne `just check`, et cite `kubectl-rw`, `kube-preflight`, `just verify-delivery` (`K: AGENTS.md:38-46`), tous absents. L'agent K reçoit des instructions inexécutables (tours perdus) et n'a aucune validation avant PR. O a `tools/dev/check` (`O: AGENTS.md:13`) et la CI de `appgen`. | Défaut de fidélité + mesure | Handicape K (tours, $, échecs tardifs). Le coût d'une porte absente est une MESURE ; l'écart d'instructions mortes est à consigner dans la passe 0. |
| E3 | **Couche Kyverno absente.** KO a `k8s/infrastructure/security/policies/apps-generated-boundary.yaml` (ValidatingPolicy, Deny hors `svc-*`) et le test négatif `tests/apps-generated/run.py`. Pas copiés dans K. Sur le banc, le cluster partagé applique en revanche les VAP de base d'O (`O: platform/baseline/vap-baseline-pod-hardening.yaml:59`, Deny sur privileged/host*, tous namespaces sauf `kube-system`, `cloudflared`) à K comme à O. | Neutre pour P1 ; favorise K pour le contenu du piège | P1 (privilégié) est contenu pour K par VAP cluster, pas par le chemin kube-ops. Le résultat S6 de K ne mesure pas la défense de kube-ops. |
| E4 | **Containment des pièges non reproduit à l'identique.** P2 (`kube-system`) : le chart interdit d'exprimer un namespace libre (hardcode `svc-`), et l'AppProject unique `lab-k` limite aussi les apps Kustomize ; KO donne aux apps Kustomize le projet `applications` (destination `''`, `*/*`, `KO: k8s/bootstrap/argocd-root/applications-project.yaml:106-108`), donc K est plus fermé que KO sur la voie Kustomize. P3 (base supprimée) : `lab-pg` hors périmètre AppProject. | Favorise K sur S6 (K sur-contenu) | Un 3/3 de K sur S6 sous-estime l'exposition réelle de KO ; un échec K impossible. À consigner. |
| E5 | **AppProject unique `lab-k` pour les deux chemins.** Il n'admet ni `ExternalSecret`, ni `SecretStore`, ni `Password`, ni écriture dans `lab-pg` (DIFF §4.2). M2 (miniflux) y est irréalisable tel quel ; l'`ApplicationSet` de `lab-pg/miniflux-database.yaml` n'existe pas. | À CORRIGER ou M2 NOT_TESTED | Handicape K. |
| E6 | **M3 sans non-prod côté K** (DIFF §4.3). La tâche exige « valider hors production » ; KO n'a pas d'environnement non-prod pour une app Kustomize. O a deux environnements. | Mesure légitime, à consigner | Handicape K (tâche non faisable ou dégradée). Ne pas inventer de non-prod dans K (principe de Paul). Si le grader exige `lab-k-ntfy` en non-prod, M3.K est `NOT_TESTED` = échec de K. À décider par Paul avant la passe 0, pas par l'agent. |
| E7 | Observation par check run Argo (D6) ; pas de `kubectl-ro`/`kubectl-rw`. | Neutre | Identique côté O (stratégie §2.2). |
| E8 | ntfy stateless sans PVC/ExternalSecret ; miniflux sans OIDC, base `lab-pg` ; hôtes factices ; cluster `oracle-a1` (D8-D12). | Neutre à léger avantage K | Moins de complexité pour K que KO réel ; symétrique à O (M3 stateless, M2 sans OIDC). |
| E9 | Le chart rend un hôte `<name>.<domaine public de kube-ops>` (`K: templates/network.yaml`, HTTPRoute). | Neutre | Pas de DNS sur le banc ; la réponse HTTP 200 se teste à l'adresse interne. Fuite de nom d'hôte public : à vérifier par la porte de fuite du dépôt public. |
| E10 | `AGENTS.md` K contient des règles (Doppler, Linear, Paul) inutiles sur le banc. | Neutre (fidèle) | Surcoût de tokens identique à KO ; garde la fidélité. |

## 3. Points non vérifiés
- Rendu `kustomize build` de ntfy et miniflux : NOT_TESTED (DIFF §5).
- Acceptation Argo des Applications K (AppProject `lab-k` non listé dans la preuve de T-487) : NOT_TESTED.
- Contenu de la CI du bac à sable : aucun workflow ; NOT_TESTED.
- Résultat de `diff` calculé sur l'arbre de travail de kube-ops (HEAD = `ef50472`, SHA lu dans `.git/HEAD` et `refs/heads/main`) ; arbre propre non vérifié par `git status` (outil refusé dans cette session).

## 4. À corriger AVANT la passe 0
1. **E1** (bloquant) : arbitrage de Paul entre (a) paramètre de préfixe dans le chart (viole « chart inchangé ») et (b) admission de `svc-*` dans `lab-k`. Sans choix, M1, M4, P1 et P2 du bras K ne produisent rien.
2. **E5** (bloquant pour M2) : élargir `lab-k` aux kinds de kube-ops (copie du projet `applications`, restreinte à `lab-k-*` et `lab-pg`) ou déclarer M2.K `NOT_TESTED`.
3. **E6** : décision de Paul sur M3.K (environnement non-prod absent). Sans décision, M3.K vaut échec de K, ce qui est une mesure et non une erreur.
4. **E2** : décider si les portes de kube-ops (`.justfile`, `package.json`, scripts de contrat, workflows) sont copiées. Recommandation : les copier à l'identique (fidélité) ; sinon corriger `AGENTS.md` K n'est PAS permis (copie fidèle) et la perte est à consigner comme mesure.
5. Consigner dans `tests/bench-ab/thresholds` la lecture de S6 (E3, E4) : un 3/3 de K n'est pas la mesure de la défense réelle de kube-ops.
6. Vérifier `kustomize build` des 2 apps Kustomize (CI K ou local) avant la passe 0.

Aucun écart ne doit être « corrigé » en rendant K plus capable que kube-ops réel : tout écart restant dans ce sens est une mesure.
