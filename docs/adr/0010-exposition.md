# ADR-0010 — Exposition : privé par défaut, public par Cloudflare Tunnel + Access
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0007, ADR-0009 ; `missions/MISSION.md` (exception MCP du 2026-11-18)

## Contexte
- Pas de LoadBalancer OCI (quota 0, coût). OpenChoreo suppose un LoadBalancer par plan (CONSOLIDATION §b).
- kube-ops : deux Gateways quasi identiques, un wildcard DNS qui rend une route `external` publique dès le merge,
  Cloudflare Access configuré hors dépôt (KUBE-OPS-REQUIREMENTS §6.2).
- Écart G6 : `exposure.host` et `auth: cloudflare-access` ne sont pas rendus.

## Décision
1. **Trois modes, un champ** : `exposure.mode: private | internal | public`.
   - `private` (défaut) : joignable seulement depuis le cluster (et port-forward) ;
   - `internal` : réseau du foyer / NetBird, jamais Cloudflare ;
   - `public` : Cloudflare Tunnel → gateway ClusterIP, **toujours** derrière une authentification
     (`identity.mode: oidc|proxy`) ou Cloudflare Access par groupe.
2. **Pas de publication implicite** : le wildcard DNS `*.smadja.dev` (socle, Tofu) reste, mais un hôte n'est
   joignable que si l'app déclare `public` : la route vers le tunnel **et** l'application Cloudflare Access sont
   générées avec l'app (ADR-0009). Aucune Gateway « external » ne publie toutes les routes d'office.
3. **Le MCP OpenChoreo** est la seule exposition plateforme : Access service token + authz OpenChoreo.
4. Aucune exposition par LoadBalancer, NodePort ou hostPort, sur aucun cluster.

## Conséquences
- `appgen` rend HTTPRoute par hôte (G6) et les ressources Cloudflare par app.
- Passer une app en `public` reste AUTONOME si l'auth est déclarée et que la CI le vérifie ; sans auth, refus.

## Alternatives écartées
- **Wildcard + Gateway external** (kube-ops) : publication implicite au merge.
- **LoadBalancer OCI** : coût, et contourne Access.

## Vérification
- CI : `public` sans auth → refus. Test externe (sonde hors réseau) : hôte public sans session → 302/403.

## Références
`docs/APP-CONTRACT.md` §10.7, `golden-paths/SCHEMA-GAPS.md` G6, `docs/CLOUD-AGENTS.md` §3.
