# Preuves runtime VAP et désinstallation (revue PR #8 : P1, P2, P3, A3) — k3d, pas OKE

> Flux sécurité A3, 2026-11-17. API server réel : k3d jetable `k3d-lab-sec-vap`, Kubernetes v1.35.5+k3s1, Helm 4.1.3,
> supprimé à la fin. Aucun accès OKE. Détail et preuves : `tests/vap/RESULTS.md`, `tests/uninstall-k3d/RESULTS.md`.
> Limite : nœud k3s non démarré (inotify de la VM colima partagée). L'admission, l'audit, Helm et les CRD sont réels ;
> aucun contrôleur n'a tourné.

## Conclusion

- **VAP.** La CI statique verte cachait un **contournement réel de VAP-1** : un `PUT namespaces/<dp-x>/status`
  (ou `/finalize`) par le cluster-agent passait la PSA d'une cellule à `privileged`.
  - Elle cachait aussi deux exfiltrations possibles de `lab-pg-superuser` via `ExternalSecret`
    (`target.template`, `dataFrom.extract`).
  - Corrigé dans `platform/policies/` et prouvé : 91/92 PASS. Le seul FAIL vient de la baseline kube-ops :
    `pods/ephemeralcontainers` non couvert hors dp-*.
- **Désinstallation.** `uninstall.sh` **ne fonctionnait pas avec Helm 4** (`helm list -a`), avec un échec OUVERT dans
  `--migrate-cnpg-system`.
  - `--all` cassait sur l'état réel d'OKE (étapes 1-5) ; `--step 1` orphelinait les webhooks cert-manager.
  - Corrigé et prouvé : 59/59 PASS, dont `--all` de bout en bout sans orphelin ni effet sur les PVC.
- **Avant tout `uninstall.sh` sur OKE** : rejouer `tests/uninstall-k3d/run.sh` sur un k3d dont le nœud démarre (A3
  restant), puis appliquer P1 (revue PR #8), qui n'est pas traité ici.

## Correctifs

| Fichier | Correctif | Preuve |
|---|---|---|
| `vap-cluster-agent-scope.yaml` R3 | s'applique aussi aux sous-ressources `namespaces/status` et `namespaces/finalize` | V1-N13, V1-N14 |
| idem R2 | lab-pg et Events identifiés par `groupe/ressource` | V1-W07 |
| idem R2b (nouvelle) | une identité `dp-X` n'écrit que dans `dp-X` | V1-A02, V1-A03 |
| idem R6 | `ExternalSecret` : générateur Password `<x>-pg` seul, sans template, extract, find, storeRef ni data | V1-P03, V1-P03b |
| bindings VAP-1 et VAP-2 | `validationActions: [Deny, Audit]` | AUD-* (annotations dans le journal d'audit) |
| `uninstall.sh` | `helm_releases` (Helm 3 et 4) ; `kd` (seul un kind non servi est toléré) ; garde de releases dans `undo_1` ; `undo_5` sans `--wait` puis attente des CRD ; `migrate_cnpg_system` limité aux kinds de l'étape 1 | M07, ALL, R1g, R5b, M02 |
| `lib.sh` | `guard_test_context` : actif seulement si `LAB_TEST_CLUSTER=k3d-lab-sec-vap`, plus contexte, serveur local, nœud `k3s://` et état dédié ; branche OKE inchangée | G01-G07 |

## Effets de `helm uninstall` (objets vivants)

- **CRD gardées** (`helm.sh/resource-policy: keep` présent sur l'objet vivant) :
  - cert-manager : 6 CRD, dans `templates/` ;
  - ESO : 23 CRD, dans `templates/crds/` ;
  - argo-cd : 3 CRD, dans `templates/crds/`.
- **CRD supprimées avec leurs CR** : kgateway-crds, 8 CRD dans `templates/`, sans `keep`.
- **Jamais touchées** : openchoreo-control-plane, 36 CRD dans `crds/` (rendu seulement).
- Une CR à finalizer laisse sa CRD en `Terminating` jusqu'au retrait du finalizer. Les hooks `pre-install` d'Argo
  restent hors release (rendu seulement).

## Reste à faire

- Rejouer les deux bancs avec un nœud réel. Il faut lever la limite inotify de la VM colima, geste de Paul :
  `colima ssh -p openchoreo -- sudo sysctl -w fs.inotify.max_user_instances=512`. On couvrira alors selfHeal et les
  finalizers Argo, les hooks, `budget_gate`, l'exec effectif et les webhooks.
- A3 : cycle réel du cluster-agent OpenChoreo (whoami, cnpg-lab-db) sous VAP-1 corrigée, en particulier R2b et R6
  face aux écritures réelles de l'agent.
- m1 (dp-* créé en `baseline`), `PushSecret.secretStoreRefs` non borné, protection des objets VAP/VAPB par RBAC seul.
- À signaler à kube-ops : `baseline-pod-hardening` ne couvre pas `pods/ephemeralcontainers` ;
  `baseline-image-digest` est en `Warn` seulement.
