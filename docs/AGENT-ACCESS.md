# AGENT-ACCESS — accès des agents IA (Claude Code, Codex) à OpenChoreo

**Statut** : modèle prouvé sur **k3d** (50 PASS / 0 FAIL / 2 NOT_TESTED, voir `tests/mcp/RESULTS.md`). Rien n'a été joué sur OKE.
Manifestes : `platform/authz/`. Identités IdP : `docs/IDENTITY.md` (autre agent, non modifié ici).

## 1. Conclusion

- Un agent **lit** avec `openchoreo-agent-reader`. Il n'a aucune écriture, aucun secret, aucun accès à l'authz.
- Un agent **écrit** seulement sous mandat, avec `openchoreo-agent-operator`, et uniquement au **runtime** des environnements non productifs : replicas et ressources d'un ReleaseBinding, déploiement d'une release existante.
- Tout changement durable passe par une **PR** (`AGENTS.md`). Écrire via MCP **contourne GitOps** : c'est prouvé, l'écriture arrive dans le cluster sans commit (test O1b).
- Les interdits sont posés en **deny explicite** (`lab-agent-forbidden`). Le deny l'emporte même si un allow est ajouté par erreur (tests T3-T5).

## 2. Qui lit, qui écrit, où

| Sujet | Claim | Rôles OpenChoreo | Lit | Écrit |
|---|---|---|---|---|
| `openchoreo-agent-reader` (agent) | `client_id` | `lab-agent-reader`, deny `lab-agent-forbidden` | namespaces, projets, composants, workloads, releases, bindings, ressources, logs, événements, métriques, diagnostics | rien |
| `openchoreo-agent-operator` (agent, sous mandat) | `client_id` | `lab-agent-reader` + `lab-agent-operator` (CEL : development/staging), deny `lab-agent-forbidden` | idem | `update_release_binding`, `create_release_binding`, `create_component_release`, hors production |
| `openchoreo-viewers` (humain) | `groups` | `lab-viewer` | console en lecture, sans secret ni authz | rien |
| `openchoreo-developers` (humain) | `groups` | `developer` (rôle du chart) | tout le périmètre applicatif | composants, workloads, bindings, ressources |
| `authentik-admins` (humain) | `groups` | `lab-platform-admin` (`*`) | tout | tout, authz comprise |

Interdits explicites aux deux agents (deny) :

- toute l'authz : `*authzrole*` et `*authzrolebinding*` ;
- `secret:*`, `secretreference:*`, `resource:read-secrets`, `resource:connect` ;
- `component:exec`, `component:connect` ;
- création, modification et suppression des composants, workloads, ressources, traits, types, workflows, plans, environnements et namespaces ;
- `workflowrun:*` en écriture ;
- `auditlogs`, `platformlogs`, `wirelogs`.

`patch_component` est interdit lui aussi : c'est par lui qu'on attache un Trait. Le cas d'un Trait qui rend une ClusterRoleBinding est refusé deux fois, par l'authz (tests T1-T4) puis par le postRender du CCT (`tests/k3d` T03a).

**Règle MCP d'écriture.** L'opérateur reste borné au runtime. Une écriture MCP sert au dépannage ou à l'urgence. Elle est éphémère : Argo CD l'écrase au sync suivant si l'objet est dans `generated/` (non prouvé, G1). La correction durable est une PR. Les classes AUTONOME, REVUE, MANDAT et INTERDIT de `platform-guardrails` s'appliquent : le jeton operator relève de MANDAT.

Pourquoi les droits sont bornés par environnement et pas par namespace : la condition `resource.environment.endsWith("/development")` vaut quel que soit le namespace OpenChoreo. Sur OKE, on peut ajouter `scope: {namespace: default}` au mapping operator, comme dans `docs/IDENTITY.md`. Ce point n'a pas été testé, car la cible des tests vit dans `lab-mcp`.

## 3. Configurer Claude Code et Codex (aucun secret dans le dépôt)

Le jeton est obtenu **hors dépôt** par client_credentials. Il dure 15 minutes et se renouvelle simplement en relançant la commande. Le secret du client vient de Doppler, ou est remis par Paul. Il n'est jamais écrit dans un fichier du dépôt.

```bash
# OKE (Authentik, scope requis pour le claim client_id : docs/IDENTITY.md §2)
export OPENCHOREO_MCP_TOKEN="$(curl -fsS -X POST "$OIDC_TOKEN_URL" \
  -d grant_type=client_credentials -d client_id=openchoreo-agent-reader \
  -d client_secret="$(doppler secrets get OPENCHOREO_AGENT_READER_SECRET --plain)" \
  -d scope='openid openchoreo-client-id' | jq -r .access_token)"
```

Claude Code, fichier `.mcp.json` à la racine du dépôt. Il peut être commité, car il ne contient qu'une référence à une variable :

```json
{
  "mcpServers": {
    "openchoreo": {
      "type": "http",
      "url": "${OPENCHOREO_MCP_URL}",
      "headers": { "Authorization": "Bearer ${OPENCHOREO_MCP_TOKEN}" }
    }
  }
}
```

Codex, fichier `~/.codex/config.toml` (configuration locale, hors dépôt) :

```toml
[mcp_servers.openchoreo]
url = "https://<api-openchoreo>/mcp"
bearer_token_env_var = "OPENCHOREO_MCP_TOKEN"
```

- Par défaut, Claude Code et Codex reçoivent le jeton **reader**. Le jeton **operator** n'est émis que pour la durée d'un mandat, à l'agent qui l'exécute.
- Garder `filterByAuthz` par défaut (`true`). L'agent ne voit alors que ses outils. `?filterByAuthz=false` ne donne aucun droit (test L4), mais il expose 130 outils inutiles.
- Ne jamais lier par `client_id` un client public ou utilisateur, comme `user_mcp_client` ou un client CLI. Un jeton utilisateur sans `groups` mais avec `client_id` serait classé `service_account` (l'ordre de priorité du résolveur v1.3.3 le permet).
- Pour distinguer Claude de Codex dans les traces, prévoir un client par agent (par exemple `openchoreo-agent-reader-claude` et `-codex`), chacun avec ses 2 bindings (allow et deny). Proposition non testée.

## 4. Rotation et révocation

| Action | Effet | Délai |
|---|---|---|
| Régénérer le secret du provider Authentik, puis le mettre à jour dans Doppler | plus aucun nouveau jeton avec l'ancien secret | immédiat pour les nouveaux jetons ; ceux déjà émis restent valides jusqu'à `exp` (15 min max) |
| Supprimer le binding allow (PR, ou `kubectl delete` en urgence) | coupe **aussi les jetons déjà émis** : le PDP relit les CRD par watch, sans cache (`authorization.cache.enabled: false`) | quelques secondes (propagation observée < 6 s, tests T3-T5) |
| Désactiver le provider Authentik | plus de jeton | immédiat pour les nouveaux jetons |
| Kill-switch d'urgence | appliquer un binding `effect: deny` sur `"*"` pour le `client_id` (non testé tel quel ; le mécanisme deny est prouvé) | quelques secondes |

## 5. Mapping vers Authentik (`docs/IDENTITY.md`)

| Client ou groupe Authentik | Ici | Note |
|---|---|---|
| `openchoreo-agent-reader` (client_credentials) | `lab-agent-reader-binding` + `lab-agent-reader-deny` | claim `client_id` à **valeur fixe** par property mapping (scope `openchoreo-client-id`) |
| `openchoreo-agent-operator` | `lab-agent-operator-binding` (CEL) + `lab-agent-operator-deny` | idem |
| `openchoreo-viewers`, `openchoreo-developers`, `authentik-admins` | `bindings-humans.yaml` | claim `groups` |

Sur k3d, les tests utilisent des clients ThunderID de test portant **les mêmes `client_id`** : le même manifeste sert aux deux environnements.

**Conflit de noms ARBITRÉ (2026-11-17) : `platform/authz/` fait foi, le brouillon `platform/identity/authz/` est supprimé.** Ancien brouillon : `platform/identity/authz/openchoreo-authz.yaml` (brouillon, jamais appliqué) définit des objets **de même nom et de contenu différent** : `lab-viewer` (sans logs), `lab-viewers-binding`, `lab-agent-reader-binding` et `lab-agent-operator-binding` (`lab-release-operator`, scope `default`, sans deny). Il ne faut **pas appliquer les deux** : le dernier appliqué écrase l'autre. Seul `platform/authz/` est testé. Je propose qu'il remplace le brouillon, en y reportant si besoin le scope `namespace: default` et le binding `developer` + `cluster-reader`.

## 6. Journalisation et audit sans observability plane

Ce qu'on voit (prouvé sur k3d, AU1-AU3) :

- **`openchoreo-api` (stdout)** : un `ACCESS-LOG` JSON par requête, avec l'heure, la méthode, le chemin `/mcp`, l'IP source, le user-agent, le statut HTTP et la durée.
- **Objets écrits** : `metadata.managedFields` indique le gestionnaire `openchoreo-api` et l'horodatage, sans l'identité de l'agent. `generation` est incrémenté.
- **Événements et conditions** OpenChoreo sur l'objet (réconciliation).

Ce qu'on ne voit pas :

- **Le sujet** (`client_id`) et **la décision** (allow ou deny). La décision du PDP n'est loguée qu'en DEBUG. Un refus MCP est une réponse HTTP **200** portant une erreur JSON-RPC, donc invisible dans le statut.
- **L'audit structuré** (`audit.enabled`, acteur `actor.id_claim`) : il est désactivé et dépend d'un observability plane.

Options sans observability plane, à décider :

1. passer le log de `openchoreo-api` en DEBUG. C'est verbeux et ça inclut les entitlements ;
2. utiliser l'audit Kubernetes de l'apiserver OKE. Il verrait le SA `openchoreo-api`, pas l'agent ;
3. faire journaliser côté agent (transcripts Claude Code et Codex) les appels MCP avec leur `client_id`.

Pour un PoC, l'option 3 suffit. L'option 1 ne doit servir que le temps d'une investigation.

## 7. Limites

- k3d seulement. ThunderID au lieu d'Authentik : la forme des claims Authentik reste à vérifier (T-Z de `docs/IDENTITY.md`).
- Connexion navigateur par groupe non jouée (H8). Seule la décision du PDP est prouvée.
- La dérive GitOps d'une écriture MCP n'est pas mesurée (G1, attend A3).
- `list_authz_actions` reste appelable par tout sujet authentifié (catalogue statique).
- Le rôle `developer` du chart inclut `resource:read-secrets` et `component:exec` pour les humains.
