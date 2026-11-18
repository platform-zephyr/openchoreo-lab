# ADR-0004 — Environnements, promotion et frugalité
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0003, ADR-0011, D-2026-11-15-05 (seuil 70 %), `docs/CLOUD-AGENTS.md`

## Contexte
- OKE Always Free : un nœud, 1830m CPU / 8,4 GiB allocatables, pas de HA voulue. Pas de second cluster de dev.
- Seul l'Environment `production` existe ; `appgen` connaît déjà `development` ; le DeploymentPipeline n'a pas de
  chemin de promotion. Écart G3 : le même `releaseName` part dans tous les environnements.
- Les agents travaillent depuis des sessions cloud sans kubeconfig : ils ont besoin d'un lieu où tester en runtime.

## Décision
1. **Deux Environments OpenChoreo** : `development` et `production`, sur le **même** cluster (et le même data plane)
   pour OKE ; le homelab reçoit les mêmes deux noms quand il devient data plane (ADR-0003).
2. **Promotion `development → production` par PR** : `appgen promote <app>` épingle en production la release
   validée en development (pin par environnement, correction de G3). Revenir en arrière = repointer la release
   précédente par PR ou `git revert`.
3. **Le dev est éphémère et frugal** : une app n'est en `development` que le temps d'un changement ; au plus 2 apps
   en même temps ; `replicas: 1`, `size: small` ; pas de volume ni de base dédiée en development sur OKE (une base
   de dev = base jetable ou données synthétiques, sans volume OCI).
4. **La preuve runtime en development conditionne la promotion** (ADR-0011).
5. **k3d en CI** valide les changements de plateforme ; il ne remplace pas `development` pour les apps.

## Conséquences
- PR plateforme : Environment `development`, `promotionPaths`, pins par environnement dans `appgen`.
- Check CI de frugalité (≤ 2 apps en dev, taille, pas de stockage).
- La promotion en production peut rester autonome (ADR-0002) pour une app A/D ; elle est REVUE pour une app avec
  données `important`/`irreplaceable` (ADR-0008).

## Alternatives écartées
- **Second cluster de dev** : hors Always Free.
- **Deux ClusterDataPlane logiques sur le même OKE** (planeID distincts) : isolation un peu meilleure, double agent et
  double CA pour un nœud déjà plein. À reconsidérer seulement si une fuite dev → prod est observée.
- **Pas de dev, test direct en prod** : supprime le lieu d'essai des agents.

## Vérification
- Preuve OKE datée : une app passe dev → prod → rollback, release prod inchangée pendant un essai dev.
- Mesure : requests totales < 70 % avec 2 apps en dev.

## Références
`golden-paths/SCHEMA-GAPS.md` G3, G12 ; `docs/reference/openchoreo/releases-bindings-promotion.md` ; `environments-pipelines.md`.
