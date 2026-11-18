# ADR-0006 — Primitives de sécurité applicatives par défaut
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0005, ADR-0010 ; `docs/KYVERNO-POLICY-CONTRACT.md`

## Contexte
- L'autonomie des agents (ADR-0002) n'est acceptable que si une app mal écrite **ne peut pas** devenir dangereuse :
  la sécurité doit être dans la plateforme, appliquée sans que l'agent y pense.
- kube-ops a les bonnes règles, mais une partie n'est pas appliquée (Kyverno `nsa-hardening` en Audit, Gatekeeper en
  dryrun, PSA sur 16/29 namespaces) (KUBE-OPS-REQUIREMENTS §3, §6.2).
- OpenChoreo n'apporte pas de politique d'admission hors validations CEL des types (CONSOLIDATION §b).
- OKE et homelab ont tous deux Cilium (chaining sur OKE) : les NetworkPolicy sont appliquées des deux côtés.

## Décision
Chaque app reçoit, **sans rien déclarer**, ces primitives, en défense en profondeur (rendu + admission) :
1. **Pod durci** : non-root, `runAsNonRoot`, drop ALL, seccomp `RuntimeDefault`, `readOnlyRootFilesystem`,
   `allowPrivilegeEscalation: false`, SA sans token monté, requests/limits issus de `size`.
2. **PSA `restricted`** sur chaque namespace de cellule, `enforce-version: latest`.
3. **Réseau default-deny** ingress et egress ; egress déclaré par l'app (`fqdn`, `app`, `idp`) ; IMDS refusé ;
   pas de LoadBalancer ni NodePort.
4. **Images par digest** (`tag@sha256`), registres autorisés listés ; arm64 obligatoire sur OKE.
5. **Secrets** : jamais de valeur dans Git ; référence par nom via ESO, ou **générés dans le cluster** (G9) ;
   l'API de secrets d'OpenChoreo reste désactivée.
6. **Rien de cluster-scoped** et aucun RBAC applicatif créable par une app.
7. **Admission en deux couches** :
   - **VAP natives** (noyau, ADR-0002) pour les invariants vitaux qui doivent tenir sans webhook ;
   - **Kyverno en `Enforce`** pour le golden path (cellules et namespaces d'apps), en `Audit` ailleurs, avec
     `failurePolicy` qui ne bloque pas la restauration de la plateforme (namespaces plateforme exclus).
8. **Exceptions nominatives** : `securityExceptions` dans `app.yaml`, motivées, bornées, visibles dans le catalogue ;
   chaque exception est une PolicyException Kyverno générée, jamais un assouplissement global.

## Conséquences
- Porter les ValidatingPolicy Kyverno du golden path de kube-ops (5 règles en Deny) en `platform/kyverno/`, en mode
  Enforce sur les cellules ; la matrice de `KYVERNO-POLICY-CONTRACT.md` sert de référence.
- Coût mémoire de Kyverno sur OKE à mesurer (D3 de `DECISIONS-OPEN.md`) ; si le budget ne tient pas, les VAP
  couvrent les invariants et Kyverno ne tourne que sur le homelab.
- Une app qui ne passe pas ces règles est F, ou obtient une exception déclarée.

## Alternatives écartées
- **Audit seulement** : c'est l'état de kube-ops, et c'est ce qui laisse des écarts (Mealie).
- **Gatekeeper/OPA** : seconde pile de politiques ; Kyverno + VAP suffisent.

## Vérification
- Suites de refus rejouables en CI k3d (`tests/vap`, `tests/kyverno`) : chaque primitive a un test qui prouve le refus.
- Preuve OKE datée par primitive (liste de `missions/MISSION.md` : default-deny, PSA, IMDS, cluster-scoped, admission).

## Références
`platform/policies/`, `platform/kyverno/`, `docs/KYVERNO-POLICY-CONTRACT.md`, `docs/research/KUBE-OPS-REQUIREMENTS.md` §3.
