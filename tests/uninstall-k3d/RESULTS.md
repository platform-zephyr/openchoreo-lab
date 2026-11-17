# Résultats désinstallation — **k3d** `k3d-lab-sec-vap` (pas OKE)

- **Date** : 2026-11-17, 20:10-20:35 UTC. API server Kubernetes v1.35.5+k3s1, Helm **v4.1.3** (poste). Cluster jetable,
  supprimé à la fin.
- **Méthode** : `tests/uninstall-k3d/run.sh`. `tools/oke/uninstall.sh` et `install.sh` sont exécutés **pour de vrai**
  (`--apply`) en MODE TEST (`LAB_TEST_CLUSTER=k3d-lab-sec-vap`, `OKE_PHASEB_STATE` dédié hors de l'état réel).
  Charts **exacts** de `versions.env`, sha256 vérifiés : cert-manager v1.19.4, external-secrets 2.0.1,
  kgateway-crds et kgateway v2.3.11, argo-cd 10.3.3 (`lab-argocd`), Gateway API v1.5.1. Values du labo.
- **Limite d'environnement (importante)** : le kubelet k3s ne démarre pas (VM colima partagée, limite
  `fs.inotify.max_user_instances=128`). Un objet **Node factice**, tainté `NoSchedule`, porte le nom attendu par la
  garde de test. Conséquences :
  - aucun pod ne tourne, aucun contrôleur ni webhook n'est actif ;
  - étapes 3 à 5 installées par `helm upgrade --install` (mêmes tgz, values et namespaces), **sans `--wait`** et sans
    `budget_gate` ;
  - Argo CD installé avec `--no-hooks` ;
  - `ext-user` étiqueté `cert-manager.io/disable-validation=true`, le webhook cert-manager n'ayant pas de pod.

  Les effets d'API (Helm, CRD, finalizers, gardes) sont réels. Le comportement des contrôleurs (selfHeal d'Argo,
  cascade de `resources-finalizer`) n'est pas testé : NOT_TESTED.
- **Preuves** : `tests/uninstall-k3d/evidence/<id>.txt` (commande, sortie, rc, verdict), `results.tsv`,
  `00-storage-before/after.txt`, `R1-orphelins-avant-garde.log`.

## Bilan : 59 PASS, 0 FAIL (après 4 correctifs d'`uninstall.sh` révélés par le banc)

## Effets de `helm uninstall` par chart (objets VIVANTS, H-* et R*)

| Chart | CRD : emplacement | `keep` sur l'objet vivant | Effet observé de l'uninstall |
|---|---|---|---|
| cert-manager v1.19.4 | 6, `templates/` | oui, 6/6 (`crds.keep`) | release supprimée, **6 CRD gardées** (R3a). Supprimées par `rm_crds` seulement avec `--delete-crds` et sans usage hors essai (R3b), y compris `acme.cert-manager.io`, par nom de rendu |
| external-secrets 2.0.1 | 23, `templates/crds/` (pas de `crds/`) | oui, 23/23 (`crds.annotations`) | release supprimée, **23 CRD gardées** (R4a). Release passée sans `keep` : refus (K01) |
| kgateway-crds v2.3.11 | 8, `templates/` | **non** (0/8) | `helm uninstall` **SUPPRIME les 8 CRD et leurs CR**, dont la `GatewayParameters` d'essai (R5b). `helm --wait` (Helm 4) rapporte une ERREUR pendant le `Terminating` des CRD, alors que la release est bien supprimée |
| kgateway v2.3.11 | aucune | — | Deployment et RBAC supprimés (R5a) |
| argo-cd 10.3.3 | 3, `templates/crds/` | oui, 3/3 (`crds.keep`) | release supprimée, **3 CRD gardées** (R11), Applications restantes orphelines. Hooks `pre-install` (`argocd-redis-secret-init` : SA, Role, RoleBinding, Job, `before-hook-creation`) hors release : ils resteraient. Rendu statique seulement (installé `--no-hooks`), NOT_TESTED en runtime |
| openchoreo-control-plane 1.3.3 | 36, `crds/` | sans objet | Helm ne supprime **jamais** les CRD de `crds/` (pas installé ici ; rendu seulement) |

Finalizers et CR vivantes :
- une `ExternalSecret` à finalizer hors essai laisse la CRD en `Terminating` (« CustomResource deletion is in
  progress ») tant que le finalizer reste (R4b). La CRD disparaît dès qu'on le retire (R4c) ;
- une Application à `resources-finalizer.argocd.argoproj.io` reste `Terminating` sans contrôleur Argo (R11c). Il
  faut retirer le finalizer à la main (R11d).

## Gardes d'`uninstall.sh` et de `lib.sh`

| Id | Scénario | Résultat |
|---|---|---|
| G01-G07 | mode test : autre nom de cluster, contexte renommé, serveur `:16443`, sans `OKE_PHASEB_STATE`, chemin `oke-access`, sans `LAB_TEST_CLUSTER` (garde OKE d'origine) | tous refusés ; accepté seulement sur `k3d-lab-sec-vap` (G07) |
| A-1, A-7, A-9, A-10 | `--step N --apply` avec des Applications dans `lab-argocd` | refusé, rien n'est supprimé (A-ns) |
| R11b | après `--step 11`, une Application non nommée par `undo_11` reste | garde Argo toujours active (échec fermé) |
| K01-K02 | release ESO sans `keep` | refusée, release intacte ; `keep` rétabli |
| R5a / R4a / R3a / R2a | CRD utilisées hors essai (TrafficPolicy, ExternalSecret, Issuer, GatewayClass) | CRD conservées ; P2 prouvé pour `gateway.kgateway.dev` |
| R5b / R3b / R4d | plus d'usage hors essai | CRD supprimées par nom de rendu |
| M01-M08 | `--migrate-cnpg-system` : ConfigMap étranger, ConfigMap étiqueté, PVC, sans label, release Helm | tous refusés ; supprimé seulement s'il est vide et étiqueté (ResourceQuota d'étape 1 toléré), idempotent |
| R1g | `--step 1` alors que des releases Helm restent | refusé |
| P01, P02, F02 | PVC témoin (`lab-pvc-witness`) et PV : empreinte uid avant/après chaque étape et après `--all` | identiques : aucune création ni suppression |
| R12→R1, ALL | rollback étape par étape, puis `--all --apply --delete-crds` sur une installation 1-5 + Argo | sans erreur. F01/F02 : 0 objet cluster-scoped orphelin |

## Défauts trouvés en runtime et corrigés (`tools/oke/uninstall.sh`)

1. **`helm list -a` n'existe plus en Helm 4** (« unknown shorthand flag: 'a' »).
   - `helm_rm` mourait : aucun rollback possible.
   - Dans `migrate_cnpg_system`, l'erreur était lue comme « aucune release » : **échec OUVERT**.
   - Correctif : `helm_releases` (filtres de statut combinés, valables en Helm 3 et 4).
   - Preuve : M07 refuse une release dont le seul objet est d'un kind toléré.
2. **`--all` cassait sur une installation partielle**. C'est l'état réel d'OKE (étapes 1-5) : `undo_10` mourait sur
   « no matches for kind Cluster » (CNPG), puis `undo_9` et `undo_8` (`openchoreo.dev`).
   - Correctif : `kd` ne tolère que l'erreur « kind non servi » ; toute autre erreur provoque un abandon.
   - Preuve : ALL.
3. **`--step 1` sans garde de releases** : le namespace était supprimé avec le Secret de la release. Restaient
   orphelins ClusterRole, ClusterRoleBinding, `Validating/MutatingWebhookConfiguration` cert-manager (avec
   `failurePolicy: Fail`, donc toute écriture `cert-manager.io` du cluster cassée) et CRD.
   - Preuve : `R1-orphelins-avant-garde.log`, 83 objets.
   - Correctif : refus tant qu'une release reste (R1g).
4. **`undo_5`** : `helm uninstall kgateway-crds --wait` échouait sur le `Terminating` des CRD.
   - Correctif : uninstall sans `--wait`, puis `kubectl wait --for=delete` sur les CRD nommées par le rendu.
5. **`migrate_cnpg_system`** acceptait tout objet étiqueté `part-of`.
   - Correctif : seuls les kinds posés par l'étape 1 sont tolérés (ResourceQuota, LimitRange, NP, CNP).
   - Preuve : M02.

## NOT_TESTED

- selfHeal d'Argo (recréation d'un objet supprimé) et cascade du `resources-finalizer` : pas de contrôleur.
- Orphelins des hooks Argo (`argocd-redis-secret-init`) : rendu statique seulement.
- `install.sh --from 3 --to 5` avec `budget_gate` : pas de nœud, donc pas d'API summary du kubelet.
- `undo_6`, `undo_6b`, `undo_7`, `undo_9`, `undo_10` avec leurs objets réellement installés (CP, DP, CNPG non
  installés) : seul le chemin « rien à annuler » est prouvé.
