# ADR-0001 — Une seule surface pour les agents : l'intention `app.yaml`
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0005, ADR-0011, ADR-0013 (l'humain parle en langage naturel ; l'agent écrit `app.yaml`)

## Contexte
- Le but est qu'un LLM ajoute une application ou l'opère avec le **moins de concepts possible**.
- kube-ops connaît deux façons de déclarer une app : un `app.yaml` (stateless seulement) ou 8 à 12 fichiers Kustomize écrits
  à la main. La majorité des ~30 apps n'a aucun chemin simple (KUBE-OPS-REQUIREMENTS §2, §6.2).
- OpenChoreo expose un modèle riche (Project, Component, Workload, ComponentRelease, ReleaseBinding, Resource…) et un MCP
  d'environ 110 outils, sans mode lecture seule (CONSOLIDATION §a-b).
- Les sources IDP convergent : intention minimale déclarative, la plateforme génère le reste ; surface d'outils étroite
  (IDP-AGENTIC §principes 1, 11, 12).

## Décision
1. **Écrire = un fichier.** Toute application, quel que soit son archétype, est déclarée par `apps/<nom>/app.yaml`
   (contrat versionné `platform.smadja.dev/v2alpha1`, schéma `docs/schema/app.schema.json`). Pas d'autre chemin
   d'écriture : ni manifestes à la main, ni Kustomize, ni écriture MCP/console/kubectl.
2. **La plateforme génère.** `tools/appgen` transforme l'intention en objets OpenChoreo, Argo CD, ressources
   externes (ADR-0009) et politiques. `generated/` n'est jamais édité à la main.
3. **Lire = trois sources, toutes en lecture seule** : le dépôt (contrat, schémas, `clusters/*/capabilities.yaml`,
   `docs/reference/openchoreo/`), le MCP OpenChoreo avec un client lecture seule, et le statut machine-lisible de
   l'app (ADR-0011).
4. **Opérer = modifier l'intention.** Mettre à jour, promouvoir, mettre à l'échelle, retirer ou revenir en arrière se fait
   par une PR sur `app.yaml` (ou `git revert`). Les verbes `appgen` (`new`, `check`, `promote`, `retire`) sont des
   aides pour écrire cette PR.
5. **Le contrat ne grossit que par champs optionnels** avec valeurs par défaut sûres. Un besoin hors contrat = archétype
   F (refus motivé) ou évolution du contrat par PR plateforme, jamais un échappatoire libre (`extraManifests`…).

## Conséquences
- Les ~30 apps de kube-ops doivent tenir dans ce contrat : il faut donc couvrir worker/cron, Postgres, PVC, OIDC,
  exposition publique et charts Helm durcis (ADR-0005 à 0010). C'est la principale charge de travail.
- Un agent n'a besoin de connaître ni CRD OpenChoreo ni Argo pour livrer ; les skills `add-app`, `fix-app`,
  `promote-or-rollback` restent le mode d'emploi.
- Les erreurs du schéma et d'`appgen check` doivent être typées et dire comment corriger (ADR-0011).

## Alternatives écartées
- **Écriture MCP directe** : contourne Git (prouvé, test O1b de `docs/AGENT-ACCESS.md`), pas de revue ni de revert.
- **Portail Backstage comme canal d'écriture** : vue humaine utile, mais une API de plus à sécuriser ; un template
  Backstage qui ouvre une PR reste possible plus tard.
- **Garder Kustomize libre pour les cas difficiles** : c'est ce qui rend kube-ops illisible pour un agent.

## Vérification
- CI : tout fichier hors `apps/`, `generated/` produit par `appgen`, `platform/`, docs → refus si un objet Kubernetes
  applicatif apparaît ailleurs ; `appgen check` sans dérive.
- Indicateur : part des apps du catalogue kube-ops déclarées par `app.yaml` seul (cible 90 %).

## Références
`docs/APP-CONTRACT.md`, `golden-paths/README.md`, `golden-paths/SCHEMA-GAPS.md`, `docs/research/CONSOLIDATION.md`.
