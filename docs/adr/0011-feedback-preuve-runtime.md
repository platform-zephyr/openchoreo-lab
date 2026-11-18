# ADR-0011 — Feedback machine-lisible et preuve runtime automatique
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0001, ADR-0002, ADR-0004

## Contexte
- Aujourd'hui, une preuve OKE exige le coordinateur et une session bastion : c'est le goulot principal.
- kube-ops a déjà des niveaux de preuve (STATIC < CI < RECONCILED < RUNTIME < USER) et un contrat `app-status.v1`
  (lecture seule). OpenChoreo expose conditions et événements, mais pas de verdict agrégé (CONSOLIDATION §b).
- Les sources IDP insistent sur des erreurs typées et des statuts machine-lisibles (IDP-AGENTIC principes 6, 9, 15).

## Décision
1. **Un statut d'app unique et versionné** (`app-status.v1`, repris de kube-ops) : JSON avec, par environnement,
   le niveau atteint (STATIC/CI/RECONCILED/RUNTIME/USER), le verdict (PASS/FAIL/NOT_TESTED/BLOCKED), la date, le
   cluster, la révision Git et la release, et la cause typée en cas d'échec.
2. **Preuve runtime produite par la plateforme**, pas par un humain : après chaque sync Argo, un Job de vérification
   (namespace `lab-*`, droits en lecture) exécute les checks de l'archétype et le `spec.verify` de l'app, puis
   publie le statut. Une CI verte n'est jamais une preuve runtime.
3. **Lisible sans kubeconfig** : statut publié là où un agent cloud lit déjà (statut de commit / commentaire de PR et
   MCP lecture seule).
4. **Erreurs typées** partout : schéma, `appgen check`, CI, admission. Chaque refus dit la règle, le champ et la
   correction attendue ; il distingue « à corriger » de « réessayable ».
5. **Audit des agents** : chaque changement est attribuable (auteur de PR, client OpenChoreo), humain ou agent.
6. **Boucle sans blâme** : un échec runtime produit une fiche d'incident et, si possible, un nouveau test ou une règle.

## Conséquences
- Ticket central : Job PostSync + publication du statut ; `golden-paths/_checks` en sortie JSON stable.
- `spec.verify` (G10) entre dans le contrat.
- Le coordinateur OKE n'est plus requis pour les apps ; il reste pour l'installation de la plateforme.

## Alternatives écartées
- **Observability plane OpenChoreo complet** : trop lourd pour le nœud ; à reconsidérer après D1.
- **Accès kubectl lecture pour les agents** : identifiants de cluster hors de la session, plus difficile à borner.

## Vérification
- Une PR d'app reçoit un statut RUNTIME daté sans action humaine ; un échec volontaire produit FAIL typé et revert.

## Références
kube-ops `docs/contracts/app-status*` et `acceptance-levels.md`, `golden-paths/_checks/`, `docs/CLOUD-AGENTS.md` §4.
