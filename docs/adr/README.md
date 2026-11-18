# ADR — décisions d'architecture de la plateforme

Ces ADR fixent la **cible** de la plateforme : un IDP OpenChoreo hybride (OKE + homelab) que des agents LLM utilisent
pour déclarer et opérer des applications. Ils sont **larges** par choix : chacun fixe une direction et les invariants,
pas l'implémentation. Le détail vit dans les tickets (`backlog/`) et les contrats (`docs/APP-CONTRACT.md`, `docs/schema/`).

Ordre de priorité fixé par Paul (2026-11-18) : **autonomie totale des agents d'abord**, avec des **primitives de
sécurité applicatives fortes par défaut** et un **golden path stable**. La sécurité se gagne par des contrôles
exécutables, pas par des approbations.

| ADR | Titre | Statut |
|---|---|---|
| [0001](0001-surface-agent-unique.md) | Une seule surface pour les agents : l'intention `app.yaml` | PROPOSÉ |
| [0002](0002-autonomie-des-agents.md) | Autonomie d'abord, noyau de confiance protégé (sécurité finale : étape FINAL) | PROPOSÉ, amendé |
| [0003](0003-topologie-hybride.md) | Topologie hybride : un control plane, deux data planes (CP sur le homelab, OKE optionnel) | PROPOSÉ, amendé |
| [0004](0004-environnements-promotion.md) | Environnements, promotion et frugalité | PROPOSÉ |
| [0005](0005-golden-path-archetypes.md) | Golden path unique et archétypes | PROPOSÉ |
| [0006](0006-securite-applicative-par-defaut.md) | Primitives de sécurité applicatives par défaut | PROPOSÉ |
| [0007](0007-identite-oidc.md) | Identité : Authentik, OIDC déclaré par l'app | PROPOSÉ |
| [0008](0008-donnees-stateful-recuperation.md) | Données stateful : classe déclarée, sauvegarde et restauration prouvée | PROPOSÉ |
| [0009](0009-ressources-externes-crossplane.md) | Ressources externes par app : Crossplane ; socle : OpenTofu | PROPOSÉ |
| [0010](0010-exposition.md) | Exposition : privé par défaut, public par Cloudflare Tunnel + Access | PROPOSÉ |
| [0011](0011-feedback-preuve-runtime.md) | Feedback machine-lisible et preuve runtime automatique | PROPOSÉ |
| [0012](0012-connaissance-backlog.md) | Connaissance, backlog et état pour agents | PROPOSÉ |
| [0013](0013-intention-langage-naturel.md) | L'utilisateur exprime une intention en langage naturel à un LLM | PROPOSÉ |
| [0014](0014-secrets-openbao.md) | Secrets : OpenBao pour les secrets internes, Doppler pour les primitives externes | PROPOSÉ |
| [0015](0015-observabilite-remediation.md) | Observabilité, alerting et remédiation automatique | PROPOSÉ |
| [0016](0016-montees-de-version.md) | Montées de version automatisées | PROPOSÉ |
| [0017](0017-cout-free-tier.md) | Coût : rester dans le free tier, garde-fous exécutables | PROPOSÉ |
| [0018](0018-services-ia.md) | Services IA : sandbox, gateway, identité et audit des IA | PROPOSÉ |
| [0019](0019-data-platform-mesure.md) | Data platform légère et mesure de la plateforme | PROPOSÉ |
| [0020](0020-porte-adoption-openchoreo.md) | Porte d'adoption d'OpenChoreo (décision le 2026-12-04, mono-cluster) | PROPOSÉ, amendé |
| [0021](0021-usine-agents-24-7.md) | Usine d'agents 24/7 (version réduite : règle d'usine, pilote, paliers, PAUSE) | PROPOSÉ |
| [0022](0022-harness-environnements-agents.md) | Harness et environnements de dev des agents | PROPOSÉ |
| [0023](0023-routage-des-modeles.md) | Routage des modèles par tâche (3 règles) | PROPOSÉ |
| [0024](0024-art-anterieur-maintenabilite.md) | Art antérieur et maintenabilité (recherche bornée, cliquet de qualité) | PROPOSÉ |

Ces ADR ne changent rien au cluster. Un ADR passe d'**PROPOSÉ** à **ACTÉ** par la fusion de la PR qui le modifie,
approuvée par Paul (`docs/adr/` fait partie du noyau protégé, ADR-0002). Un ADR acté n'est pas réécrit : il est
**amendé** ou **remplacé** par un nouvel ADR, comme les décisions `D-AAAA-MM-JJ-NN` de homelab-infra.

Les tickets de `backlog/` ne démarrent qu'une fois leurs ADR **ACTÉ** : T-061 (T-061a) acte ADR-0002 et ADR-0021 (prérequis du
pilote 24 h), T-061b acte ADR 0001, 0003-0006, 0010-0013, 0020, 0022, 0023 et 0024 en parallèle du pilote, T-218 acte ADR 0014-0019
après le MVP (consensus du 2026-11-18 et consensus n°2, `docs/review/CONSENSUS-2.md`).

Amendements du 2026-11-18 (consensus n°2 et arbitrages de Paul) : ADR-0002 (sécurité de dev, étape FINAL), ADR-0003 (CP
OpenChoreo sur le homelab, OKE optionnel), ADR-0020 (porte mono-cluster, horloge à T-363 `done`, repli le 2026-11-25).
ADR-0014 et ADR-0018 ne citent pas DeepSeek : pas d'amendement (DeepSeek après le chantier, ADR-0023).

## Rapport à l'existant

kube-ops, homelab-infra et Atlas sont des **sources d'inspiration, pas des sources de vérité** (Paul, 2026-11-18). Un
composant de l'implémentation actuelle peut être retiré ou remplacé s'il a plus de sens avec OpenChoreo. Candidats
explicitement ouverts : secrets par app dans Doppler (→ OpenBao, ADR-0014), Velero/Kopia vs VolSync, Kyverno sur
OKE, Backstage comme portail, Crossplane (ADR-0009), Argo CD du homelab pour les apps.

## Gabarit

```markdown
# ADR-NNNN — Titre
Statut : PROPOSÉ | ACTÉ | AMENDÉ PAR ADR-XXXX | REMPLACÉ PAR ADR-XXXX · Date : AAAA-MM-JJ · Décideur : Paul
Décisions liées : ADR-…, D-AAAA-MM-JJ-NN (homelab-infra)

## Contexte        — le problème, les contraintes mesurées, ce qui existe déjà
## Décision        — la direction et les invariants, en phrases courtes et numérotées
## Conséquences    — ce que ça impose (contrat, plateforme, agents), ce que ça coûte
## Alternatives écartées — option, raison
## Vérification    — comment on prouve que la décision est tenue (test, check CI, preuve runtime)
## Références
```

Sources de recherche : `docs/research/CONSOLIDATION.md`, `docs/research/IDP-AGENTIC-BEST-PRACTICES.md`,
`docs/research/KUBE-OPS-REQUIREMENTS.md`, `docs/research/HOMELAB-INFRA-REQUIREMENTS.md`, `docs/reference/openchoreo/`.
