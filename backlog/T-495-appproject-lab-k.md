---
id: T-495
title: "AppProject lab-k (frontière du bras K) et racine lab-k-root (synchro manuelle) pour le bac à sable bench-ab-arm-k"
status: in-progress
phase: P1
adr: [0025, 0002]
depends_on: []
class: REVUE
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-495 — AppProject `lab-k` et racine `lab-k-root`

## Intention
Constat du 2026-11-18 : l'AppProject `lab-k` n'existe pas dans ce dépôt (`platform/install/argocd/project-lab.yaml`), alors que T-487 (critère 1), T-212 et le bras K du banc A/B (`docs/research/POC-OPENCHOREO-STRATEGY.md` §2.2, ADR-0025, `tests/bench-ab/arm-k/DIFF.md`) en dépendent. OKE n'a qu'un seul Argo CD (`lab-argocd`). Ce ticket pose NOTRE frontière du bras K, jamais celle livrée par le bac à sable `platform-zephyr/bench-ab-arm-k` (que des agents modifient), et une racine `lab-k-root` qui livre ses deux ApplicationSets de livraison par geste opérateur.

Décisions de Paul du 2026-11-18 appliquées :
- destinations `lab-k-*` ET `svc-*` : le chart `platform-app` de kube-ops code en dur `svc-<nom>` et ne doit pas être modifié ;
- kinds = EXACTEMENT ceux de l'AppProject `apps-generated` copié de kube-ops (bac à sable, commit `742bbd6b8c4e894b8bc31800ee234de0d2b80dd6`) : aucun développement supplémentaire pour le bras K ; ExternalSecret, SecretStore et Password ne sont PAS ajoutés (un bras K moins capable que le bras O fait partie de la mesure) ;
- accès au dépôt : les clés de déploiement sont désactivées sur `bench-ab-arm-k` (HTTP 422, politique d'organisation). La source est donc une URL HTTPS SANS identifiant (aucun Secret de dépôt). Paul tranche entre (a) dépôt PUBLIC (recommandé : copie MIT de kube-ops et valeurs factices, aucun secret) et (b) App GitHub en lecture seule (option « dépôt privé » ci-dessous, non implémentée).

## Périmètre de fichiers
platform/install/argocd/project-lab.yaml, platform/install/argocd/apps/lab-k-root.yaml, tools/oke/argo_guard.py, tools/oke/argo_guard_k.py, tests/argo-guard/test_rules.py, tests/argo-guard/test_characterization.py, tests/argo-guard/golden.json.gz, tests/argo-guard/run.sh, tools/oke/verify.sh, tools/oke/install.sh, tools/oke/uninstall.sh, NOTICE, backlog/T-495-appproject-lab-k.md

Ce qui est livré :
- AppProject `lab-k` : sources = `https://github.com/platform-zephyr/bench-ab-arm-k(.git)` seul ; destinations = cluster local, `lab-k-*` et `svc-*` ; Namespace sous ces deux globs ; 7 kinds namespacés de kube-ops (Deployment, Service, ServiceAccount, PodDisruptionBudget, ServiceMonitor, HTTPRoute, CiliumNetworkPolicy) et sa blacklist (Role, RoleBinding, Secret, ResourceQuota, LimitRange). Aucune destination `openchoreo-*`, `argocd`, `kube-system`, `lab-argocd`, `lab-pg`, `lab-secrets`.
- AppProject `lab-k-root` : ApplicationSet seul, dans `lab-argocd`, même dépôt, fenêtre `deny` permanente (`manualSync: true`).
- Application `lab-k-root` (sous `apps/`, livrée par `lab-root`) : synchro MANUELLE ; `k8s/bootstrap/argocd-root`, `include` = `apps-generated-applicationset.yaml` et `applications-applicationset.yaml` seulement (l'AppProject copié `apps-generated-project.yaml` est exclu) ; `FailOnSharedResource`.
- `argo_guard.py` règles L1-L4 (module `tools/oke/argo_guard_k.py` : `argo_guard.py` reste ≤ 600 lignes, cliquet de maintenabilité) ; `svc-*` et `lab-k-*` refusés dans tout autre projet (P2 joker) ; 10 cas négatifs dans `run.sh`, 10 tests dans `test_rules.py`, gel régénéré (seul changement des cas existants : la liste des projets admis citée dans les messages A2).
- `verify.sh --step 11` : B11-lab-k-projects, B11-lab-k-dest, B11-lab-k-root-manual (B1 et B6 inchangés).
- Le contrôleur ApplicationSet reste à 0 réplica (son activation est une autre PR de la session locale, T-487).

## Critères de fin
- [x] AppProjects `lab-k` et `lab-k-root` et Application `lab-k-root` versionnés ; `python3 -I tools/oke/argo_guard.py .` : 0 écart — STATIC, 2026-11-19
- [x] cas négatifs refusés : `lab-k` vers `kube-system`, `argocd`, `lab-argocd` ; autre dépôt ; ExternalSecret ; ClusterRole ; `svc-*` dans `lab-o` ; AppProject copié inclus ; `lab-k-root` automated ; Application `project: lab-k` — `tests/argo-guard/run.sh` 58 PASS, 0 FAIL ; `python3 -m unittest discover -s tests/argo-guard` OK — STATIC, 2026-11-19
- [ ] décision de Paul : dépôt `bench-ab-arm-k` public (a) ou App GitHub (b) ; si (b), PR qui implémente l'option « dépôt privé »
- [ ] RUNTIME OKE (session locale) : `install.sh --step 11 --apply` puis `verify.sh --step 11` : B11-lab-k-projects, B11-lab-k-dest, B11-lab-k-root-manual PASS (preuve datée, `backlog/evidence/`)
- [ ] RUNTIME OKE (session locale) : synchro manuelle de `lab-k-root` : Synced ; seuls les ApplicationSets `apps-generated` et `applications` créés dans `lab-argocd` ; aucun AppProject modifié (`kubectl -n lab-argocd get appproject lab-k -o yaml` = celui de ce dépôt) (preuve datée)
- [ ] RUNTIME OKE (session locale) : refus d'une destination hors périmètre prouvé par Argo (Application de test `project: lab-k` vers `kube-system` : `ComparisonError`/sync refusée), puis supprimée (preuve datée)

## Gestes de la session locale (OKE, après fusion)
1. Accès au dépôt, sans identifiant : `git ls-remote https://github.com/platform-zephyr/bench-ab-arm-k.git HEAD` doit répondre SANS demander d'identifiant (option a). Sinon : STOP, BLOCKED (décision de Paul attendue).
2. `tools/oke/install.sh --step 11` (dry-run), puis `tools/oke/install.sh --step 11 --apply` : réapplique `project-lab.yaml` (ajoute `lab-k`, `lab-k-root`) ; `lab-root` (automatique) crée l'Application `lab-k-root`.
3. `tools/oke/verify.sh --step 11` : B11-* PASS, dont B11-lab-k-projects, B11-lab-k-dest, B11-lab-k-root-manual.
4. Relire le diff avant synchro : `argocd app diff lab-k-root` (port-forward) ou l'UI : 2 ApplicationSets, `template.spec.project: lab-k`, dépôt `bench-ab-arm-k` seul, aucune app nommée `root` (collision avec `lab-k-root`).
5. Synchro manuelle : `argocd app sync lab-k-root` (ou bouton « Sync » de l'UI) ; la fenêtre `deny` laisse passer la synchro manuelle seulement.
6. Contrôles : `kubectl -n lab-argocd get applicationsets.argoproj.io` (lab-o, apps-generated, applications) ; `kubectl -n lab-argocd get application lab-k-root -o jsonpath='{.status.sync.status}'` = Synced ; AppProject `lab-k` inchangé.
7. Test de refus : Application de test `project: lab-k`, destination `kube-system` : Argo refuse ; supprimer l'Application de test.
8. Activation du contrôleur ApplicationSet : autre PR (T-487), pas ce ticket.

## Option « dépôt privé » (documentée, NON implémentée)
Si Paul choisit (b) : une App GitHub installée sur `bench-ab-arm-k` seul, permission `Contents: read-only`. Secret de dépôt Argo (support natif d'Argo CD, `docs/operator-manual/declarative-setup.md`) créé hors Git dans `lab-argocd` par la session locale, label `argocd.argoproj.io/secret-type: repository`, champs `type: git`, `url: https://github.com/platform-zephyr/bench-ab-arm-k.git`, `githubAppID`, `githubAppInstallationID`, `githubAppPrivateKey` (clé lue par tube depuis un fichier, jamais affichée ni committée). Même URL HTTPS : `project-lab.yaml`, `lab-k-root.yaml` et les ApplicationSets du bac à sable ne changent pas. `verify.sh` ajouterait un contrôle de présence du Secret (label et `url`, sans lire la clé).

## Notes
- Risques résiduels : un ApplicationSet du bac à sable peut nommer n'importe quel projet dans son modèle ; seul `lab-k` (et `lab-k-root`, fenêtre deny) accepte ce dépôt comme source (`argo_guard` L1), donc une Application générée dans un autre projet est refusée par Argo. Une app du bac à sable nommée `root` produirait l'Application `lab-k-root` : à relire au geste 4. L'ApplicationSet `applications` (modèle kube-ops) n'utilise ni `goTemplate` ni `missingkey=error` : objet de la mesure, non corrigé.
- Les manifests de miniflux (ExternalSecret, SecretStore, Password, objets dans `lab-pg`) seront refusés par `lab-k` : voulu (décision de Paul).
- `uninstall.sh` étape 11 supprime aussi l'Application `lab-k-root` ; le retrait des ApplicationSets et Applications `lab-k-*` relève du nettoyage du banc (T-212).
- Implémentations publiques consultées : https://github.com/argoproj/argo-cd/blob/109ca7ca71139e514114499d294a492e7910a965/docs/user-guide/projects.md (Apache-2.0, adopté : globs de destination et `name` glob de clusterResourceWhitelist) ; https://github.com/argoproj/argo-cd/blob/109ca7ca71139e514114499d294a492e7910a965/docs/operator-manual/declarative-setup.md (Apache-2.0, adopté pour l'option GitHub App) ; AppProject `apps-generated` de kube-ops `ef50472bc427bbb5fb342cebf2f4db408157f5b3` via le bac à sable `742bbd6b` (MIT, adapté, ligne `NOTICE`).
