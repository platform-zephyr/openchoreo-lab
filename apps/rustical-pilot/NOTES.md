# rustical-pilot : app.yaml ecrit, pilote prive, DONNEES SYNTHETIQUES UNIQUEMENT

Source kube-ops : `k8s/applications/platform/rustical-pilot/` + `k8s/optional/rustical/` @ origin/main [C]. Date : 2026-11-17.

## Verifications
- `appgen validate` : OK. `appgen render --out <scratchpad>` : OK (rien ecrit dans `generated/`).
- Digest : index `sha256:33ec65f695eeed3fafb15270f274a89f7201d2bb3ffe3369e1be1a94e04af880` contient linux/arm64 (`471751e9...`) [C]. Identique a kube-ops (qui l'epingle deja).
- Runtime : NOT_TESTED. Les gates pilote de kube-ops (README : connexion OIDC a deux utilisateurs, CRUD CalDAV/CardDAV synthetique, rollback GitOps) restent a executer.

## Ecarts de securite vs kube-ops
1. **FQDN et CIDR non declares** : kube-ops autorise `auth.smadja.dev:443`, la VIP Gateway interne `192.0.2.192/32` et le serveur Authentik. Ici `egress: none` + `allowIdp: true`. `thunder.lab.smadja.dev` est refuse en egress FQDN sur k3d (pas de Cilium). Au gate OKE : `egress: [{fqdn: thunder.lab.smadja.dev, ports: [443]}]`.
2. **Mot de passe local** : kube-ops met `RUSTICAL_FRONTEND__ALLOW_PASSWORD_LOGIN: "true"`. Je l'ai retire : appgen refuse toute variable d'environnement dont le nom ressemble a un secret (`PASSWORD`). Le comportement par defaut de RustiCal est [S] a verifier ; si le login mot de passe est actif, le pilote a une voie d'auth hors OIDC. Extension requise pour le desactiver proprement : liste blanche de booleens de config ou option `identity` (ex. `passwordLogin: false`).
3. **Sonde** : `healthPath: /` [S]. kube-ops utilise `rustical health` (exec).
4. **Secrets renommes** : `APP_RUSTICAL_OIDC_CLIENT_ID/SECRET` devient `RUSTICAL_PILOT_OIDC_CLIENT_ID/SECRET` (prefixe `RUSTICAL_PILOT_`). Action Paul : renommer dans Doppler.
5. **Inscription OIDC** : `RUSTICAL_OIDC__ALLOW_SIGN_UP: "true"` comme kube-ops. La vraie porte est `allowedGroups` cote ThunderID [S] (noms `family`/`admin` a confirmer).
6. **Exposition** : `private`, sans hote. kube-ops expose `calendar.smadja.dev` en interne : non declare.
7. **Stockage** : PVC 1Gi `block-rwo` (local-path) au lieu de `longhorn-bulk`. Mode `Recreate` impose.
8. **Sauvegarde** : `class: regenerable` (donnees synthetiques). Velero de kube-ops non reproduit. Aucune donnee reelle ne doit entrer.
9. Securite conteneur : uid 1000, rootfs en lecture seule (contrat cell) et `/tmp` seul en ecriture, comme kube-ops [C].

## Pour passer en OKE
Gate OKE, egress FQDN du point 1, et extension du point 2 avant tout test de login.
