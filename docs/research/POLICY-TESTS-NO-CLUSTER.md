# Tests de politiques sans cluster (spike T-463, SL-9)

> 2026-11-18, VM cloud x86_64, 4 vCPU, aucun cluster, aucun Docker utilisé. Issu de `SHIFT-LEFT-DEV-ENV.md` §5 (SL-9).

## 1. Verdict

**PASS.** `kyverno test` (CLI v1.19.2, la version épinglée) exécute sans cluster :

- les **97 cas** de `tests/kyverno` (12 politiques Kyverno `ValidatingPolicy`) en **2,6 à 3,0 s** (3 passages, `tests/kyverno/run.sh` compris) ;
- les **VAP natives** de `platform/policies/` (`ValidatingAdmissionPolicy`), y compris `matchConditions` sur `request.namespace` et `request.userInfo`, avec 19 cas de prototype en **0,55 à 0,61 s**.

Pas d'outil à ajouter : le CLI déjà épinglé couvre les deux. `conftest` est écarté (§5). Rien n'est branché dans la CI ni dans `tools/dev/check` (hors périmètre du ticket).

Deux constats à traiter par ticket :

1. **`tests/kyverno/run.sh` échoue par intermittence avec le CLI v1.19.2** : `"$kyv" version | head -1` sous `set -o pipefail`. `kyverno version` écrit 3 lignes ; `head -1` ferme le tube et le CLI sort en 141 (SIGPIPE). Constaté 3 fois sur 3 ici (rc=141 en 0,05 s, avant tout test) ; `kyverno version | head -1` donne `PIPESTATUS=141`. Correctif : `"$kyv" version >/dev/null` (ou `| sed -n 1p`). Le prototype `run.sh` l'applique. L'effet dépend de la course entre `head` et le CLI : la CI peut passer par chance.
2. Les cas **sous-ressource, CONNECT, `oldObject`** des VAP ne sont pas rejouables sans API server (§3).

## 2. Mesures

| Mesure | Résultat | Preuve |
|---|---|---|
| Binaire `kyverno-cli_v1.19.2_linux_x86_64.tar.gz` | 53,5 Mo ; sha256 `357eaf1d…bf4a` = `KYVERNO_CLI_LINUX_AMD64_SHA256` de `platform/kyverno/install/versions.env` | `sha256sum`, 2026-11-18 |
| `tests/kyverno/run.sh` (avec un enrobage de `version`) | rc=0, `97 tests passed and 0 tests failed`, 2,70 s / 3,04 s / 2,63 s | 3 passages |
| `tests/kyverno/run.sh` sans enrobage | rc=141, 0,05 s | 3 passages |
| Prototype VAP `docs/research/policy-tests-no-cluster/run.sh` | rc=0, `19 tests passed and 0 tests failed`, 0,55 / 0,56 / 0,61 s | 3 passages |
| Contrôle négatif | la règle `hostPath` de `lab-cell-pod-hardening` remplacée par `true` dans une copie : `Want fail, got pass` sur `lab-pg/bad-hostpath`, `6 passed 1 failed`, rc=1 | copie hors dépôt |

Comparaison : `tests/vap/run.sh` (92 cas) prend 29 s à 4 min 48 s en CI et exige un k3d (`K3D-REACTIVATION.md` §2.1).

## 3. Cas exécutables sans cluster

### 3.1 `tests/kyverno` : tous, 97 cas

| Politique | Cas |
|---|---|
| `lab-cluster-scoped-provenance` | 5 |
| `lab-delete-approval-window` | 6 |
| `lab-egress-declared` | 7 |
| `lab-egress-report` | 5 |
| `lab-host-isolation-report` | 5 |
| `lab-image-digest` | 5 |
| `lab-policy-exception-governance` | 9 |
| `lab-protect-persistent-data` | 14 |
| `lab-security-objects-guard` | 21 |
| `lab-service-exposure` | 7 |
| `lab-workload-resources` | 4 |
| `lab-workload-restricted` | 9 |

Non exécutable sans cluster : `tests/kyverno/run-apiserver.sh` (refus par requêtes réelles, PolicyReport, « Kyverno indisponible », empreinte). `NOT_TESTED` : il exige un k3d.

### 3.2 VAP natives (`tests/vap`, 89 cas `t`/`ti`) : ce qu'un rejeu sans cluster couvre

Prototype : `docs/research/policy-tests-no-cluster/` (3 dossiers, 19 cas, politiques lues dans `platform/policies/` sans copie).

| Capacité | Preuve | Verdict |
|---|---|---|
| Corps d'objet (digest d'image, privileged, hostPath, hostNetwork, initContainers) | `vap-cell-pod-hardening` : 7 cas | PASS |
| `matchConditions` sur le namespace (hors `dp-*` : `skip`, message « match conditions aren't met ») | idem, cas `hostnet-outside-scope` | PASS |
| Identité (`userinfo`) : agent et SA applicatif, R1, R2, R2b, R3 (PSA), R4 (RoleBinding), R5 (Role) | `vap-cluster-agent-scope-agent` 9 cas, `-app` 3 cas | PASS |
| Sous-ressources (`pods/exec`, `status`, `finalize`, `ephemeralcontainers`), CONNECT | aucun champ du test ne fixe `request.subResource` ni l'opération CONNECT | NOT_TESTED, probablement impossible |
| UPDATE avec `oldObject` (R3 « pas de baisse restricted → baseline », `oldNsLabels`) | non essayé | NOT_TESTED |
| `failurePolicy`, type-check CEL par l'API server, `validationActions: Deny,Audit`, journal d'audit | propres à l'API server | hors portée |
| Baseline OKE exportée (14 cas `B-*`) | politiques de kube-ops, absentes de ce dépôt | hors portée |

Estimation (H, non mesurée) : environ 55 des 89 cas de `tests/vap` (les DENY et ALLOW sur corps d'objet et identité des 64 cas `V1-*` et 11 cas `V2-*`) se transposent ; les cas `V1-C*`, `V1-N13/N14` (sous-ressources) et `B-*` restent sur k3d. `tests/vap` reste l'autorité pour la CEL réelle (10 FAIL avant correctif, dont un contournement PSA, ne se voyaient qu'avec l'API server).

## 4. Recommandation (ticket suivant, REVUE)

1. Corriger le SIGPIPE de `tests/kyverno/run.sh` (une ligne).
2. Faire exécuter `docs/research/policy-tests-no-cluster/` par `tests/kyverno/run.sh` (déplacer en `tests/vap-static/` ; ajouter une vérification « chaque VAP de `platform/policies/` a un dossier de tests », sur le modèle de la cohérence politique/tests existante).
3. Exposer le tout dans `tools/dev/check` au niveau L2 (≈ 3 s, 0,6 s pour les VAP) avec l'outil `kyverno` installé par la VM cloud (SL-2). Aujourd'hui `kyverno` est absent de la VM : téléchargement à épingler par sha256 depuis `versions.env`.
4. Transposer ensuite les cas rejouables de `tests/vap` ; garder `vap` sur k3d pour sous-ressources, CEL réelle et audit.

## 5. Alternatives écartées

- **`conftest`** (OPA/Rego) : demanderait de réécrire les CEL en Rego, donc de tester une autre implémentation que celle qui s'exécute dans l'API server. Écarté, `NOT_TESTED`.
- **`kubeconform`** : déjà en CI ; valide le schéma, pas la CEL ni `matchConditions`.
- **`kubectl-validate`** : valide les ressources contre OpenAPI/CRD et leurs règles CEL de schéma, pas les VAP ; dernière version 2024-05 (v0.0.4). Lu par son numéro de version seulement, `NOT_TESTED`.

## 6. Implémentations publiques consultées

| Source | Licence | Décision | Pourquoi |
|---|---|---|---|
| Kyverno CLI v1.19.2, https://github.com/kyverno/kyverno/tree/e63308f1e16c05cd009ac4864be6ec25c66b49be (binaire de la release, sha256 vérifié ; `LICENSE` de l'archive lue) | Apache-2.0 | adopté | exécute `kyverno test` et les VAP natives sans cluster |
| conftest v0.71.1, https://github.com/open-policy-agent/conftest/tree/8f7ac015cb51d81992f2ffbe2b0c1451fd05d1c5 (en-tête de `LICENSE` lu seulement) | Apache-2.0 attendue, non confirmée | écarté | Rego, pas la CEL de l'API server |
| kubectl-validate v0.0.4, https://github.com/kubernetes-sigs/kubectl-validate/tree/fac15fd6e47976df8585fe18a73246d78642eab9 | Apache-2.0 (en-tête lu) | écarté | ne teste pas les VAP |
| kubeconform v0.8.0, https://github.com/yannh/kubeconform/tree/02374e583d700721f57300fae78e11acd27ee539 | Apache-2.0 (déjà adopté, `SHIFT-LEFT-DEV-ENV.md` §8) | inchangé | schéma seulement |

Limites : `github.com` n'a répondu que pour les téléchargements de releases et `raw.githubusercontent.com` ; la page de documentation `kyverno test` n'a pas été relue (le comportement est établi par l'exécution). Contenu externe traité comme donnée ; aucune commande exécutée sur la foi d'une page.
