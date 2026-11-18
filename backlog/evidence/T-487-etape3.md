# T-487 / E4 : étape 3 (cert-manager) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 3 --apply` : 22:42:06 à 22:43:37 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 3` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:43:41Z | PASS | B3-deploy : cert-manager : 3 Deployments Available |
| 2026-11-18T22:43:43Z | PASS | B3-noks : aucun objet cert-manager dans kube-system (leader election dans son namespace) |
| 2026-11-18T22:43:46Z | PASS | B3-webhook : webhook cert-manager joignable (dry-run serveur d'un Issuer) |
