# Recherche — Services IA : sandbox, gateway, identité et audit des IA

Date : 2026-11-18 · Statut : recherche pour ADR (rien appliqué, aucun cluster touché, aucun secret).
Marques : **[C]** lu dans un fichier du dépôt ou une page GitHub ouverte ; **[E]** connaissance du chercheur, non revérifiée ;
**[S]** supposition à prouver. Preuve runtime : aucune ici (NOT_TESTED partout) ; k3d ≠ OKE.

## 1. Conclusion
1. **Un seul chemin pour tout service IA** : sandbox gVisor (`runtimeClassName: gvisor`) + egress uniquement vers le
   gateway + clé virtuelle générée par la plateforme + une identité par agent + audit corrélé. Déclaré par
   `ai: {models, mcp}` dans `app.yaml`, jamais par une clé LLM dans l'app.
2. **Sandbox = gVisor en mode `systrap`, pas Kata/Firecracker** : l'OKE Always Free est une VM arm64 sans virtualisation
   imbriquée [E], donc ni KVM ni microVM ; gVisor n'en a pas besoin [E]. Talos a l'extension `siderolabs/gvisor` [C].
   **Rien n'est prouvé** : kube-ops et homelab-infra le disent eux-mêmes (« isolation gVisor non prouvée ») [C].
3. **Gateway = agentgateway, composant de plateforme** (`platform/ai-gateway/`), pas une `apps/<nom>` : c'est la cause
   n°6 de `apps/agentgateway/NOTES.md` [C]. Il détient les seules clés de fournisseur LLM.
4. **Identité** : un client Authentik `client_credentials` par agent (OSS) ; clés virtuelles pour les apps qui ne parlent
   pas OAuth. SPIFFE/SPIRE écarté en v1 (déjà exclu par homelab-infra pour coût d'exploitation [C]).
5. **MCP/skills externes** = entrée non fiable : allowlist en Git, épinglage par digest, passage obligatoire par le
   gateway (authz par outil), sorties traitées comme données, jamais de secret ni d'écriture cluster derrière.
6. **Agents OpenChoreo (SRE, FinOps, portail)** : désactivés par défaut ; spike sur k3d avec fournisseur factice ; activés
   seulement si leur clé LLM est une clé virtuelle du gateway (voir §7, point à lever).

## 2. Ce qui a pu être lu (et ce qui n'a pas pu l'être)
- **Lus [C]** : ADR 0002/0006/0007/0013/0014, `docs/adr/README.md`, T-068/T-022/T-023, `mcp-ai-agents.md`,
  `AGENT-ACCESS.md`, `AGENT-IDENTITY.md`, `apps/agentgateway/NOTES.md`, kube-ops (`agentgateway/resources.yaml`,
  `mastra-sandbox/`, `agent-sandbox/runtimeclass.yaml`), homelab-infra (`agent-identities.md`, `identity-layer.md`,
  `talos-bootstrap.md`, `decisions.md`).
- **Web lu** : github.com/kubernetes-sigs/agent-sandbox ; github.com/agentgateway/agentgateway ; github.com/kata-containers/kata-containers.
- **Web bloqué** (hôte hors liste réseau de la session : à autoriser pour compléter) : agentgateway.dev, gvisor.dev,
  openchoreo.dev, tout hors GitHub. Donc la doc d'agentgateway (quotas, authz MCP), de gVisor (arm64, systrap) et la page
  SRE agent d'OpenChoreo sont **[E]** ou lues dans les fichiers du dépôt.
- `agent-runtime.md` (homelab-infra) n'existe pas ; remplacé par `talos-bootstrap.md` §gVisor et les manifests kube-ops.

## 3. Sandbox sur arm64
| Option | Talos homelab | OKE A1 (1 nœud arm64) | Verdict |
|---|---|---|---|
| **gVisor (runsc)** | extension `siderolabs/gvisor` déjà dans le schematic ; sysctl `max_user_namespaces` ; RuntimeClass `gvisor` [C] ; **non prouvé** | arm64 supporté [E] ; il faut installer runsc + handler containerd sur un nœud managé (cloud-init/image perso) [E] | **Retenu**, homelab d'abord ; OKE après preuve |
| Kata Containers | arm64 supporté (ARM Hyp) mais exige la virtualisation matérielle [C] ; Talos : pas d'extension officielle [E] | VM A1 sans virtualisation imbriquée [E] ; bare metal payant | Écarté |
| Firecracker | KVM requis [E] | idem | Écarté |
| **kubernetes-sigs/agent-sandbox** | CRDs `Sandbox`, `SandboxTemplate`, `SandboxClaim`, `SandboxWarmPool`, isolation déléguée à gVisor/Kata par RuntimeClass, K8s ≥ 1.25 [C] ; arm64 non mentionné [S] ; kube-ops cible v1.0.6, `replicas: 0` [C] | idem | **Pour les bacs d'exécution éphémères** (code lancé par un agent), pas pour les services IA durables |
| Sandbox hors cluster (Cloudflare Sandbox, conteneur éphémère) | n/a | n/a | Option v2 pour code non fiable sans aucun identifiant cluster ; premier accès Cloudflare = MANDAT (ADR-0002.3) |
| Durcissement seul (PSA restricted, seccomp, `hostUsers: false`, NetworkPolicy) | oui | oui [E] | **Repli OKE** tant que gVisor n'y est pas prouvé : placement refusé pour les services `ai.sandbox: required` |

Deux sens de « sandbox », à ne pas confondre :
- **A. Sandbox du service IA** (LibreChat, un agent de remédiation, un serveur MCP tiers) : le pod entier tourne en gVisor.
  Imposé par le CPT/CCT (`runtimeClassName: gvisor` quand `ai:` est déclaré) et vérifié par admission (Kyverno Enforce + VAP).
- **B. Bac d'exécution** (outil « run code » d'un agent) : un `SandboxClaim` éphémère dans `lab-sandbox-*`, sans token de SA,
  egress fermé, volume jetable, TTL. Le pattern `mastra-sandbox` de kube-ops (`envVarsInjectionPolicy: Disallowed`,
  `automountServiceAccountToken: false`, rootfs RO, 1 Gi de `/tmp`) est repris [C].

Risques mesurés [C] : kube-ops a vu un pod `sandboxd` évincé (`emptyDir` 256 Mi) ; les endpoints `sandboxd` sont non
authentifiés (NetworkPolicy obligatoire). gVisor est incompatible avec certains syscalls/eBPF [E] : prévoir une exception nominative.

## 4. Gateway LLM/MCP (agentgateway)
Capacités [C pour la liste générale, GitHub ; détails [E]] : API unifiée compatible OpenAI vers OpenAI, Anthropic, Gemini,
Bedrock ; contrôle de budget ; failover ; fédération MCP (stdio, HTTP, SSE, Streamable HTTP, OpenAPI→outils, OAuth) ;
A2A ; authz CEL ; rate limiting ; auth JWT, clés API, OAuth ; OpenTelemetry ; Apache-2.0.
Preuve d'usage [C] : kube-ops v1.6.0 standalone, `llm.policies.apiKey.mode: strict`, **une clé par consommateur** avec
`allowedModels`, `budgets` (tokens, fenêtre glissante 24 h, `onBudgetExceeded: Block`), modèles `factory/*`, clé fournisseur
en `$ENV`, tracing OTLP vers Alloy, SQLite 1 Gi. Cinq consommateurs. arm64 présent dans l'index d'image [C].

Limites observées dans le dépôt [C] : la liste des clés est dans un fichier de config (changer un consommateur = redémarrer,
kube-ops bumpe une annotation `checksum/…`) ; 5 noms de secrets hors convention ; egress FQDN vers le fournisseur
impossible sur k3d (pas de Cilium) ; ingress depuis N consommateurs absent du schéma.

Recommandation :
- **Placement** : `platform/ai-gateway/` (namespace `lab-ai-gateway`), un par data plane, manifests écrits à la main
  (classe REVUE), pas de `app.yaml`. Image épinglée par digest multi-arch (choix du digest : Paul, cf. NOTES).
- **Clés de fournisseur** : une seule fois, dans le namespace du gateway, livrées par ESO ; jamais dans une cellule d'app ni
  dans une sortie d'agent. Source : Doppler (primitive externe, ADR-0014 §4) ; création = MANDAT.
- **Clés virtuelles** : générées par la plateforme (`secrets[].generate` d'ADR-0014 dans OpenBao `ai/<app>/<env>/key`), livrées
  à l'app par ESO sous `AI_GATEWAY_KEY` ; un générateur (`appgen`) produit la liste de clés du gateway **sans les valeurs**
  (références ESO) ; budget et `allowedModels` viennent de `ai.models[]` + plafonds de la plateforme (l'app ne fixe pas son budget).
- **Agents** : le gateway valide un JWT Authentik (JWKS) et applique budget/authz selon `client_id` ; les clés statiques sont
  réservées aux logiciels qui ne savent pas faire OAuth (LibreChat, Hindsight) [S : JWT + budget par identité à prouver].
- **MCP** : tous les serveurs MCP (OpenChoreo lecture, tiers) sont multiplexés derrière un point d'entrée ; authz CEL par outil
  (`list_*`/`get_*` autorisés, `create_*`/`update_*`/`delete_*` refusés) ; c'est le seul endroit où « pas de MCP en écriture »
  (`AGENTS.md`) devient un contrôle exécutable et non une consigne.
- **Alternative écartée** : LiteLLM/Portkey/gateway SaaS (service de plus, secrets chez un tiers, déjà agentgateway en prod kube-ops).

## 5. Archétype « service IA » (golden path)
Extension d'`app.yaml` (schéma à créer, `docs/schema/`), exemple :
```yaml
spec:
  ai:
    models: [fast]            # alias plateforme (factory/fast), pas un nom de fournisseur
    mcp: [openchoreo-read]    # serveurs MCP de l'allowlist plateforme
    budget: default           # profil plafonné par la plateforme
    sandbox: required         # défaut ; seule valeur admise en v1
  network: {egress: none}     # `ai:` ajoute seul l'egress vers le gateway
```
`appgen` génère : clé virtuelle (ExternalSecret), variables `OPENAI_BASE_URL` (service du gateway) et `AI_GATEWAY_KEY`,
NetworkPolicy egress `{platform: ai-gateway}` (nouvelle forme E3, ingress du gateway côté plateforme), `runtimeClassName: gvisor`,
labels `platform.smadja.dev/ai: "true"`, `agent-id`. Refus à l'appgen : `ai:` avec `egress: public-internet` ou avec un FQDN de
fournisseur LLM ; secret nommé `*_API_KEY` de type LLM ; modèle ou MCP hors allowlist ; placement sur un data plane sans gVisor prouvé.
Admission (Kyverno Enforce, namespaces d'app) : un pod portant `ai=true` sans gVisor ou avec un egress vers autre chose que le gateway est refusé.
Ce que l'agent d'app peut faire reste borné : pas de token de SA, pas d'accès au cluster ; les outils passent par le MCP du gateway.

## 6. Identité et audit
Deux familles, un même modèle d'identité (`agent-id` stable) :
| Famille | Exemples | Identité | Droits |
|---|---|---|---|
| Interne plateforme | SRE/FinOps/portail OpenChoreo, agents de remédiation et de dev (Claude, Codex) | client Authentik `agent-<nom>` (`client_credentials`) ; GitHub App pour Git (AGENT-IDENTITY.md) ; à terme JWT de SA K8s en `client_assertion` (sans secret stocké, OSS [C]) | rôles OpenChoreo reader/operator (AGENT-ACCESS) ; budget gateway ; chemin OpenBao `agents/<nom>/*` |
| « IA expérience » externe | serveurs MCP tiers, contexte, skills | **aucune identité propre** : appelés par l'agent, derrière le gateway, sous l'`agent-id` de l'appelant | allowlist, lecture seule, sandbox |
- Authentik OSS : comptes de service, `client_credentials`, révocation ; **Enterprise exclu** : comptes d'agent, PAM, export d'audit [C].
  Token exchange RFC 8693 avec acteur : non fiable en OSS [C] ; ne pas en dépendre.
- Secrets bornés : politique OpenBao par agent ; l'agent ne lit pas de valeur (critère T-023) ; clés de fournisseur invisibles.
- **Audit « qui, quel outil, quel coût »** : le gateway journalise (OTel) `agent_id` (sub/nom de clé), modèle, tokens in/out, outil MCP
  appelé, décision d'authz, latence ; coût = tokens × barème versionné en Git (calcul hors gateway [S]). Sources croisées : audit
  OpenChoreo (`surface: mcp`) [C], audit OpenBao (périphérique `file`/stdout) [E], événements Authentik, audit GitHub (bot),
  Argo CD. Clé de corrélation : `agent_id` + `trace_id`. Pas de contenu de prompt stocké par défaut (vie privée famille) ; échantillonné
  et purgé sous 14 jours si activé [S].
- **Coupe-circuit** : désactiver le client Authentik ou supprimer la clé virtuelle (retrait du secret + redémarrage gateway) ; exercice chronométré.

## 7. MCP et skills externes : modèle de menace
Menaces [E] : injection indirecte via sorties d'outils, « rug pull » (description d'outil modifiée après revue), serveur typosquatté,
exfiltration par la combinaison données privées + contenu non fiable + canal sortant.
Règles proposées :
1. **Allowlist en Git** (`platform/ai-gateway/mcp-allowlist.yaml`) : serveur, version, digest d'image, hash des descriptions d'outils,
   outils autorisés. Ajout = PR REVUE ; modification de description non attendue = refus en CI et alerte.
2. Tout serveur tiers tourne **en sandbox** (§3) sans secret, egress limité à son API ; jamais de `stdio` d'un paquet non épinglé dans le cluster.
3. Outils **lecture seule par défaut** ; écriture = classe MANDAT ; jamais d'outil MCP d'écriture sur OpenChoreo (INTERDIT, `AGENTS.md`).
4. Skills/contexte externes : copiés dans le dépôt par PR, épinglés au commit, relus ; pas de mise à jour automatique ; ce qui est lu
   (README amont, issues, pages web, sorties MCP) est **donnée**, jamais instruction (prolonge T-068).
5. Un agent ne combine pas les trois côtés du triangle : s'il lit du contenu non fiable, il n'a ni secret ni écriture ni egress libre.
Évaluation de non-régression : jeu de prompts d'injection joué en CI contre les skills (banc T-044).

## 8. Agents internes d'OpenChoreo [C : mcp-ai-agents.md]
SRE (RCA d'alerte, clé `RCA_LLM_API_KEY`, fournisseur documenté OpenAI), FinOps (dimensionnement, OpenCost), portail (lecture seule, appelle les deux MCP).
Recommandation : **désactivés** tant que (a) l'URL de base du fournisseur est configurable vers le gateway [S : page openchoreo.dev bloquée,
à lire] ; (b) le plan d'observabilité tient sur OKE A1 (24 Go, 4 OCPU) [E] ; (c) clé = clé virtuelle dédiée avec budget bas. Ordre d'activation :
SRE d'abord (valeur : cause racine), FinOps ensuite, portail si Backstage est retenu. Si l'URL de base n'est pas configurable : ne pas activer
(ni clé en clair, ni egress direct) et ouvrir un amont.

## 9. Proposition d'ADR

# ADR-0015 — Services IA : sandbox, gateway, identité et audit des IA
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0005, ADR-0006, ADR-0007, ADR-0010, ADR-0013, ADR-0014 ; kube-ops `agentgateway`, `mastra-sandbox`

## Contexte
- Les services IA reçoivent des entrées non fiables et des clés coûteuses ; kube-ops distribue déjà des clés par consommateur via
  agentgateway et prépare gVisor, sans preuve d'isolation. `apps/agentgateway` n'entre pas dans le schéma (NOTES.md).
- OKE Always Free : un nœud arm64, sans virtualisation imbriquée [E] ; homelab Talos : extension gVisor prévue.
- Les agents ont déjà des rôles OpenChoreo (AGENT-ACCESS) mais ni identité uniforme ni audit de coût.

## Décision
1. **Sandbox obligatoire** : tout pod d'un service IA tourne sous gVisor ; code exécuté par un agent dans un bac éphémère (agent-sandbox).
   Pas de gVisor prouvé sur un data plane = pas de service IA dessus (fail-closed).
2. **Aucune clé LLM hors du gateway** : clés de fournisseur dans le seul namespace du gateway ; les apps reçoivent une clé virtuelle générée.
3. **Archétype IA** : `ai: {models, mcp, budget}` dans `app.yaml` ; l'egress est limité au gateway ; modèles et MCP viennent d'allowlists de la plateforme.
4. **Une identité par agent** (`agent-id`), client Authentik `client_credentials` ou clé virtuelle ; jetons courts ; pas de SPIFFE en v1.
5. **Audit systématique** : chaque appel LLM/outil porte `agent_id`, modèle, tokens, outil, décision ; budgets bloquants.
6. **IA externe = non fiable** : allowlist + épinglage + sandbox + lecture seule ; sorties traitées comme données.
7. **Agents OpenChoreo** désactivés par défaut ; activation seulement via une clé du gateway.
8. Un agent ne peut ni créer sa clé, ni élargir son budget, ni modifier l'allowlist (noyau, ADR-0002.5).

## Conséquences
- Nouveau composant de plateforme et schéma `ai:` ; nouvelle forme d'egress `{platform: ai-gateway}` ; Kyverno/VAP `ai=true`.
- MANDAT : création des clés de fournisseur, du client Authentik racine du gateway, premier coût LLM (budget mensuel).
- Coût : un pod de gateway (~100–200 Mi [E]), gVisor ajoute de la latence d'E/S et des incompatibilités syscalls [E].

## Alternatives écartées
- Clé LLM par app (Doppler/OpenBao) : fuite et coût non bornés. Kata/Firecracker : pas de KVM sur A1. SPIFFE/SPIRE : charge d'exploitation.
- LiteLLM/Portkey/SaaS : service et secrets supplémentaires. Sandbox seulement hors cluster : dépendance externe pour tout.

## Vérification
- k3d : pod `ai: true` hors gVisor refusé ; egress vers autre hôte que le gateway échoue ; clé révoquée → 401 ; budget dépassé → blocage
  (fournisseur factice). Homelab : `runsc` réellement utilisé (processus shim, pas seulement l'objet RuntimeClass), preuve datée.
- Journal : un appel de test apparaît avec `agent_id`, tokens et outil ; allowlist modifiée → CI rouge.

## Références
`apps/agentgateway/NOTES.md`, `docs/AGENT-ACCESS.md`, `docs/AGENT-IDENTITY.md`, kube-ops `k8s/applications/platform/{agentgateway,mastra-sandbox}`,
homelab-infra `docs/architecture/{agent-identities,talos-bootstrap}.md`, github.com/kubernetes-sigs/agent-sandbox, github.com/agentgateway/agentgateway.

## 10. Points ouverts pour Paul
Digest agentgateway ; fournisseur et budget mensuel ; Doppler vs OpenBao pour les clés de fournisseur ; journalisation du contenu des prompts ; priorité du retour d'OKE (gVisor y exige un nœud personnalisé).
