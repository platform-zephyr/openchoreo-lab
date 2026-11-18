# T-487 / E4 : étape 8 (ClusterDataPlane) sur OKE recréé

Niveau : RUNTIME OKE. Installation `tools/oke/install.sh --step 8 --apply` : 22:56:03 à 22:57:07 UTC (2026-11-18).
Contrôle `tools/oke/verify.sh --step 8` (dernier passage, journal verify.log) :

| Horodatage UTC | Verdict | Contrôle |
|---|---|---|
| 2026-11-18T22:57:10Z | PASS | B8-cdp : ClusterDataPlane default présent |
| 2026-11-18T22:58:17Z | PASS | B8-agent-effective : permissions effectives du cluster-agent inchangées (après enregistrement) |
| 2026-11-18T22:58:19Z | PASS | B8-agent : agent connecté : agentConnection.connected=true, connectedAgents>=1, heartbeat < 5 min |
| 2026-11-18T22:58:21Z | PASS | B8-logs : journal de l'agent (200 lignes) sans refus VAP-1 ni erreur TLS |
