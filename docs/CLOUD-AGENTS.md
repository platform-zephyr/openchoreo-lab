# Agents Claude Code dans le cloud : dev et prod sur le même OKE

Décisions de Paul du 2026-11-18 (inscrites dans `missions/MISSION.md`) :
- le backlog de ce labo vit dans les **issues GitHub** de ce dépôt, pas dans Linear (adoption d'OpenChoreo non tranchée) ;
- **un seul cluster** : OKE Always Free, un nœud, pas de HA. « dev » et « prod » sont deux **Environments OpenChoreo**
  sur ce même cluster. La charge du dev doit rester minimale ;
- le **MCP OpenChoreo** peut être joint depuis le cloud par **Cloudflare Tunnel + Cloudflare Access**. Aucun accès
  anonyme, aucun LoadBalancer.

## 1. Boucle d'un agent cloud (cible)

```
issue GitHub ──► session Claude Code cloud (ou runner agent:dev) ──► PR apps/<nom>/app.yaml (environments: [development])
   ──► ci-ok ──► merge (AUTONOME) ──► Argo CD ──► OpenChoreo, Environment development
   ──► preuve runtime automatique (Job dans le cluster) + lecture MCP (agent-reader) ──► correctif éventuel par PR
   ──► PR de promotion (environments: [production]) ──► revue de Paul ──► Argo ──► production
```

L'agent n'a **jamais** de kubeconfig, d'accès bastion ni de jeton en écriture. Il écrit par Git et lit par MCP.

| | Écriture | Lecture |
|---|---|---|
| development | PR, classe AUTONOME (app A privée, `egress: none`) | MCP `openchoreo-agent-reader` + résultat de la preuve automatique |
| production | PR de promotion, classe REVUE (Paul merge) | MCP `openchoreo-agent-reader` |

## 2. Frugalité du dev (un nœud : 1830m CPU / 8,4 GiB allocatables)

Règles visées (à faire respecter par la CI, issue dédiée) :
- le dev est **éphémère** : une app passe par `[development]`, puis `[production]` à la promotion. Le binding dev
  disparaît à ce moment-là. `[development, production]` est réservé à un correctif en cours ;
- en development : `replicas: 1`, `size: small` (50m / 128Mi demandés) ;
- **au plus 2 apps** en development en même temps ;
- **aucune app B ou C** (Postgres, PVC) en development : un volume coûte, et le stockage OCI reste soumis à l'accord
  de Paul ;
- seuil dur inchangé : requests ≤ 70 % de l'allocatable, mesuré par `tools/oke/verify.sh`.

## 3. MCP OpenChoreo depuis le cloud (Cloudflare Tunnel + Access)

Chemin : session cloud → proxy de la session → `https://<hôte MCP>` (Cloudflare Access) → tunnel `cloudflared`
existant sur OKE → Service ClusterIP du MCP OpenChoreo (control plane).

Deux contrôles indépendants, les deux obligatoires :
1. **Cloudflare Access** : application self-hosted sur l'hôte MCP, politique `Service Auth` limitée à **un** service
   token dédié aux agents. Aucune politique « Allow everyone », aucun bypass. Durée du token courte et rotation
   par Paul.
2. **OpenChoreo authz** : JWT Authentik du client `openchoreo-agent-reader` (lecture seule, deny explicite,
   `docs/AGENT-ACCESS.md`). Le MCP ne fait jamais confiance au seul passage par Access.

Côté cluster (PR `platform/`, REVUE) : NetworkPolicy qui autorise **seulement** le namespace de `cloudflared` vers le
port du MCP. Rien d'autre du control plane n'est routé par le tunnel.

Côté session cloud : les secrets ne sont **jamais** dans le dépôt, ni dans un prompt, ni dans une variable
d'environnement en clair. Ils sont enregistrés comme *network secrets* de l'environnement Claude Code. Le proxy les
injecte sur l'hôte voulu et l'agent ne voit pas leur valeur :
- hôte MCP : le service token Access [S : en un seul en-tête, option « read service tokens from header » de
  l'application Access, à vérifier] ;
- hôte du token Authentik : `client_id:client_secret` du client reader en Basic. La session obtient alors un JWT de
  15 min par `client_credentials` [S : à vérifier ; sinon, jeton reader de durée plus longue émis par Paul].

Ce que l'agent ne fait jamais : créer l'application Access, le service token, l'hôte DNS ou le client Authentik
(classe MANDAT, Paul seul).

## 4. Preuve runtime sans coordinateur

Aujourd'hui, une preuve OKE exige le coordinateur et le bastion : c'est le goulot. Cible : un Job de vérification
lancé par Argo CD après chaque sync (PostSync) dans un namespace `lab-*`. Il exécute les checks de
`golden-paths/_checks` en lecture (HTTP 200 interne, PSA, NetworkPolicy) et publie un résultat daté lisible par l'agent
(statut de commit ou objet lu par MCP). Une CI verte reste différente d'une preuve runtime. Ce Job **est** la preuve
runtime, avec horodatage et révision Argo.

## 5. Gestes de Paul (MANDAT)

1. Approuver la PR `platform/` (Environment development, pipeline, NetworkPolicy MCP).
2. Cloudflare : hôte MCP sur le tunnel existant, application Access, service token agents.
3. Authentik : client `openchoreo-agent-reader` (déjà prévu, `docs/IDENTITY.md`).
4. Environnement Claude Code cloud : hôtes autorisés (hôte MCP, hôte Authentik) et network secrets ci-dessus.
