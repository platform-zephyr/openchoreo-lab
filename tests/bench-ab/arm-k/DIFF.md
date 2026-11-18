# Bras K du banc A/B : écarts avec kube-ops (T-212)

Date : 2026-11-18. Niveau de preuve : STATIC. Dépôt PUBLIC : aucune IP, aucun hôte interne, aucun secret.

## Conclusion
- Le contenu du bac à sable est prêt (55 fichiers), mais il n'est **pas poussé** : BLOCKED (§5).
- `helm template` du chart `platform-app` : PASS pour `echo-bench` seulement. Pour `miniflux`, le chart
  refuse la base par conception ; pour `ntfy`, le contrat ne sait pas passer l'argument `serve`. Ces deux apps
  suivent donc le chemin Kustomize de kube-ops.
- Deux conflits entre « chart inchangé » et « cible `lab-k-*` » demandent un arbitrage de Paul (§4).

## 1. Références
| Objet | Valeur |
|---|---|
| kube-ops (dépôt public) | `SmadjaPaul/kube-ops`, SHA `ef50472bc427bbb5fb342cebf2f4db408157f5b3` (branche `main`) |
| Lecture | 56 fichiers lus par `raw.githubusercontent.com` à ce SHA, identiques à un clone local du même SHA |
| API GitHub publique pour kube-ops | NOT_TESTED : refusée par le proxy de la session (le SHA vient du clone local, puis la lecture par raw le confirme) |
| Bac à sable | `platform-zephyr/bench-ab-arm-k` (privé, vide sur `main`) ; SHA du commit : **aucun (non poussé)** |
| Empreinte du contenu préparé | sha256 de la liste `sha256sum` triée des 55 fichiers : `0183e729f6b395162f78f5b15965481734f61f73e1ae64aba5962053f9796078` |

## 2. Contenu du bac à sable
- Copiés à l'identique : `LICENSE` (MIT), `AGENTS.md`, `CLAUDE.md`, `k8s/CLAUDE.md`, `.claude/` (settings, hook
  `secret-output-guard.py`, agents, lien `skills`), `.agents/skills/` (sauf 3 fichiers, §3), chart
  `k8s/charts/platform-app/` (0.2.0), `scripts/app-status.sh` et `scripts/lib/output-mode.sh` (`app-status.v1`),
  `docs/contracts/app-status-v1.example.json`, `docs/platform/app-status.md`,
  `k8s/infrastructure/database/pg-shared-homelab/app-database.example.tmpl`.
- Ajouté : `NOTICE` (dépôt source, SHA, date, valeurs factices, écarts).
- Apps du banc (arbitrage de Paul du 2026-11-18, remplace `it-tools`, `vikunja`) :

| Tâche | App | Chemin kube-ops reproduit | Fichiers |
|---|---|---|---|
| M1, M4 | `echo-bench` | contrat à un fichier `apps-generated` + chart `platform-app` | `k8s/apps-generated/echo-bench/` (copie de `idp-e2e`, `traefik/whoami` épinglé par digest) |
| M2 | `miniflux` | Kustomize, modèle du golden path `service-postgres-oidc@v1` (kube-ops n'a pas de miniflux à ce SHA ; seulement la fixture de rejet et la mention de la PR #1593) | `k8s/applications/catalog/miniflux/`, `k8s/infrastructure/database/lab-pg/miniflux-database.yaml` |
| M3 | `ntfy` | Kustomize, copie de `k8s/applications/catalog/ntfy` | `k8s/applications/catalog/ntfy/` |

## 3. Seules différences avec kube-ops
| # | Différence | Où | Raison |
|---|---|---|---|
| D1 | Dépôt = bac à sable (`repoURL`, `sourceRepos`) | 3 fichiers de `k8s/bootstrap/argocd-root/` | champ 1 du mandat |
| D2 | Projet `lab-k` (au lieu de `apps-generated` et `applications`) ; AppProject renommé `lab-k` | idem | champ 2 du mandat |
| D3 | Préfixe `lab-k-` : nom des Applications (`gen-`/`apps-` → `lab-k-`), destination et glob de Namespace (`svc-*` → `lab-k-*`) ; namespaces `lab-k-ntfy`, `lab-k-miniflux` | idem + manifestes ntfy et miniflux | champ 3 du mandat, cible `lab-k-*` |
| D4 | Namespace Argo `argocd` → `lab-argocd` | 3 fichiers de `argocd-root/` | un seul Argo, celui du labo (ADR-0025) ; hors des 3 champs |
| D5 | Générateur Kustomize réduit à `k8s/applications/catalog` ; `ignoreDifferences` de `gpt-researcher` retiré | `applications-applicationset.yaml` | réduction aux 3 apps |
| D6 | Observation par check run publié (Argo CD Notifications, T-005), pas par `scripts/app-status.sh` ni Grafana Cloud | hors dépôt | l'agent n'a pas de kubeconfig ; `app-status.sh` est copié comme contrat mais ne tourne pas sur le banc |
| D7 | Pas de `kubectl-rw` (ni `kubectl-ro`, `kube-preflight`, `doppler-safe`) : écriture par PR seulement | scripts non copiés | protocole du banc (stratégie §2.2) |
| D8 | Base de M2 sur `lab-pg` (namespace `lab-pg`, Cluster `lab-pg`) au lieu de `pg-shared-homelab` ; label `platform.smadja.dev/pg-client` sur le namespace (NetworkPolicy `allow-pg-clients` de `lab-pg`) au lieu d'une CiliumNetworkPolicy dans le namespace de la base | `miniflux/`, `lab-pg/miniflux-database.yaml` | arbitrage de Paul |
| D9 | miniflux sans OIDC (pas d'Authentik sur le cluster du banc) | `miniflux/` | capacité absente |
| D10 | ntfy en mode stateless : pas de PVC, de cache, de base d'auth, d'initContainer ni d'ExternalSecret Doppler ; HTTPRoute sur `Gateway/internal` seulement | `ntfy/app.yaml` | arbitrage de Paul (M3 stateless) ; pas de Doppler sur le banc |
| D11 | Valeurs factices : 1 IP LAN → `<gateway-internal-vip>` ; 4 noms d'hôte → `*.example.invalid` (3 skills, `$id` du schéma `app-status.v1`, exemple du contrat) ; hôtes des apps → `ntfy.example.invalid`, `miniflux.example.invalid`, `echo-bench.example.invalid` (catalog-info) | 3 skills, 2 docs, apps | aucun hôte ni IP dans le bac à sable |
| D12 | `catalog-info.yaml` de echo-bench : cluster `oracle-a1` au lieu de `homelab` | `k8s/apps-generated/echo-bench/` | cluster du banc |

Résidus gardés à l'identique (copie fidèle) : le chart rend le nom d'hôte `<name>.<domaine public de kube-ops>` ;
`AGENTS.md` cite des URL publiques GitHub ; `k8s/CLAUDE.md` cite des noms de bucket ; `scripts/app-status.sh`
garde l'URL de kube-ops et `svc-<app>`. Aucun secret : `gitleaks dir` PASS (aucune fuite) sur l'arbre.

## 4. Conflits à arbitrer (BLOCKED, question à Paul)
1. **echo-bench hors `lab-k-*`.** Le chart inchangé code en dur `svc-<name>` (Namespace et tous les objets) et le
   nom d'hôte. Avec l'AppProject `lab-k` (destinations `lab-k-*`), Argo refusera la synchro de `svc-echo-bench`.
   Choix : (a) un paramètre de préfixe de namespace dans le chart (écart au chart) ; (b) admettre `svc-*` dans
   `lab-k` (écriture hors `lab-*`).
2. **miniflux et kinds Kustomize.** L'AppProject copié de `apps-generated` n'admet ni `ExternalSecret`, ni
   `SecretStore`, ni `Password` ; kube-ops les admet dans le projet `applications` (`*/*`). La base exige aussi
   d'écrire dans `lab-pg` (Database, Role, RoleBinding, Job, ExternalSecret) et d'ajouter un rôle géré au Cluster
   `lab-pg`, possédé par la plateforme. `lab-pg/miniflux-database.yaml` n'est livré par aucun ApplicationSet.
3. **M3 sans non-prod.** kube-ops n'a pas d'environnement non-prod pour une app Kustomize à ce SHA ; la tâche M3
   (non-prod puis prod) n'a pas d'équivalent direct dans le bras K.

## 5. Preuves
| Contrôle | Statut | Détail |
|---|---|---|
| `helm template` echo-bench (helm v4.1.3) | PASS (STATIC) | rc=0 ; Namespace, PDB, ServiceAccount, Service, Deployment, CiliumNetworkPolicy, HTTPRoute, tous dans `svc-echo-bench` |
| `helm template` miniflux (fixture kube-ops `miniflux-reprise.yaml`) | FAIL attendu | rc=1 : `capability database unavailable: pg-shared-homelab not reconciled` |
| `helm template` ntfy (sonde contrat v1) | rendu PASS, app NOT_PROVEN | rc=0, mais 0 ligne `args`/`command` ; `spec.runtime` n'admet que `replicas, size, port, healthPath, env` ; kube-ops passe `args: ["serve"]` |
| kubeconform (`-strict -ignore-missing-schemas`) | PASS (STATIC) | 29 ressources : 16 valides, 0 invalide, 13 ignorées (CRD sans schéma) |
| `kustomize build` ntfy, miniflux | NOT_TESTED | binaire absent de la session |
| Diff des 3 fichiers de livraison | PASS (STATIC) | seuls D1-D5 changent (diff unifié lu) |
| Poussée du commit initial | BLOCKED | `git` refusé dans le clone du bac à sable par l'isolation du worktree de la session ; écriture par l'API GitHub refusée par le proxy (HTTP 403). Le contenu est écrit dans le clone, sans commit |
| Accès de l'App de l'usine au bac à sable | NOT_PROVEN | dépôt privé lisible et inscriptible par l'identité de la session seulement |
| Applications du bras K rattachées à `lab-k` sur OKE | NOT_TESTED | l'AppProject `lab-k` n'apparaît pas dans la preuve de l'étape 11 de T-487 (projets listés : `lab-platform`, `lab-o`, `lab-authz`, `lab-root`) |
| Check run publié par Argo CD Notifications | NOT_TESTED | T-005, T-489 |
| `helm template` en CI du bac à sable | NOT_TESTED | aucun workflow copié |
