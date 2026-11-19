# T-487 / E4 : étape 5 (kgateway) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 5 --apply` : 22:45:08 à 22:46:26 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 5` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:46:29Z | PASS | B5-deploy : kgateway Available |
| 2026-11-18T22:46:31Z | PASS | B5-class : GatewayClass kgateway Accepted |
