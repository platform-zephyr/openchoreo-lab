# T-487 / E4 : étape 10 (CNPG et lab-pg (PVC oci-bv 50 Gi)) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 10 --apply` : 22:59:43 à 23:02:45 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 10` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T23:17:59Z | PASS | B10-pg : Cluster CNPG lab-pg Ready |
| 2026-11-18T23:18:01Z | PASS | B10-pvc : PVC lab-pg Bound (block volume OCI) |
| 2026-11-18T23:18:02Z | PASS | B10-psa : lab-pg en PSA restricted |
| 2026-11-18T23:18:04Z | PASS | B10-cnpg : opérateur CNPG Available dans lab-cnpg |
