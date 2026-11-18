# ADR-0015 — Observabilité, alerting et remédiation automatique
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0003, ADR-0011, ADR-0013, D-2026-11-15-05 et D-2026-11-13-02 (homelab-infra)

## Contexte
- Paul veut qu'un échec d'application déclenche un agent de remédiation et que, sans issue, il soit prévenu sur son téléphone.
- OKE : 1830m / 8,4 GiB, budget CPU à 70 % ; Grafana Cloud gratuit (≈ 10 000 séries partagées, 14 jours) est déjà la cible
  et l'export Alloy existe sur les deux clusters. Le homelab est éteint certains soirs. Le dépôt est public (journaux publics).
- ADR-0011 fournit `app-status.v1` et la preuve runtime ; il rejette l'observability plane OpenChoreo, sans fixer l'alerting.

## Décision
1. **Collecte** : un Alloy par cluster, métriques en liste blanche et logs filtrés (`lab-*`, `dp-*`, `openchoreo-*`), sondes
   blackbox intégrées ; pas de Prometheus, Loki ni Alertmanager locaux pour le lab. Budget de séries tenu par un registre mesuré.
2. **Alerting** : règles et politique de notification évaluées dans Grafana Cloud, déclarées en OpenTofu ; une règle = un
   runbook ; garde de warm-up pour le homelab éteint.
3. **Remédiation** : une alerte d'application déclenche, par `workflow_dispatch` (jeton limité à Actions), un job qui collecte
   un contexte assaini sans l'agent, puis lance l'agent `fix-app` sans secret. Il agit par PR ou revert, selon les classes
   de `platform-guardrails`. Il ne modifie jamais règles d'alerte, silences, CI ni noyau (ADR-0002).
4. **Garde-fous** : une issue d'incident par (app, env) ; 2 essais/app/24 h ; 6 dispatches/jour ; disjoncteur `agent:gave-up`.
5. **Escalade** : sans issue ou garde-fou atteint, ntfy externe (topic secret), priorité 4 ; plateforme indisponible : priorité 5,
   sans agent. Le contenu ne porte ni secret ni log brut. Le canal d'alerte est hors des sites surveillés.
6. **OpenChoreo observability plane et SRE agent non déployés** ; à réexaminer sur preuve de besoin, hors OKE.
7. Chaque incident produit une fiche sans blâme et, si possible, un test ou une règle.

## Conséquences
- Contrat : labels `lab_app/lab_env/cluster`, schéma de charge d'alerte, format de runbook, `cause.type` dans `app-status.v1`.
- Un workflow `.github/` (noyau, REVUE) et deux jetons (Actions-only, Viewer) créés par Paul (MANDAT).
- Coût : ≈ 40m / 180 Mi sur OKE, 0 € ; quota LLM de l'agent borné par les compteurs.
- Risque accepté : un agent peut ouvrir une PR erronée ; compensé par `ci-ok`, preuve runtime et revert.

## Alternatives écartées
- Alertmanager local : meurt avec le site, RAM, doublon. Observability plane OpenChoreo : trop lourd, clé LLM tierce.
- `repository_dispatch` : exige Contents:write. Agent avec accès cluster : identifiants dans la session, injection par logs.
- ntfy interne comme canal d'alerte : indisponible quand le site tombe.

## Vérification
- Drill daté : app cassée en dev → alerte → issue → PR/revert → PASS ; second cas sans issue → ntfy reçu.
- Test CI : chaque règle d'alerte a un runbook ; le workflow n'expose pas de secret à l'étape agent.
- Indicateurs : MTTD, MTTR, part d'incidents clos sans humain, séries utilisées / 10 000.

## Références
`docs/research/OBSERVABILITY-OPERATIONS.md`, `docs/reference/openchoreo/observability.md`, homelab-infra `terraform/grafana-cloud`.

_Source et détails : `docs/research/OBSERVABILITY-OPERATIONS.md`. Texte proposé par la recherche du 2026-11-18, intégré tel quel ; à revoir par la revue adverse._
