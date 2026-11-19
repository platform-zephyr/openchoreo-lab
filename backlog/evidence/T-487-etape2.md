# T-487 / E4 : étape 2 (Gateway API) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 2 --apply` : 22:41:49 à 22:41:53 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 2` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:41:56Z | PASS | B2-gatewayclasses : CRD gatewayclasses.gateway.networking.k8s.io Established |
| 2026-11-18T22:41:58Z | PASS | B2-gateways : CRD gateways.gateway.networking.k8s.io Established |
| 2026-11-18T22:42:00Z | PASS | B2-httproutes : CRD httproutes.gateway.networking.k8s.io Established |
| 2026-11-18T22:42:01Z | PASS | B2-referencegrants : CRD referencegrants.gateway.networking.k8s.io Established |
| 2026-11-18T22:42:03Z | PASS | B2-grpcroutes : CRD grpcroutes.gateway.networking.k8s.io Established |
