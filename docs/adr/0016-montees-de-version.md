# ADR-0016 — Montées de version automatisées
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0002, ADR-0004, ADR-0006, ADR-0008, ADR-0011, D-2026-11-16-07 (homelab-infra), PLT-127/128/140/141

## Contexte
- Paul exige des montées automatisées avec un maximum d'autonomie : apps, charts, OpenChoreo, Argo CD, opérateurs, OKE, Talos, providers Tofu, images de base, actions GitHub.
- Existant : `.github/renovate.json` minimal (digests d'apps automerge), `versions.env` non suivi, aucune procédure OpenChoreo/OKE ; le bundle de sécurité privé lie chaque chart à un bundle.
- Une montée n'est sûre que si la preuve runtime la précède (ADR-0011) et si un revert est possible ; les données stateful et les nœuds uniques ne se « reviennent » pas.
## Décision
1. **Un pipeline unique** : détection (Renovate, veille) → PR → `upgrade-gate` → preuves → merge/promotion → revert automatique.
2. **Trois niveaux** par catégorie : AUTO (Renovate fusionne seul), ASSISTÉ (un agent traite et fusionne sur preuves PASS), MANDAT (préparation autonome, application par Paul dans une fenêtre approuvée). Le tableau de `docs/research/UPGRADES.md` §2 fait foi.
3. **La politique est dans le noyau** : `.github/renovate.json`, `upgrade-gate`, `ops/maintenance-windows.yaml` ne se modifient que par Paul ; aucun agent ne peut élargir son automerge (ADR-0002 §5).
4. **Porte des apps** : CI k3d + déploiement `development` + `app-status` RUNTIME PASS, puis promotion ; en échec, `git revert` automatique. Une montée à la fois en dev (ADR-0004).
5. **Jamais d'automerge** : 0.x, noyau, données `important/irreplaceable`, source d'image nouvelle, image sans `linux/arm64`. Stateful : sauvegarde fraîche prouvée avant toute montée ; majeure PG ou migration de schéma = MANDAT.
6. **Âge minimal** par catégorie (3 à 30 jours) avec `internalChecksFilter: strict` ; les CVE contournent l'âge, pas la preuve.
7. **Plateforme** : OpenChoreo une mineure à la fois (CRD, bundle reconstruit), OKE et Talos par fenêtre déclarée ; l'agent prépare, répète sur k3d, résume ; il n'applique pas.
8. **Supply chain** : digest obligatoire ; signature cosign vérifiée pour les éditeurs qui signent ; provenance et Scorecard en signaux ; actions GitHub jamais en AUTO.
9. **Veille** : un agent résume chaque release (champs fermés), le texte amont reste non fiable.
## Conséquences
- Nouvelle surface : `upgrade-gate`, `bump-versions`, runbooks OpenChoreo/OKE/Talos, `docs/reference/versions.md`, App GitHub pour Renovate (MANDAT).
- Coût : temps de CI k3d, un créneau dev occupé par montée ; coupure assumée du nœud unique pendant les fenêtres.
- T-064 est remplacé par la série UPG ; T-065 (revert) devient prérequis de l'AUTO.
## Alternatives écartées
- **Automerge large sur tout patch/minor** : un tag compromis ou une migration silencieuse atteint la prod sans preuve.
- **Tout en revue humaine** (état kube-ops) : dette de versions croissante (platform-overview homelab-infra), contraire à ADR-0002.
- **Flux/Argo Image Updater écrivant dans le cluster** : contourne Git, interdit par AGENTS.md.
- **Hébergement Renovate par l'App Mend** : pas de `postUpgradeTasks` [E], donc `generated/` non régénéré.
## Vérification
- Indicateurs : part de PR de montée fusionnées sans humain, délai détection → prod, taux de revert, âge médian des dépendances, composants proches de la fin de support.
- Preuves : une montée AUTO complète datée (dev → prod), un échec volontaire → revert, une répétition k3d d'une mineure OpenChoreo, un test de refus de l'automerge pour chaque règle « jamais ».
## Références
`docs/research/UPGRADES.md`, `docs/reference/openchoreo/install-upgrade-support.md`, `docs/SECURITY-BUNDLE.md`, `.github/renovate.json`.

_Source et détails : `docs/research/UPGRADES.md`. Texte proposé par la recherche du 2026-11-18, intégré tel quel ; à revoir par la revue adverse._
