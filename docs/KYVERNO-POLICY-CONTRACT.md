# Contrat policy-as-code Kyverno (PSA + VAP natives + Kyverno)

> 2026-11-17. Décision de Paul : Kyverno est une primitive OBLIGATOIRE, en complément sans doublon de la PSA et des VAP natives. Cible : OKE (1 nœud arm64, 1830m / 8,4 GiB), puis Talos.
> Statut des preuves : `kyverno test` **PASS** (97/97, CLI v1.19.2, 2026-11-17). API server et « Kyverno indisponible » : **NOT_TESTED**, faute de cluster libre (VM colima saturée, consigne de Paul). Le script est prêt, non exécuté : `tests/kyverno/run-apiserver.sh`. Rien n'est déployé, ni sur OKE ni ailleurs.

## 1. Matrice d'ownership

Principe : **une règle et une cible = un seul propriétaire qui refuse**. Les protections critiques restent **natives** (PSA, VAP) et tiennent sans webhook. Kyverno prend :
- les validations supplémentaires ;
- les règles qui ont besoin d'état (lecture d'objets, horloge) ;
- les exceptions contrôlées ;
- les rapports.

Quand deux mécanismes visent le même risque, ils visent des **cibles différentes**, ou l'un est un filet de coût. La raison est écrite dans chaque cas.

| Règle | PSA (namespaces du lab) | VAP natives (sans webhook) | Kyverno | Pourquoi ce partage |
|---|---|---|---|---|
| Pod restricted (runAsNonRoot, pas d'escalade, drop ALL, seccomp, volumes) | **Propriétaire** sur les Pods | — | **K-01** `lab-workload-restricted` (Deny) sur les **gabarits** des contrôleurs | La PSA ne fait qu'avertir sur un Deployment : l'objet est admis, puis le ReplicaSet échoue en silence. K-01 refuse au moment du sync Argo/Helm. Les Pods ne sont pas visés (pas d'autogen). K-01 suit le niveau PSA du namespace (`baseline` : non contrôlé). |
| privileged, hostNetwork/PID/IPC, hostPath, hostPort | **Propriétaire** sur les Pods | **Propriétaire** : `lab-cell-pod-hardening` (Pods dp-*, lab-pg) ; `baseline-pod-hardening` de kube-ops (contrôleurs et Pods, tous namespaces sauf kube-system et cloudflared) | **K-02** `lab-host-isolation-report` : **Audit seul** | Ce sont des garde-fous critiques, qui doivent tenir sans Kyverno. Kyverno ne fait que les rapporter. Sur Talos, `baseline-pod-hardening` doit être portée telle quelle (VAP native). |
| Image épinglée par digest | — | **Propriétaire** sur les Pods dp-* et lab-pg (`lab-cell-pod-hardening`) | **K-03** `lab-image-digest` (Deny) sur les contrôleurs de dp-*, lab-*, openchoreo-* | Autre cible (gabarit) et périmètre plus large (charts du lab, composants OpenChoreo) que la VAP ne couvre pas. La VAP kube-ops `baseline-image-digest` (Warn, sur auth/backstage/hindsight) est hors lab. |
| Service LoadBalancer / NodePort / externalIPs | — | — | **K-04** `lab-service-exposure` (Deny, exception possible) | Kyverno porte la règle : message clair, exception gouvernée, rapport. Le quota `services.loadbalancers=0` et `nodeports=0` reste un **filet de coût** natif (un LB OCI est facturé). Ce n'est pas un second propriétaire : pas de message de sécurité, pas d'exception possible. |
| requests/limits et quota | — | — | **K-05** `lab-workload-resources` (Deny) : requests cpu/mem et limit mem sur le gabarit, ResourceQuota présent dans le namespace | Le LimitRange ne s'applique qu'aux Pods. Les valeurs du quota restent natives (`01-quotas.yaml`, CPT). Kyverno vérifie seulement leur présence (`resource.List`). |
| Ressources cluster-scoped créées par une application | — | **Propriétaire par identité** : `lab-cluster-agent-scope` R1 (SA dp-*, cluster-agent) | **K-06** `lab-cluster-scoped-provenance` (Deny) : par **provenance** (tracking-id Argo d'une Application non plateforme, label `openchoreo.dev/component`, release Helm de cellule) | Argo applique tout avec un seul SA (REVIEW-PR8 P1). L'identité ne distingue donc pas une app de la plateforme, la provenance si. Un objet sans marque reste à la charge du RBAC, de l'AppProject et d'`argo_guard.py`. |
| Namespaces du lab et objets de sécurité (PSA des namespaces, default-deny, quotas, LimitRange) | — | **Propriétaire pour l'agent** : `lab-cluster-agent-scope` R3 | **K-07** `lab-security-objects-guard` (Deny) pour toutes les autres identités | Les leçons I6 et A2 : une PR ou un humain pouvait abaisser la PSA. K-07 couvre `namespaces/status` (cas V1-N13). Les VAP et les webhooks échappent à toute admission : RBAC, CI et `argo_guard` restent leurs seuls gardiens. |
| Egress déclaré : label `platform.smadja.dev/egress-isolated` | — | — | **K-08** `lab-egress-declared` (Deny, lab-* et openchoreo-*) + **K-09** `lab-egress-report` (Audit : cellules dp-*, NetworkPolicy Egress par défaut) | Aucun mécanisme natif ne porte ce label (C1). Pour dp-*, l'action est Audit tant que le CPT ne pose pas le label (§9). L'isolation effective reste aux NetworkPolicy/CCNP (Cilium). |
| Suppression de données persistantes (PVC, PV, Cluster CNPG, namespace contenant des PVC) | — | — (une VAP n'a pas d'horloge) | **K-10** `lab-protect-persistent-data` (Deny, **Fail**, DELETE seulement) + **K-12** `lab-delete-approval-window` (Ignore, validité de l'annotation à l'écriture) | Scénarios I4 et P3 : un prune ou un selfHeal Argo, ou un uninstall, recrée un volume de 50 Go. |
| Gouvernance des exceptions | — | — | **K-11** `lab-policy-exception-governance` (Deny, **Fail**) | Une exception non gouvernée, admise pendant une panne, s'appliquerait au redémarrage. |
| Contrat applicatif (capacités autorisées) | — | — | — | Propriétaire : golden path (`docs/APP-CONTRACT.md`, `tools/appgen`, CI). Kyverno contrôle ce qui est **effectivement soumis** à Kubernetes (rendu OpenChoreo, charts Helm et Argo), pas l'intention. |

**Non retenus, avec raison :**
- `MutatingPolicy` / `GeneratingPolicy` : aucune. Argo CD est le seul écrivain (une mutation crée une dérive selfHeal). La génération (default-deny, quota) a déjà un propriétaire (install/, CPT). Elle exigerait le background-controller, soit un pod de plus.
- Génération de VAP par Kyverno : désactivée. Les VAP critiques restent écrites et testées à la main (`platform/policies`, `tests/vap`). Le générateur a contourné les exceptions jusqu'en 1.19.1 (GHSA-qc9c-3fgf-cgq8).
- ClusterPolicy legacy : aucune. Kyverno 1.20 bloque déjà leur création.

## 2. Version retenue et types CEL

- **Kyverno v1.19.2** (2026-10-20), chart `kyverno` **3.9.2**, sha256 `f6fe7184…861e`. C'est la seule version que les 24 GHSA publiées (9 critiques) donnent comme corrigée, d'après la liste des avis du dépôt.
  - v1.20.0 est « Latest » mais n'a que 5 jours. C'est une version .0, elle bloque les politiques legacy, et aucun avis ne la donne encore comme corrigée. On y passera par PR après vérification.
  - Versions, sha256 et digests : `platform/kyverno/install/versions.env`.
- **arm64** : CLI `linux_arm64` et `darwin_arm64` publiés dans `checksums.txt`. Les images `kyverno`, `kyvernopre`, `reports-controller` et `readiness-checker` sont des index multi-arch avec arm64 (vérifié sur ghcr.io le 2026-11-17).
- **API `policies.kyverno.io/v1`** : servie par les CRD de v1.19.2 (v1alpha1, v1beta1 et v1 servies ; stockage v1beta1). Les types CEL sont **GA** :
  - `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy` ;
  - `PolicyException` (CEL), avec `spec.expiresAt` natif. Depuis 1.19 (#16299), une exception expirée est ignorée.
- **`kyverno test`** prend en charge `isValidatingPolicy`, les `operation` CREATE, UPDATE et DELETE, `userinfo`, `values.namespaces` (`namespaceObject`), les `clusterResources` (lus par `resource.List`) et les `exceptions`. Tout cela a été vérifié à l'exécution.
- **Limite du CLI** : en UPDATE, `oldObject` est identique à `object`. La « baisse PSA » de K-07 ne se teste donc que sur un API server (cas `K07-psa` du script).
- Bibliothèques CEL de Kyverno utilisées : `resource.List` (K-05, K-09, K-10) et `time.now()` (K-10, K-11, K-12).

## 3. Indisponibilité de Kyverno : décision par règle

Dispositions communes :
- le webhook global exclut `kube-system`, `kube-public`, `kube-node-lease` et `lab-kyverno` (`install/values.yaml`) ;
- chaque politique ajoute une condition de périmètre par **nom** de namespace (`dp-*`, `lab-*`, `openchoreo-*`) ;
- un objet en cours de suppression n'est jamais bloqué ;
- `forceFailurePolicyIgnore=false`.

| Politique | failurePolicy | Kyverno arrêté : ce qui tient encore | Bloque quoi pendant la panne |
|---|---|---|---|
| K-01, K-03, K-05 | Ignore | PSA (Pods), `lab-cell-pod-hardening`, quota et LimitRange | rien |
| K-02, K-09 (Audit) | Ignore | PSA et VAP (refus réels) | rien (rapports en pause) |
| K-04 | Ignore | quota LB/NodePort = 0 (« exceeded quota ») ; externalIPs non couvert | rien |
| K-06 | Ignore | VAP-1 R1, RBAC, AppProject | rien |
| K-07, K-08 | Ignore | VAP-1 R3 (agent), RBAC, selfHeal Argo | rien |
| K-12 | Ignore | — (K-10 revalide la fenêtre au DELETE) | rien |
| **K-10** | **Fail** | — | **DELETE** de PVC, PV, Cluster CNPG et namespace du périmètre : opération destructive, rare, différable |
| **K-11** | **Fail** | — | création et modification de PolicyException |

Break-glass (cluster-admin, tracé) : `kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg`. Kyverno le recrée à son redémarrage. Le geste est réservé à une panne prolongée qui bloque une suppression urgente.

## 4. Exceptions et suppressions approuvées

**Exception** : une `PolicyException` (`policies.kyverno.io/v1`) placée dans le namespace `lab-policy-exceptions`. C'est le seul namespace lu par Kyverno (`--exceptionNamespace`). L'objet porte :

```yaml
metadata:
  annotations:
    platform.smadja.dev/reason: "≥ 20 caractères"
    platform.smadja.dev/approver: "user:default/paul"
    platform.smadja.dev/approved-at: "2026-11-17T10:00:00Z"
spec:
  expiresAt: "2027-01-31T00:00:00Z"
  policyRefs: [{name: lab-image-digest, kind: ValidatingPolicy}]
  matchConditions: [{name: one-app, expression: "object.metadata.namespace == 'dp-legacy'"}]
```

K-11 refuse l'exception dans chacun de ces cas :
- elle est hors de `lab-policy-exceptions` ;
- `expiresAt` manque, est passé, ou tombe plus de 90 jours après `approved-at` ;
- `approved-at` est dans le futur ;
- elle vise une politique non exceptionable (K-02, K-07 à K-12) ;
- elle n'a pas de `matchConditions`.

Exceptionables : K-01, K-03, K-04, K-05, K-06 (annotation `platform.smadja.dev/exceptionable` de chaque politique). On révise une exception par PR. À l'échéance, Kyverno l'ignore.

**Suppression de données** : `kubectl annotate pvc <x> platform.smadja.dev/delete-approved-until=$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)`, puis `kubectl delete`. La fenêtre fait 24 h au plus et doit être dans le futur. Elle vaut aussi pour un admin. La purge par le namespace-controller et le garbage-collector, ainsi que les PV supprimés par les contrôleurs de kube-system, sont exemptés.

## 5. Rapports exploitables par un agent

Le reports-controller agrège les `PolicyReport` (`wgpolicyk8s.io`) : un par namespace, plus des `ClusterPolicyReport`. Pour la conformité par namespace :

```bash
kubectl get policyreports.wgpolicyk8s.io -A -o json | jq -r '
  [.items[] | {ns: .metadata.namespace, pass: (.summary.pass // 0), fail: (.summary.fail // 0)}]
  | group_by(.ns) | map({ns: .[0].ns, pass: (map(.pass)|add), fail: (map(.fail)|add)})[]
  | "\(.ns)\tpass=\(.pass)\tfail=\(.fail)"'
```

Pour la conformité par application (label OpenChoreo `openchoreo.dev/component` de la ressource) :

```bash
kubectl get policyreports.wgpolicyk8s.io -A -o json | jq -r '
  .items[] | . as $r | .results[]? | select(.result == "fail")
  | [$r.metadata.namespace, ($r.scope.name // "-"), .policy, .message] | @tsv'
```

[NON VÉRIFIÉ sur API server] La forme exacte des rapports de v1.19.2 (`wgpolicyk8s.io` par défaut, `openreports.io` si `openreports.enabled`) doit être capturée par `run-apiserver.sh` §3, qui écrit `policyreports.json` dans les preuves.

## 6. CI : bloc prêt à intégrer

Je n'ai pas modifié `.github/workflows/ci.yaml` : l'agent A2 l'édite en ce moment. Voici le bloc à intégrer.

```yaml
# env (en tête du workflow) :
  # Kyverno CLI v1.19.2 linux-arm64 : sha256 de checksums.txt de la release GitHub kyverno/kyverno v1.19.2
  # (platform/kyverno/install/versions.env), relevé le 2026-11-17.
  KYVERNO_VERSION: "1.19.2"
  KYVERNO_CLI_SHA256: "250f2a02f143d5c6425e686b13c130d3a3ba7372dba6a7210d599d1b0dd12e92"

# job :
  kyverno:
    # Politiques Kyverno (platform/kyverno/policies) : kyverno test, cas positifs ET négatifs par politique,
    # cohérence politique <-> tests. Aucun cluster, aucun secret. docs/KYVERNO-POLICY-CONTRACT.md.
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0
        with:
          python-version: "3.12"
      - name: Installer kyverno CLI (archive vérifiée par sha256, hors PATH global)
        run: |
          cd "$RUNNER_TEMP"
          curl -fsSLO "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_linux_arm64.tar.gz"
          echo "${KYVERNO_CLI_SHA256}  kyverno-cli_v${KYVERNO_VERSION}_linux_arm64.tar.gz" | sha256sum -c -
          tar -xzf "kyverno-cli_v${KYVERNO_VERSION}_linux_arm64.tar.gz" kyverno
      - name: yamllint platform/kyverno et tests/kyverno
        run: |
          python3 -m pip install --disable-pip-version-check "yamllint==1.38.0"
          yamllint -c tools/appgen/yamllint.yaml platform/kyverno tests/kyverno
      - name: shellcheck
        run: shellcheck -x tests/kyverno/run.sh tests/kyverno/run-apiserver.sh
      - name: kyverno test
        run: tests/kyverno/run.sh "$RUNNER_TEMP/kyverno"

# ci-ok : ajouter `kyverno` à needs.
```

Les actions sont épinglées par SHA (les mêmes que dans le workflow) et le binaire par sha256. `run.sh` ne modifie jamais le dépôt : il travaille sur une copie temporaire, où les dates relatives `@@T±N[hd]@@` sont rendues. Il vérifie aussi deux choses :
- chaque politique référence `tests/kyverno/<nom>` ;
- ce dossier contient au moins un cas `pass` et un cas `fail`.

Contrôle manuel fait le 2026-11-17, hors `run.sh` : une version affaiblie de K-03 fait bien échouer 3 tests. Les tests ne passent donc pas à vide.

## 7. Preuves

| Preuve | Statut | Détail |
|---|---|---|
| `kyverno test` (CLI v1.19.2 darwin-arm64, sha256 vérifié) | **PASS** 2026-11-17 | 97 cas sur 12 politiques. Chaque politique a des témoins `pass` et des refus `fail`, plus des `skip` hors périmètre. Exception CEL appliquée (K-04). Identités `--as` simulées : app, admin, cluster-agent, namespace-controller. |
| Non-conflit avec l'existant (`kyverno apply`) | **PASS** 2026-11-17 | Manifests appliqués : `00-namespaces.yaml`, `lab-pg-namespace.yaml`, `install/namespaces.yaml` et `12-gateway-parameters.yaml`. Résultat : 0 fail, 0 erreur. `argo_guard.py .` : 0 écart. Le chart Kyverno rendu (`helm template`) est entièrement épinglé par digest, PSA restricted. |
| Refus et témoins sur API server (k3d `lab-sec-kyv`) | **NOT_TESTED** | Pas de cluster libre (VM colima saturée, ~1,75 GiB disponibles, consigne de Paul). Script prêt : `tests/kyverno/run-apiserver.sh` §2. |
| PolicyReport et requête jq | **NOT_TESTED** | Même cause. `run-apiserver.sh` §3. |
| Kyverno indisponible (admission à 0 réplica) | **NOT_TESTED** | Même cause. `run-apiserver.sh` §5, résultat attendu : privileged, root et tag refusés par PSA/VAP ; LB refusé par quota ; DELETE PVC et PolicyException refusés (Fail) ; Deployment non conforme, namespace et kube-system admis (Ignore, cluster non bloqué). |
| Propagation des `matchConditions` vers la configuration de webhook | **[S] NOT_TESTED** | À lire dans `webhooks.json` (§1 du script). Sans propagation, K-12 est appelée pour toute écriture de PVC ou de namespace : c'est sans danger (Ignore), mais cela coûte un appel. |

Garde-fous de `run-apiserver.sh` :
- `KUBECONFIG` explicite et dédié ;
- contexte exactement `k3d-lab-sec-kyv`, serveur local ;
- refus de oke, openchoreo, lab-sec-a1, lab-sec-argo et lab-sec-vap ;
- avec `--create`, création seulement si la VM a au moins 2560 MiB libres.

## 8. Empreinte

[NON MESURÉ] Aucun cluster disponible. Valeurs **déclarées** (requests et limites des values, défauts du chart 3.9.2) et projection :

| Contrôleur | Pods | Requests | Limite mémoire | Défaut du chart |
|---|---|---|---|---|
| admission-controller (+ init kyvernopre) | 1 | 50m / 128Mi | 384Mi | 100m / 128Mi, 384Mi |
| reports-controller | 1 | 20m / 64Mi | 256Mi | 100m / 64Mi, 128Mi |
| background, cleanup | 0 | — | — | (désactivés) |
| **Total** | **2 pods, 4 images arm64** | **70m / 192Mi** | **640Mi** | |

Projection sur OKE (1830m / 8,4 GiB alloués) :
- requests : 3,8 % du CPU et 2,2 % de la mémoire ;
- pire cas en limites : 7,4 % de la mémoire.

La documentation publie seulement des latences (benchmarks v1.18.1 : p99 inférieur à 1 s jusqu'à 500 VU avec 1 réplica, hors cas extrêmes), pas d'empreinte au repos. La mesure réelle reste à faire avec `run-apiserver.sh` §4 (`kubectl top`), avant toute installation sur OKE.

## 9. Actions hors de ce périmètre (à faire par leurs propriétaires)

1. **CPT `cell-restricted`** (`platform/project-types`) : ajouter la constante `"platform.smadja.dev/egress-isolated": "true"`, puis passer `dp-*` de K-09 (Audit) à K-08 (Deny).
2. **CI** (`.github/workflows/ci.yaml`, agent A2) : intégrer le bloc du §6.
3. **GitOps** : une Application `lab-kyverno` (projet plateforme) pour `platform/kyverno/**`, déjà reconnue comme plateforme par K-06 et K-07. Ordre : namespaces, puis chart, puis politiques. `argo_guard.py` devra réserver `policies.kyverno.io/*` à ce projet. Les apps (`apps/`, `generated/`) n'y ont jamais accès.
4. **Talos** : porter la VAP `baseline-pod-hardening` de kube-ops. C'est elle qui détient le refus de privileged et host* sur les contrôleurs. K-02 ne fait que rapporter.
5. **OKE** [S] : vérifier les identités plateforme réelles (utilisateurs IAM cluster-admin ≠ `system:masters`). Ajuster la variable `isPlatform` de K-07 par PR.
