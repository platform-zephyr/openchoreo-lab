# T-487 / E4 : étape 6 (control plane (security bundle 1.0.1)) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 6 --apply` : 22:46:54 à 22:50:36 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 6` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:50:42Z | PASS | B6-bundle : release openchoreo-control-plane durcie (security bundle) |
| 2026-11-18T22:50:45Z | PASS | B6-image : contrôleur : image épinglée par le digest du security bundle |
| 2026-11-18T22:50:47Z | PASS | B6-deploy : CP : controller-manager, openchoreo-api, cluster-gateway, kgateway Available |
| 2026-11-18T22:50:48Z | PASS | B6-ca : ConfigMap cluster-gateway-ca peuplé (CA publique) |
| 2026-11-18T22:50:50Z | PASS | B6-webhook : webhook OpenChoreo joignable (dry-run serveur du CCT service-restricted) |
| 2026-11-18T22:50:51Z | PASS | B6-noevents : event-forwarder absent (profil minimal ; Backstage : étape 6b) |
| 2026-11-18T22:50:53Z | PASS | B6-netpol : CNP d'egress vers Authentik présentes (03-idp-egress.yaml) |
| 2026-11-18T22:50:55Z | PASS | B6-no-secrets-rbac : aucun (Cluster)Role de la release CP ne donne le droit secrets (hors GET nommé git-webhook-secrets) |
| 2026-11-18T22:52:23Z | FAIL | B6-sa-effective : permissions effectives de tous les ServiceAccounts du CP : aucun accès aux Secrets hors GET nommé |
| 2026-11-18T22:52:25Z | PASS | B6-no-tryout : ni mcp-tryout-client-binding ni liaisons ThunderID (bootstrap.mappings remplacé) |
| 2026-11-18T22:52:28Z | PASS | B6-health : openchoreo-api /health = 200 |
| 2026-11-18T22:52:28Z | PASS | B6-mcp : MCP sans jeton refusé (401) |
