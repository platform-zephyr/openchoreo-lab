# Installation, mise à jour, support, dimensionnement

## À quoi ça sert
Ce qu'il faut pour installer et maintenir OpenChoreo 1.3.x : prérequis, ordre d'installation, cycle de vie et politique de support.
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/deployment-topology/ ; https://openchoreo.dev/docs/v1.3.x/getting-started/try-it-out/on-your-environment/

## Versions
- Doc v1.3.x ; chart Helm et tag Docker `1.3.3` / `v1.3.3` ; registre `oci://ghcr.io/openchoreo/helm-charts` (charts : `openchoreo-control-plane`, `-data-plane`, `-workflow-plane`, `-observability-plane`).
- Aperçu : `v1.4.0-m.2` (ajoute ReleaseLine, pod rollouts, thèmes Backstage) ; non applicable à 1.3.3.
- Dernier patch 1.3.3 le 2026-10-29. v1.3 GA le 2026-09-19.
Sources : https://openchoreo.dev/docs/v1.3.x/changelog/ ; https://openchoreo.dev/docs/v1.3.x/releases/release-and-support-process/

## Prérequis
Kubernetes 1.34+, RBAC, 3 noeuds de 4 vCPU / 8 Go en production (un noeud 4 vCPU / 8 Go suffit en test), LoadBalancer, StorageClass par défaut, Helm 3.12+, cert-manager 1.12+ sur tout cluster de plan, ESO, Gateway API CRDs + kgateway sur data/observability. Un registre de conteneurs est requis pour les builds. Un domaine par plan (wildcard pour les apps), certificats SAN/wildcard.

## Ordre d'installation (cluster réel)
Prérequis (cert-manager, ESO, Gateway API, kgateway) -> TLS -> control plane (ThunderID inclus) -> ressources par défaut (types, traits, environnements) -> data plane + enregistrement -> workflow plane (optionnel) -> observability plane (optionnel) -> liens entre plans.
Source : https://openchoreo.dev/docs/v1.3.x/getting-started/try-it-out/on-your-environment/

## Mise à jour
- Une seule version mineure à la fois ; passer d'abord au dernier patch de sa mineure.
- Helm ne met pas à jour les CRD : `helm pull ... --untar` puis `kubectl apply --server-side --force-conflicts -f crds/` pour chaque plan, puis `helm upgrade --reset-then-reuse-values` dans l'ordre control, data, workflow, observability.
- Sauvegarde recommandée avant : export `kubectl get ... -o yaml` des CRD/ressources + données OpenSearch/registre (rien de natif d'automatisé).
- v1.2 -> v1.3 : claim d'entitlement des comptes de service `sub` -> `client_id` (voir `authz-identity.md`).
Sources : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/upgrades/overview/ ; https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/upgrades/v1.2-to-v1.3/

## Support
Les trois dernières mineures sont supportées (1.3 : fin de vie à la GA de 1.6 ; 1.2 et 1.1 supportées). Patches mensuels, correctifs hors cycle `-hotfix.n`. 1.0 est en fin de vie.
Source : https://openchoreo.dev/docs/v1.3.x/releases/release-and-support-process/

## Dimensionnement (repères)
Control plane : API 2+ réplicas sans état, controller manager 2+ (leader élu), cluster-gateway 1 par défaut (HA = pré-release). Data plane : cluster agent 2+, collecteur de logs 1 par noeud. Workflow plane : les pods de build dominent le coût ; registre HA recommandé.
Source : https://openchoreo.dev/docs/v1.3.x/platform-engineer-guide/production-sizing/

## Invariants et pièges
- Les identifiants par défaut de la démo (ThunderID, clients MCP, secrets de test) sont publics dans la doc : à ne jamais utiliser sur OKE (valeurs non reproduites ici).
- `jwksUrlTlsInsecureSkipVerify` : développement uniquement.
- Mode air-gapped : guide dédié (miroir d'images et de charts).
- Les modules communautaires (logs, tracing, métriques, FinOps, gateway) vivent dans `openchoreo/community-modules`, versionnés séparément.

## Ce qu'un agent LLM doit savoir
Installation et upgrade du cluster sont des actes MANDAT hors périmètre agent (Helm, CRD, secrets). L'agent lit seulement : version des charts (`helm list` côté humain), conditions des objets, santé du cluster-agent.

## Écarts avec le dépôt
- Le labo épingle v1.3.3 comme la doc ; la règle « une mineure à la fois » et le CRD-apply manuel doivent figurer dans le runbook d'upgrade (aucun ADR ne les cite à ce stade, à confirmer).
- k3d (Mac arm64) pour la Phase 0, OKE ensuite : la doc ne distingue pas de contraintes ARM ; vérifier la disponibilité des images arm64 des modules.
