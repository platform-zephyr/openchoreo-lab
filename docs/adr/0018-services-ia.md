# ADR-0018 — Services IA : sandbox, gateway, identité et audit des IA
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

**Amendement (consensus du 2026-11-18)** : aucun service IA sur OKE (runtime CRI-O sur nœud unique : changer le node
pool couperait le control plane) ; les services IA tournent sur le homelab.

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

_Source et détails : `docs/research/AI-SERVICES.md`. Texte proposé par la recherche du 2026-11-18, intégré tel quel ; à revoir par la revue adverse._
