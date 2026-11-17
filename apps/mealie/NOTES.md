# mealie : app.yaml ecrit, pilote (donnees de test uniquement)

Source kube-ops : `k8s/applications/catalog/mealie/` @ origin/main [C]. Date : 2026-11-17.

## Verifications
- `appgen validate` : OK. `appgen render --out <scratchpad>` : OK (rien ecrit dans `generated/`).
- Digest : index `sha256:8b02290f4d1806f02acac6f25f6d48a3c965612fda1f8e914d5af533276f8688` contient linux/arm64 (`1994d77a...`) [C] via `docker buildx imagetools inspect`. kube-ops pinne le tag seul (`v3.28.0`).
- Runtime (k3d) : NOT_TESTED. Rien n'a ete deploye ni teste.

## Ecarts de securite vs kube-ops
1. **runAsUser 911 -> 1000** : le schema impose `runAsUser >= 1000`. [S] Mealie fonctionne en 1000 avec fsGroup=1000 sur le PVC ; a prouver en Phase 0. Une extension du minimum serait requise si 911 est indispensable.
2. **Egress** : kube-ops n'a pas de section egress sur la CNP (sortie non restreinte [S]). Ici `egress: none` + `allowIdp: true`. Consequence : l'import de recettes par URL (scraping) ne fonctionnera pas.
3. **FQDN ThunderID non declare** : `thunder.lab.smadja.dev` en egress FQDN est refuse sur k3d (flannel, pas de Cilium). Au gate OKE, ajouter `egress: [{fqdn: thunder.lab.smadja.dev, ports: [443]}]` (allowIdp reste requis par la regle OIDC).
4. **Exposition** : `private` (pas d'ext). Aucun hote public. Le nom interne de `BASE_URL` (`mealie.lab.smadja.dev`) n'est pas declare : `host` n'est admis que pour le public. [S] a trancher.
5. **Sauvegarde** : kube-ops = Velero quotidien. Labo = `backup.class: none` (aucun mecanisme admis : `backupMechanisms: [none]`, `irreplaceable` refuse). Donnees reelles de famille : NE PAS migrer tant qu'un mecanisme de sauvegarde n'est pas admis.
6. **Secret renomme** : kube-ops `APP_MEALIE_OIDC_CLIENT_SECRET` devient `MEALIE_OIDC_CLIENT_SECRET` (prefixe `<NAME>_` impose par la CI). Action Paul : creer/renommer la cle dans Doppler.
7. **OIDC** : `OIDC_CONFIGURATION_URL` = chemin discovery ThunderID [S] ; groupes `family`/`admin` au lieu de `family`/`authentik-admins` [S] (noms de groupes ThunderID a confirmer). `OIDC_SIGNUP_ENABLED` garde `true` comme kube-ops : la vraie porte est `allowedGroups` cote IdP.
8. **Sonde ajoutee** : `/api/app/about` [S] (kube-ops n'en a pas).
9. **Stockage** : PVC 5Gi `block-rwo` (local-path sur k3d) au lieu de `longhorn-fast`.
10. **Metriques** : desactivees (non declarees dans kube-ops).

## Pour passer en OKE
Gate OKE, puis ajouter l'egress FQDN du point 3. Pas de donnees reelles avant le point 5.
