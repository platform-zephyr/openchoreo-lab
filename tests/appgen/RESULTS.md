# Résultats tests/appgen (exécutés le 2026-11-17, après les extensions E1-E3, E6-E9, E12 et Helm)

Tous ces résultats sont **statiques** : schéma, règles du générateur et kubeconform. Rien n'a été appliqué sur un cluster, ni k3d ni OKE. La CEL des CRD et des objets de plateforme n'est pas évaluée.

Environnement : macOS arm64, Python 3.12.1, PyYAML 6.0.2, jsonschema 4.23.0, kubeconform 0.7.0, yamllint (config `tools/appgen/yamllint.yaml`), shellcheck, gitleaks 8.30.0. CRD : `config/crd/bases` d'openchoreo v1.3.3. Schémas externes : datreeio/CRDs-catalog@`784ec895`, sha256 vérifié par `tools/appgen/fetch-ext-schemas.sh`.

| # | Contrôle | Commande | Résultat |
|---|---|---|---|
| 1 | Validation des apps du dépôt (6 apps + exemple Helm) | `python3 tools/appgen/appgen.py validate` | **PASS** (7) |
| 2 | Tests unitaires (103) | `APPGEN_CRDS=… APPGEN_EXT_SCHEMAS=… python3 -m unittest discover -s tests/appgen` | **102 PASS, 1 FAIL** (n° 5 ci-dessous) |
| 2b | Idem sans variables kubeconform | `python3 -m unittest discover -s tests/appgen` | 101 PASS, 1 SKIP (kubeconform), 1 FAIL (n° 5) |
| 3 | Rendu réel (`platform/` + `clusters/k3d`), déterministe | `render --out A`, `render --out B`, `diff -r A B` | **PASS** (48 fichiers, identiques) |
| 4 | kubeconform -strict, rendu réel des apps du dépôt, CRD v1.3.3 | `tools/appgen/validate-crd.sh <crd> <rendu>` | **PASS** 42/42 |
| 5 | Pas de dérive avec `generated/` commité | `python3 tools/appgen/appgen.py check` et test `GeneratedTreeNoDrift` | **FAIL** : `generated/` absent du dépôt. Le trait `persistent-volume-claim` existe désormais dans `platform/traits/`, donc le rendu passe. Il reste au coordinateur à lancer `render` puis à committer `generated/`. |
| 6 | kubeconform, rendu complet des extensions (native + aperçus + Helm) | test `Kubeconform` (exécuté) | **PASS** : 27/27 OpenChoreo, 8/8 NetworkPolicy, CiliumNetworkPolicy, Application, ExternalSecret, ResourceQuota |
| 6b | kubeconform, négatifs : `toFQDNs` renommé dans une CNP, `selfHeal: "oui"` dans une Application | `validate-crd.sh` après altération | **PASS** (les deux refusés, rc=1) |
| 7 | kubeconform, propositions plateforme (`fixtures/platform`, `fixtures/platform-ext`) | `kubeconform -strict` (schémas `crd2schema`) | **PASS** 8/8 (structure seulement) |
| 8 | Négatif kubeconform historique | `tests/appgen/kubeconform-negative.sh <crd>` | **PASS** |
| 9 | yamllint, shellcheck | `yamllint -c tools/appgen/yamllint.yaml tools tests/appgen clusters` ; `shellcheck tools/appgen/*.sh tests/appgen/*.sh` | **PASS** |
| 10 | gitleaks | `gitleaks dir tools tests/appgen clusters docs/schema` | **PASS** (aucune fuite) |

## Couverture des extensions (`test_extensions.py`, 69 tests)

Chaque refus a été vérifié : il touche la règle visée, pas un autre champ.

| Extension | Positifs | Négatifs (≥ 3) |
|---|---|---|
| E3 egress | alias inchangés ; CIDR public avec `except` auto ; FQDN, motif et CIDR privé admis → CNP + NP ; egress `app` → `dependencies.endpoints` + visibilité `namespace` ; flag non appliqué → aperçu `enforced=false` et règle non transmise | `0.0.0.0/0`, plage > /8, IMDS `169.254.169.254/32`, CIDR privé non admis, CIDR non canonique, sans ports, FQDN sans Cilium, `metadata.google.internal`, `*.com`, IP comme FQDN, `*.svc.cluster.local`, app inconnue, app elle-même, CPT sans paramètre → render refusé |
| E1 base | `pg-shared` admis par la politique → CRT de l'instance + `databaseNamespace`/`databaseCluster` | `pg-shared` sur k3d, instance inconnue, workload/job `database` sans base, `cnpg` sur instance non sauvegardée |
| E2 OIDC | Authentik + groupes + egress issuer → annotations catalogue | Authentik sur k3d, sans `allowedGroups`, `adminGroup` hors groupes, sans egress issuer, `OAUTH2_ADMIN_GROUP` divergent, issuer `http` |
| E6 workloads | worker + StatefulSet (CCT, visibilité `project`, base, secrets choisis) | `main`, doublon, secret non déclaré, sidecar, secret en clair, quota dépassé, CCT absente → render refusé |
| E7 jobs | CronJob (`Forbid`, `schedule` par environnement) | cron invalide, port, volume monté, base absente |
| E8 volumes | 3 volumes dont RWX en lecture seule, trait StatefulSet, quota `pvcs: 3` | RWX sur k3d, RWO avec 2 réplicas, doublon, volume sur un job |
| E9 sauvegarde | `velero` admis → annotation catalogue | `velero` sur k3d, sans volume, sans `retention`, `cnpg` sans instance sauvegardée |
| E12 exceptions | `writable-rootfs` → `readOnlyRootFilesystem: false` ; `run-as-root` → CCT d'exception + `podSecurity: baseline` de la cellule | expirée, > 90 jours, motif trop court, sans `expires`, workload inconnu, `run-as-root` + `runAsUser`, CCT absente → render refusé |
| Helm | Application multi-source, sans finalizer, `prune: false`, PSA `restricted`, `lab-*`, NP default-deny, catalogue `managed=false` | chart sans digest, version en plage, `values.yaml` absent, `hostNetwork: true`, Service `LoadBalancer`, exposition publique, `jobs` en Helm |

## Changements de rendu sur les apps existantes

Deux corrections assumées, absentes de `generated/` puisque rien n'y était commité :

- **Trait PVC.** Le paramètre `volumeName`, inconnu du trait upstream, n'est plus passé. Seul `mountPath` l'est, plus `accessMode` et `readOnly` si nécessaire. Le générateur refuse désormais tout paramètre non déclaré par une CCT, un trait ou le CPT.
- **Quota de cellule.** Les apps avec volume (aiostreams, open-connector) reçoivent `quota: {cpu: 300m, memory: 512Mi, pvcs: "1"}`. Le défaut du CPT, `pvcs: "0"`, aurait refusé leur PVC à l'admission.

## Non prouvé ou bloquant

- **[S] Runtime.** Aucune NetworkPolicy, CNP, CronJob, StatefulSet ni Application rendue n'a été appliquée. k3d n'a pas Cilium : l'egress FQDN y reste NOT_TESTED. Les preuves runtime restent à produire (k3d, puis OKE après le gate).
- **[S] Aperçu et CEL.** L'équivalence entre les aperçus `previews/` (Python) et la CEL proposée du CPT n'est pas prouvée. Il faut un `kubectl apply --dry-run=server` puis un rendu réel sur k3d.
- **BLOQUANT pour les extensions (platform/).** CPT étendu, CCT `worker`, `statefulset`, `cronjob` et `service-root-exception`, trait `persistent-volume-claim-sts` : propositions dans `fixtures/platform-ext/`. Sans eux, `render` échoue volontairement pour toute app qui les utilise. Aucune app du dépôt ne les utilise aujourd'hui.
- **CI.** Les jobs GitHub n'ont pas été exécutés.
