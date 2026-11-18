# T-487 / E4 : étape 7 (data plane) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 7 --apply` : 22:52:41 à 22:54:29 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 7` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:54:32Z | PASS | B7-deploy : DP : cluster-agent et Envoy gateway-default Available |
| 2026-11-18T22:54:34Z | PASS | B7-gw : Gateway gateway-default Programmed |
| 2026-11-18T22:54:36Z | PASS | B7-nolb : aucun Service LoadBalancer/NodePort dans les namespaces d'essai |
| 2026-11-18T22:54:37Z | PASS | B7-vap : VAP lab-cluster-agent-scope et lab-cell-pod-hardening présentes |
| 2026-11-18T22:54:41Z | PASS | B7-bundle : release openchoreo-data-plane durcie (security bundle) |
| 2026-11-18T22:55:47Z | PASS | B7-agent-effective : permissions effectives du cluster-agent : ni Secrets, ni exec, ni RBAC hors dp-*, ni joker |
| 2026-11-18T22:55:50Z | PASS | B7-agent-rb : cluster-agent : RoleBinding hors dp-* refusé (dry-run, impersonation) |
| 2026-11-18T22:55:53Z | PASS | B7-vap1 : cluster-agent : ClusterRoleBinding refusée par VAP-1 (dry-run, impersonation) |
| 2026-11-18T22:55:56Z | PASS | B7-exec : cluster-agent : kubectl exec dans openchoreo-control-plane refusé par VAP-1 (CONNECT pods/exec) |
| 2026-11-18T22:56:00Z | PASS | B7-psa-ok : cluster-agent : Namespace dp-* restricted admis (témoin, dry-run) |
| 2026-11-18T22:56:03Z | PASS | B7-psa-lock : cluster-agent : Namespace dp-* en PSA privileged refusé par VAP-1 (dry-run) |
