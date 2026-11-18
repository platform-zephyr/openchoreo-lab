# T-487 / E4 : étape 1 (namespaces, quotas, NetworkPolicy) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 1 --apply` : 22:40:46 à 22:41:04 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 1` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:41:08Z | PASS | B1-psa-openchoreo-control-plane : PSA enforce=restricted sur openchoreo-control-plane |
| 2026-11-18T22:41:09Z | PASS | B1-psa-openchoreo-cert-manager : PSA enforce=restricted sur openchoreo-cert-manager |
| 2026-11-18T22:41:11Z | PASS | B1-psa-openchoreo-external-secrets : PSA enforce=restricted sur openchoreo-external-secrets |
| 2026-11-18T22:41:12Z | PASS | B1-psa-lab-secrets : PSA enforce=restricted sur lab-secrets |
| 2026-11-18T22:41:14Z | PASS | B1-psa-lab-argocd : PSA enforce=restricted sur lab-argocd |
| 2026-11-18T22:41:16Z | PASS | B1-psa-lab-cnpg : PSA enforce=restricted sur lab-cnpg |
| 2026-11-18T22:41:17Z | PASS | B1-psa-dp : PSA enforce=baseline sur openchoreo-data-plane (exception documentée) |
| 2026-11-18T22:41:19Z | PASS | B1-quota-openchoreo-control-plane : ResourceQuota lab-quota dans openchoreo-control-plane |
| 2026-11-18T22:41:20Z | PASS | B1-deny-openchoreo-control-plane : NetworkPolicy lab-default-deny dans openchoreo-control-plane |
| 2026-11-18T22:41:22Z | PASS | B1-quota-openchoreo-data-plane : ResourceQuota lab-quota dans openchoreo-data-plane |
| 2026-11-18T22:41:23Z | PASS | B1-deny-openchoreo-data-plane : NetworkPolicy lab-default-deny dans openchoreo-data-plane |
| 2026-11-18T22:41:25Z | PASS | B1-quota-openchoreo-cert-manager : ResourceQuota lab-quota dans openchoreo-cert-manager |
| 2026-11-18T22:41:26Z | PASS | B1-deny-openchoreo-cert-manager : NetworkPolicy lab-default-deny dans openchoreo-cert-manager |
| 2026-11-18T22:41:28Z | PASS | B1-quota-openchoreo-external-secrets : ResourceQuota lab-quota dans openchoreo-external-secrets |
| 2026-11-18T22:41:30Z | PASS | B1-deny-openchoreo-external-secrets : NetworkPolicy lab-default-deny dans openchoreo-external-secrets |
| 2026-11-18T22:41:31Z | PASS | B1-quota-lab-secrets : ResourceQuota lab-quota dans lab-secrets |
| 2026-11-18T22:41:33Z | PASS | B1-deny-lab-secrets : NetworkPolicy lab-default-deny dans lab-secrets |
| 2026-11-18T22:41:34Z | PASS | B1-quota-lab-argocd : ResourceQuota lab-quota dans lab-argocd |
| 2026-11-18T22:41:36Z | PASS | B1-deny-lab-argocd : NetworkPolicy lab-default-deny dans lab-argocd |
| 2026-11-18T22:41:37Z | PASS | B1-quota-lab-cnpg : ResourceQuota lab-quota dans lab-cnpg |
| 2026-11-18T22:41:39Z | PASS | B1-deny-lab-cnpg : NetworkPolicy lab-default-deny dans lab-cnpg |
| 2026-11-18T22:41:42Z | PASS | B1-admission : pod privileged+hostNetwork refusé par PSA restricted dans openchoreo-control-plane |
| 2026-11-18T22:41:45Z | FAIL | B1-vap-digest : image sans digest refusée par la VAP kube-ops baseline-image-digest (pod PSA-conforme) (admis) |
| 2026-11-18T22:41:47Z | PASS | B1-legacy-cnpg : namespace cnpg-system absent (migration lab-cnpg faite) |
