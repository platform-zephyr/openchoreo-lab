# T-487 / E4 : étape 4 (ESO et lab-store) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 4 --apply` : 22:43:46 à 22:45:01 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 4` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:45:04Z | PASS | B4-deploy : ESO Available |
| 2026-11-18T22:45:06Z | PASS | B4-store : ClusterSecretStore lab-store Ready |
| 2026-11-18T22:45:08Z | PASS | B4-crd-keep : CRD external-secrets.io annotées helm.sh/resource-policy=keep (install.sh --step 4 rejoué) |
