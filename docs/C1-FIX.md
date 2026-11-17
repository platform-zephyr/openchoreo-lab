# C1 : correctif de la CCNP `allow-egress-unisolated` (kube-ops)

Statut : PR brouillon https://github.com/SmadjaPaul/kube-ops/pull/1629 (branche `fix/oke-egress-unisolated-lab-exclusion`, commit `98a263f`). Elle n'est pas mergée et ne contient pas #1620. Tests runtime : `NOT_TESTED`.

## Problème

`allow-egress-unisolated` (egress `toEntities: [all]`) sélectionne tout namespace hors `auth`, `backstage`, `hindsight` et `databases`. Union Cilium : le default-deny egress de `openchoreo-*`, `lab-*`, `cnpg-system` et `dp-*` est neutralisé (sonde `openchoreo-control-plane` → `1.1.1.1:443` ouverte).

## Correctif (kube-ops `k8s/clusters/oracle-a1/baseline/imds-deny.yaml`, même chemin que #1620)

```diff
       - key: io.kubernetes.pod.namespace
         operator: NotIn
         values: [auth, backstage, hindsight, databases]
+      - key: io.cilium.k8s.namespace.labels.platform.smadja.dev/egress-isolated
+        operator: NotIn
+        values: ["true"]
```

- `NotIn` sélectionne aussi les namespaces sans le label : leur comportement ne change pas.
- `deny-imds` est inchangé et reste global (`endpointSelector: {}`).
- La correction s'applique à la main (`kubectl apply -k k8s/clusters/oracle-a1/baseline`) : aucune Application Argo ne pointe sur ce chemin.

## Namespaces impactés (perdent l'allow-all)

Ce sont les namespaces labellisés `platform.smadja.dev/egress-isolated=true` : `openchoreo-control-plane`, `openchoreo-data-plane`, `openchoreo-cert-manager`, `openchoreo-external-secrets`, `lab-secrets`, `lab-argocd`, `cnpg-system` et `lab-pg`. Leur egress se limite ensuite aux policies de `platform/install/manifests/02-network-policies.yaml` (DNS, kube-apiserver, flux nominatifs, github.com pour Argo).

`dp-*` reste ouvert tant que le CPT `cell-restricted` ne pose pas aussi `platform.smadja.dev/egress-isolated: "true"`. Il pose seulement `platform.smadja.dev/cell`.

## Test (coordinateur, depuis le worktree kube-ops de la PR)

```bash
cd <checkout kube-ops sur fix/oke-egress-unisolated-lab-exclusion>
export KUBECONFIG=<kubeconfig oracle-a1>
bash tests/oke-baseline/c1-egress-isolation.sh plan   # lecture seule : sélecteur vivant, namespaces/pods impactés, dp-* non labellisés
bash tests/oke-baseline/c1-egress-isolation.sh all    # backup + sondes avant + apply + sondes après
# si régression :
bash tests/oke-baseline/c1-egress-isolation.sh rollback   # kubectl replace de la sauvegarde, durée mesurée (S-rollback)
```

Attendu après correctif :

| Contrôle | Résultat attendu |
|---|---|
| `S-open-ctrl` | namespace témoin non labellisé : `1.1.1.1:443` OPEN |
| `S-dns-iso` | DNS OK depuis `openchoreo-control-plane` |
| `S-api-iso` | apiserver OK (TLS vérifié avec `kube-root-ca.crt`) depuis `openchoreo-control-plane` |
| `S-egress-iso` | `1.1.1.1:443` TIMEOUT depuis `openchoreo-control-plane` |
| `S-imds-*` | IMDS `:80` TIMEOUT dans les deux namespaces ; dans le namespace témoin, `169.254.169.254:53` répond |
| `S-deploy` | tous les déploiements des namespaces isolés sont prêts |

Leases, redémarrages et drops Cilium sur 30 s sont affichés en INFO. La sauvegarde est écrite dans `./c1-backup/`. Après le test, `tools/oke/preflight.sh` doit afficher « C1 résolu » et `tools/oke/verify.sh --security` doit donner `S-egress` PASS.

## Non prouvé / risques

- Sélection Cilium 1.20 par label de namespace avec `NotIn` : contrôles statiques (kustomize, kubeconform sur le CRD) PASS, comportement runtime non prouvé.
- Un flux légitime non déclaré (egress d'un contrôleur d'essai) sera coupé. À surveiller : drops et `S-deploy`.
- Le label devient une interface : tout namespace qui le pose perd l'egress libre.
