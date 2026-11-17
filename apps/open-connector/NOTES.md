# open-connector : notes de portage

Source kube-ops : `k8s/applications/platform/open-connector/` @ origin/main ef50472 [C] (Deployment, PVC 2Gi, Service ClusterIP, CNP, ExternalSecret, README de test prive Paperless).

## Digest
- kube-ops pinne `ghcr.io/oomol-lab/open-connector@sha256:d8c59248...` : c'est un **manifeste mono-architecture amd64** (pas d'index, pas de linux/arm64) [C].
- Le README kube-ops cite v1.8.0 et le digest amd64 `2f1a48c8...`.
- Ici : index v1.8.0 `sha256:61e5e29a...`, qui contient linux/amd64 (`2f1a48c8...`) et linux/arm64 (`c3dfd585...`) [C]. Le cluster OKE oracle-a1 est arm64 [S] (shape A1) : le digest kube-ops ne peut pas y tourner.
- Equivalence v1.8.0 / d8c5 non verifiee [S] : a confirmer avant tout rapprochement des deux releases.

## Ecarts fonctionnels (schema v2alpha1 actuel)
1. **Egress : `none`** au lieu de `paperless:80/8000` + DNS dans kube-ops. Le paperless de test est donc injoignable depuis ce descripteur. Une cible par namespace/workload (pas un FQDN) est necessaire : extension E3 (`{entity|endpoint}`), a prevoir avant le test Paperless.
2. **Ingress inter-apps** : kube-ops autorise mastra-factory:3000. Non exprimable (E4 `fromApp`) ; bloque par le cell-restricted.
3. **Limite memoire** : `size: medium` = limite 512Mi ; kube-ops = limite 1Gi (requete 192Mi). Risque OOM a mesurer.
4. **Variables** : toutes les variables non secretes de kube-ops sont reprises telles quelles, y compris `OOMOL_CONNECT_ALLOW_PRIVATE_NETWORK=true` (sans effet sur l'egress ici, puisque egress est `none`).
5. **Secrets** : `OPEN_CONNECTOR_ADMIN_TOKEN` et `OPEN_CONNECTOR_ENCRYPTION_KEY` (prefixe `OPEN_CONNECTOR_` impose). kube-ops utilise `APP_OPENCONNECTOR_*`. Correspondance faite au provisioning, sans valeur dans Git.
6. **Stockage** : PVC 2Gi `block-rwo` (kube-ops : longhorn-bulk). Sur OKE, oci-bv facture 50Gi minimum ; `backup.class: regenerable` (donnees de connexion de test).

## Securite
- Exposition `private` (aucune route publique), `auth: none` : identique a kube-ops (pas de HTTPRoute).
- `runAsUser: 10001` (kube-ops identique), securityContext cell-restricted (non-root, drop ALL, rootfs RO + /tmp, token non monte).
- Statut runtime : NOT_TESTED.
